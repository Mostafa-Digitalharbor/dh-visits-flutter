import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/server_config.dart';
import '../../../core/config/server_config_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/view/auth_chrome.dart';
import '../../../app/design/app_dimens.dart';

/// First-run / "change server" screen. Collects the company's backend URL
/// before letting the user reach login. Shares the login screen's visual
/// chrome (brand hero + overlapping sheet); only the fields differ.
class ServerSetupPage extends StatefulWidget {
  const ServerSetupPage({super.key});

  @override
  State<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends State<ServerSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlCtrl;
  late final TextEditingController _dbCtrl;

  /// Shown only when we couldn't auto-detect the database from the server.
  bool _needsDatabase = false;
  bool _saving = false;
  bool _detecting = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<ServerConfigCubit>().state;
    _urlCtrl = TextEditingController(text: config.baseUrl);
    _dbCtrl = TextEditingController(text: config.database ?? '');
    _needsDatabase = (config.database ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _dbCtrl.dispose();
    super.dispose();
  }

  String? _urlValidator(String? v) {
    if (v == null || v.trim().isEmpty) return context.s.commonRequired;
    if (!ServerConfig.isValidUrl(v)) return context.s.serverSetupInvalidUrl;
    return null;
  }

  /// Explicit "Detect database" action: points the API client at the entered
  /// URL and asks the server for its database name, filling the field.
  Future<void> _detectDatabase() async {
    FocusScope.of(context).unfocus();
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty || !ServerConfig.isValidUrl(raw)) {
      context.showSnack(context.s.serverSetupInvalidUrl, kind: SnackKind.error);
      return;
    }
    HapticFeedback.lightImpact();
    final cubit = context.read<ServerConfigCubit>();
    setState(() => _detecting = true);

    final url = ServerConfig.normalizeUrl(raw);
    // Point the client at this host so detection queries hit the right server.
    await cubit.save(baseUrl: url);
    final db = await cubit.detectDatabase();
    if (!mounted) return;

    setState(() {
      _detecting = false;
      _needsDatabase = true; // reveal the field either way
      if (db != null) _dbCtrl.text = db;
    });
    context.showSnack(
      db != null
          ? context.s.serverSetupDetected(db)
          : context.s.serverSetupDetectFailed,
      kind: db != null ? SnackKind.success : SnackKind.error,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    final authBloc = context.read<AuthBloc>();
    final cubit = context.read<ServerConfigCubit>();
    setState(() => _saving = true);

    final url = ServerConfig.normalizeUrl(_urlCtrl.text);
    final typedDb = _dbCtrl.text.trim();

    // Point the API client at the chosen server before anything else.
    await cubit.save(baseUrl: url, database: typedDb.isEmpty ? null : typedDb);

    String? db = typedDb.isEmpty ? null : typedDb;
    if (db == null) {
      // Odoo needs a database name. Try to discover it from the server; if we
      // can't, ask the user to type it (once).
      db = await cubit.detectDatabase();
      if (db != null) {
        await cubit.save(baseUrl: url, database: db);
      } else {
        if (!mounted) return;
        setState(() {
          _needsDatabase = true;
          _saving = false;
        });
        context.showSnack(
          context.s.serverSetupDatabasePrompt,
          kind: SnackKind.error,
        );
        return;
      }
    }

    // Drop any session that belonged to the previous server so the user always
    // lands on the login screen for the server they just picked. Wait until the
    // session is actually cleared — otherwise the router would still see us as
    // authenticated and bounce straight to /home.
    if (authBloc.state.status != AuthStatus.unauthenticated) {
      authBloc.add(const AuthServerChanged());
      await authBloc.stream.firstWhere(
        (s) => s.status == AuthStatus.unauthenticated,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHero(),
              AuthSheet(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AuthSheetTitle(
                        title: context.s.serverSetupTitle,
                        subtitle: context.s.serverSetupSubtitle,
                      ),
                      const SizedBox(height: 18),
                      AuthField(
                        controller: _urlCtrl,
                        hint: context.s.serverSetupUrlHint,
                        icon: Symbols.dns,
                        keyboardType: TextInputType.url,
                        textInputAction:
                            _needsDatabase ? TextInputAction.next : TextInputAction.done,
                        validator: _urlValidator,
                        onSubmitted: _needsDatabase ? null : (_) => _submit(),
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed:
                              (_detecting || _saving) ? null : _detectDatabase,
                          icon: _detecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Symbols.search, size: 18),
                          label: Text(_detecting
                              ? context.s.serverSetupDetecting
                              : context.s.serverSetupDetectDb),
                        ),
                      ),
                      if (_needsDatabase) ...[
                        const SizedBox(height: 4),
                        ScaleFadeIn(
                          child: AuthField(
                            controller: _dbCtrl,
                            hint: context.s.serverSetupDatabaseHint,
                            icon: Symbols.database,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? context.s.commonRequired
                                : null,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _HelpHint(text: context.s.serverSetupHelp),
                      const SizedBox(height: 18),
                      AuthPrimaryButton(
                        loading: _saving,
                        onPressed: _submit,
                        icon: Symbols.arrow_back,
                        label: context.s.serverSetupContinue,
                      ),
                      const SizedBox(height: 18),
                      AuthSecureFooter(
                        text: context.s.loginSecureFooter,
                        icon: Symbols.lock,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpHint extends StatelessWidget {
  final String text;
  const _HelpHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.info, size: 16, fill: 1, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
