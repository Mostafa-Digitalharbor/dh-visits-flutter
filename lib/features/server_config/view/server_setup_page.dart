import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/server_config.dart';
import '../../../core/config/server_config_cubit.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';

/// First-run / "change server" screen. Collects the company's backend URL
/// before letting the user reach login.
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
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _Header()),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              transform: Matrix4.translationValues(0, -24, 0),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedListItem(
                          index: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.s.serverSetupTitle,
                                style: context.text.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.s.serverSetupSubtitle,
                                style: context.text.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        AnimatedListItem(
                          index: 1,
                          child: AppTextField(
                            controller: _urlCtrl,
                            label: context.s.serverSetupUrlLabel,
                            prefixIcon: Icons.dns_outlined,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            validator: _urlValidator,
                            onSubmitted: (_) => _submit(),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            ],
                          ),
                        ),
                        if (_needsDatabase) ...[
                          const SizedBox(height: 14),
                          ScaleFadeIn(
                            child: AppTextField(
                              controller: _dbCtrl,
                              label: context.s.serverSetupDatabaseLabel,
                              prefixIcon: Icons.storage_outlined,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? context.s.commonRequired
                                      : null,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        AnimatedListItem(
                          index: 2,
                          child: _HelpHint(text: context.s.serverSetupHelp),
                        ),
                        const SizedBox(height: 28),
                        AnimatedListItem(
                          index: 3,
                          child: AppButton(
                            label: context.s.serverSetupContinue,
                            loading: _saving,
                            icon: Icons.arrow_forward_rounded,
                            onPressed: _submit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpHint extends StatelessWidget {
  final String text;
  const _HelpHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: context.colors.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  ThemeMode _nextThemeMode(ThemeMode current, Brightness platformBrightness) {
    final effective = current == ThemeMode.system
        ? (platformBrightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light)
        : current;
    return effective == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? colors.onSurface : colors.onPrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 56),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [colors.surface, colors.surfaceContainerHigh]
              : [
                  colors.primary,
                  Color.lerp(colors.primary, colors.tertiary, 0.6) ??
                      colors.primary,
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BlocBuilder<SettingsCubit, SettingsState>(
              builder: (context, state) {
                final isArabic = state.locale.languageCode == 'ar';
                return Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.s.language,
                        icon: Icon(Icons.translate, color: fg),
                        onPressed: () =>
                            context.read<SettingsCubit>().setLocale(
                                  Locale(isArabic ? 'en' : 'ar'),
                                ),
                      ),
                      IconButton(
                        tooltip: context.s.themeMode,
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          color: fg,
                        ),
                        onPressed: () =>
                            context.read<SettingsCubit>().setThemeMode(
                                  _nextThemeMode(
                                    state.themeMode,
                                    MediaQuery.platformBrightnessOf(context),
                                  ),
                                ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.jpg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.s.appTitle,
              style: context.text.headlineSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.s.appTagline,
              style: context.text.bodyMedium?.copyWith(
                color: fg.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
