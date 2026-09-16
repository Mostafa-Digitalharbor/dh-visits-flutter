import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/config/server_config.dart';
import '../../../core/config/server_config_cubit.dart';
import '../../../core/utils/app_log.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../../shared/widgets/inline_notice.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/view/auth_chrome.dart';
import '../../auth/view/connection_messages.dart';

/// What the setup screen is waiting on.
enum _SetupBusy { idle, detecting, saving }

/// First-run / "change server" screen. Collects the company's backend URL
/// before letting the user reach login. Shares the login screen's visual
/// chrome (brand hero + overlapping sheet); only the fields differ.
///
/// Nothing is saved until the address has answered as an Odoo server and the
/// database is known: saving first used to repoint a signed-in app at a host
/// the user was only trying out.
class ServerSetupPage extends StatefulWidget {
  const ServerSetupPage({super.key});

  @override
  State<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends State<ServerSetupPage> {
  /// How long to wait for the previous server's session to be dropped before
  /// giving up on the switch.
  static const _signOutTimeout = Duration(seconds: 10);

  /// Stroke of the inline "detecting" spinner, thin to match the text button.
  static const _spinnerStroke = 2.0;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlCtrl;
  late final TextEditingController _dbCtrl;

  /// Shown once the database could not be decided without the user, or when a
  /// database is already configured.
  bool _needsDatabase = false;
  _SetupBusy _busy = _SetupBusy.idle;

  /// The last failure, with its next step. Stays on screen until the user
  /// edits the address or tries again.
  String? _failure;

  /// The server origin the database field was filled for, and the value put
  /// there. Changing the address to another server clears a database the user
  /// never typed, so a stale name is not sent to the new host.
  String? _dbOrigin;
  String? _dbFilledValue;

  bool get _isBusy => _busy != _SetupBusy.idle;

  @override
  void initState() {
    super.initState();
    final config = context.read<ServerConfigCubit>().state;
    _urlCtrl = TextEditingController(text: config.baseUrl);
    _dbCtrl = TextEditingController(text: config.database ?? '');
    _needsDatabase = (config.database ?? '').isNotEmpty;
    if (_needsDatabase) _rememberFilledDatabase(config.baseUrl, config.database!);

    // A session that failed to restore is reported while the splash is up and
    // the app then lands here; the listener below only hears later changes.
    final pending = context.read<AuthBloc>().state;
    if (pending.hasNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAuthNotice(pending);
      });
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _dbCtrl.dispose();
    super.dispose();
  }

  void _showAuthNotice(AuthState state) {
    final message = ConnectionMessages.forState(context, state);
    if (message == null) return;
    _fail(message);
    context.read<AuthBloc>().add(const AuthNoticeShown());
  }

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    setState(() => _failure = message);
  }

  void _rememberFilledDatabase(String origin, String database) {
    _dbOrigin = ServerConfig.normalizeUrl(origin);
    _dbFilledValue = database;
  }

  void _onUrlChanged(String value) {
    final movedHost = _dbOrigin != null &&
        ServerConfig.normalizeUrl(value) != _dbOrigin &&
        _dbCtrl.text == _dbFilledValue;
    if (movedHost) {
      _dbCtrl.clear();
      _dbOrigin = null;
      _dbFilledValue = null;
    }
    if (_failure != null || movedHost) setState(() => _failure = null);
  }

  String? _urlValidator(String? v) {
    final s = context.s;
    final required = Validators.required(s, v);
    if (required != null) return required;
    if (!ServerConfig.isValidUrl(v!)) return s.serverSetupInvalidUrl;
    if (ServerConfig.isInsecure(v) && !ServerConfig.allowsInsecureHttp) {
      return s.serverSetupInsecureUrl;
    }
    return null;
  }

  /// Explicit "Detect database" action: asks the entered server which
  /// database it hosts and fills the field. Saves nothing.
  Future<void> _detectDatabase() async {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();
    final invalid = _urlValidator(_urlCtrl.text);
    if (invalid != null) {
      _fail(invalid);
      return;
    }
    HapticFeedback.lightImpact();
    final url = ServerConfig.normalizeUrl(_urlCtrl.text);
    setState(() {
      _busy = _SetupBusy.detecting;
      _failure = null;
    });
    final probe = await context.read<ServerConfigCubit>().probe(url);
    if (!mounted) return;
    setState(() {
      _busy = _SetupBusy.idle;
      _needsDatabase = true; // reveal the field either way
    });
    switch (probe) {
      case ServerProbeFailed(:final error):
        _fail(_probeFailure(error, url));
      case ServerProbeOdoo(onlyDatabase: final String db):
        _fillDatabase(url, db);
        context.showSnack(context.s.serverSetupDetected(db), kind: SnackKind.success);
      case ServerProbeOdoo(:final databases):
        _fail(_undecidedDatabase(databases));
    }
  }

  Future<void> _submit() async {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    final cubit = context.read<ServerConfigCubit>();
    final authBloc = context.read<AuthBloc>();
    final url = ServerConfig.normalizeUrl(_urlCtrl.text);
    final typedDb = _dbCtrl.text.trim();
    setState(() {
      _busy = _SetupBusy.saving;
      _failure = null;
    });

    try {
      // Verify before saving — even with a typed database, so an unreachable
      // or non-Odoo address is reported here and not as a sign-in failure.
      final probe = await cubit.probe(url);
      if (!mounted) return;
      final String? database = switch (probe) {
        ServerProbeFailed(:final error) => _rejectProbe(error, url),
        ServerProbeOdoo(:final databases) =>
          _chooseDatabase(url, typedDb, databases),
      };
      if (database == null) return;

      await cubit.save(baseUrl: url, database: database);
      await _dropPreviousSession(authBloc);
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (e) {
      appLog('[ServerSetupPage] saving the server failed: $e');
      if (mounted) _fail(context.s.serverSetupSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = _SetupBusy.idle);
    }
  }

  /// Returns null after reporting [error], for the `switch` in [_submit].
  String? _rejectProbe(ApiException error, String url) {
    _fail(_probeFailure(error, url));
    return null;
  }

  /// The database to save, or null after telling the user what to enter.
  ///
  /// [databases] is what the server lists (null when it refuses to). A typed
  /// name is checked against the list when there is one — a misspelt or stale
  /// name is reported here instead of as "database not found" after login.
  String? _chooseDatabase(String url, String typed, List<String>? databases) {
    final listed = databases != null && databases.isNotEmpty;
    if (typed.isNotEmpty) {
      if (!listed || databases.contains(typed)) return typed;
      _revealDatabase();
      _fail(context.s.serverSetupDatabaseMissing(typed));
      return null;
    }
    if (listed && databases.length == 1) {
      _fillDatabase(url, databases.single);
      return databases.single;
    }
    _revealDatabase();
    _fail(_undecidedDatabase(databases));
    return null;
  }

  String _undecidedDatabase(List<String>? databases) =>
      databases != null && databases.length > 1
          ? context.s.serverSetupSeveralDatabases(context.joinFacts(databases))
          : context.s.serverSetupDatabasePrompt;

  String _probeFailure(ApiException error, String url) =>
      ConnectionMessages.forFailure(
        context,
        error,
        host: ServerConfig.hostOf(url),
      );

  void _revealDatabase() => setState(() => _needsDatabase = true);

  void _fillDatabase(String url, String database) {
    _dbCtrl.text = database;
    _rememberFilledDatabase(url, database);
    _revealDatabase();
  }

  /// Drops any session that belonged to the previous server so the user lands
  /// on the login screen for the server they just picked. Waits until the
  /// session is actually cleared — otherwise the router would still see an
  /// authenticated user and bounce straight to /home.
  Future<void> _dropPreviousSession(AuthBloc authBloc) async {
    if (authBloc.state.status == AuthStatus.unauthenticated) return;
    final signedOut = authBloc.stream
        .firstWhere((s) => s.status == AuthStatus.unauthenticated)
        .timeout(_signOutTimeout);
    authBloc.add(const AuthServerChanged());
    await signedOut;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final s = context.s;
    final detecting = _busy == _SetupBusy.detecting;
    return Scaffold(
      // Match the sheet, not the page: on a tall screen (tablet, or an iPad
      // running the iPhone build) the sheet ends mid-screen and the leftover
      // space showed as a differently-shaded band under it.
      backgroundColor: cs.surfaceContainerLowest,
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: ConnectionMessages.raisedNotice,
        listener: (context, state) => _showAuthNotice(state),
        child: AuthScrollBody(
          children: [
            // A back chip only when there is somewhere to go back to: opened
            // from Profile this screen is pushed, but as the first screen of
            // the sign-in flow it is the root, and "back" would exit the app.
            // maybeOf: the page is also pumped on its own (layout tests),
            // where there is no router to go back through.
            AuthHero(
              onBack: (GoRouter.maybeOf(context)?.canPop() ?? false)
                  ? () => context.pop()
                  : null,
            ),
            AuthSheet(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AuthSheetTitle(
                      title: s.serverSetupTitle,
                      subtitle: s.serverSetupSubtitle,
                    ),
                    context.gapH(Insets.x4h),
                    AuthField(
                      controller: _urlCtrl,
                      hint: s.serverSetupUrlHint,
                      icon: Symbols.dns,
                      keyboardType: TextInputType.url,
                      autofillHints: const [AutofillHints.url],
                      textInputAction: _needsDatabase
                          ? TextInputAction.next
                          : TextInputAction.done,
                      validator: _urlValidator,
                      onChanged: _onUrlChanged,
                      onSubmitted: _needsDatabase ? null : (_) => _submit(),
                      inputFormatters: [Validators.noWhitespace],
                    ),
                    context.gapH(Insets.x2),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: _isBusy ? null : _detectDatabase,
                        icon: detecting
                            ? SizedBox.square(
                                dimension: context.r(IconSz.xs),
                                child: const CircularProgressIndicator(
                                  strokeWidth: _spinnerStroke,
                                ),
                              )
                            : Icon(Symbols.search, size: context.r(IconSz.label)),
                        label: Text(
                          detecting ? s.serverSetupDetecting : s.serverSetupDetectDb,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_needsDatabase) ...[
                      context.gapH(Insets.x1),
                      ScaleFadeIn(
                        child: AuthField(
                          controller: _dbCtrl,
                          hint: s.serverSetupDatabaseHint,
                          icon: Symbols.database,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          onChanged: (_) {
                            if (_failure != null) setState(() => _failure = null);
                          },
                          validator: (v) => Validators.required(s, v),
                          inputFormatters: [Validators.noWhitespace],
                        ),
                      ),
                    ],
                    context.gapH(Insets.x3),
                    InlineNotice(text: s.serverSetupHelp),
                    if (_failure != null) ...[
                      context.gapH(Insets.x3),
                      InlineNotice(text: _failure!, tone: NoticeTone.error),
                    ],
                    context.gapH(Insets.x4h),
                    AuthPrimaryButton(
                      loading: _busy == _SetupBusy.saving,
                      onPressed: _submit,
                      // Forward, not back: this CTA advances to login. The
                      // icon carries `matchTextDirection`, so Flutter mirrors
                      // it for Arabic on its own — flipping it by hand here
                      // would only cancel that out.
                      icon: Symbols.arrow_forward,
                      label: s.serverSetupContinue,
                    ),
                    context.gapH(Insets.x4h),
                    AuthSecureFooter(
                      text: s.loginSecureFooter,
                      icon: Symbols.lock,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
