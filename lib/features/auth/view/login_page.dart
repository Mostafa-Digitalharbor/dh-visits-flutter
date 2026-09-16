import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/inline_notice.dart';
import '../bloc/auth_bloc.dart';
import 'auth_chrome.dart';
import 'connection_messages.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _settings = sl<SettingsRepository>();
  late bool _remember;

  /// Why the last attempt failed — or why the previous session ended. Kept on
  /// screen (not a snackbar) because most of these messages ask the user to do
  /// something, and a three-second toast is gone before they have read it.
  String? _failure;

  @override
  void initState() {
    super.initState();
    // Pre-fill the identifier the user last signed in with (only if they asked
    // us to remember it). The password is never stored.
    final remembered = _settings.readRememberedLogin();
    _remember = remembered != null;
    if (remembered != null) _loginCtrl.text = remembered;

    // A session that ended before this screen existed — a 401 on another tab,
    // a stored session that could not be restored — is already in the state.
    // The listener below only hears *changes*, so it would never say why the
    // user is suddenly looking at the sign-in form.
    final pending = context.read<AuthBloc>().state;
    if (pending.hasNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showNotice(pending);
      });
    }
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showNotice(AuthState state) {
    final message = ConnectionMessages.forState(context, state);
    if (message == null) return;
    HapticFeedback.heavyImpact();
    setState(() => _failure = message);
    context.read<AuthBloc>().add(const AuthNoticeShown());
  }

  void _submit() {
    final auth = context.read<AuthBloc>();
    // The keyboard's "done" key stays live while the button shows a spinner.
    if (auth.state.status == AuthStatus.authenticating) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _failure = null);
    final login = _loginCtrl.text.trim();
    // Persist (or forget) the identifier for the next sign-in.
    if (_remember) {
      _settings.writeRememberedLogin(login);
    } else {
      _settings.clearRememberedLogin();
    }
    auth.add(AuthLoginRequested(login: login, password: _passwordCtrl.text));
  }

  String? _requiredValidator(String? v) => Validators.required(context.s, v);

  /// Step back to the server screen — the first screen of the sign-in flow.
  /// `go`, not `pop`: the router *redirects* between the two, so /login is the
  /// only page on the stack and there is nothing to pop back to.
  void _backToServerSetup() => context.go(AppRoutes.setup);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return PopScope(
      // Keeps the system back gesture in step with the hero's back chip: on
      // this screen "back" means "change server", not "leave the app".
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToServerSetup();
      },
      child: Scaffold(
        // Match the sheet colour so the leftover space under it on tall screens
        // reads as one surface (see ServerSetupPage for the same fix).
        backgroundColor: cs.surfaceContainerLowest,
        body: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: ConnectionMessages.raisedNotice,
          listener: (context, state) => _showNotice(state),
          builder: (context, state) {
            final loading = state.status == AuthStatus.authenticating;
            return AuthScrollBody(
              children: [
                AuthHero(onBack: _backToServerSetup),
                AuthSheet(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AuthSheetTitle(
                          title: context.s.loginWelcomeBack,
                          subtitle: context.s.loginSubtitle,
                        ),
                        context.gapH(Insets.x4h),
                        AuthField(
                          controller: _loginCtrl,
                          hint: context.s.loginUsername,
                          icon: Symbols.person,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          validator: _requiredValidator,
                        ),
                        context.gapH(Insets.x3),
                        AuthField(
                          controller: _passwordCtrl,
                          hint: context.s.loginPassword,
                          icon: Symbols.lock,
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: _requiredValidator,
                          onSubmitted: (_) => _submit(),
                        ),
                        context.gapH(Insets.x3h),
                        _RememberRow(
                          remember: _remember,
                          onChanged: (v) => setState(() => _remember = v),
                        ),
                        if (_failure != null) ...[
                          context.gapH(Insets.x3),
                          InlineNotice(text: _failure!, tone: NoticeTone.error),
                        ],
                        context.gapH(Insets.x4h),
                        AuthPrimaryButton(
                          loading: loading,
                          onPressed: _submit,
                          icon: Symbols.login,
                          label: context.s.loginSubmit,
                        ),
                        context.gapH(Insets.x4h),
                        AuthSecureFooter(text: context.s.loginSecureFooter),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Remember + forgot row ───────────────────────────────────────────────────

/// "Remember me" on one side, "Forgot password?" on the other.
///
/// A [Wrap], not a `Row(spaceBetween)`. The Row was the app's largest layout
/// bug: its two children are localized sentences and neither was flexible, so
/// the moment they stopped fitting the row overflowed rather than reflowing —
/// by 103dp on a 320dp phone in English, and by 191dp at the app's 1.25× text
/// ceiling. Because overflow only asserts in debug, release builds clipped it
/// silently and "Forgot password?" was simply *missing* for those users, with
/// nothing on screen to suggest it existed.
///
/// `Wrap` keeps the side-by-side design whenever it fits and drops the link to
/// its own line when it doesn't, so nothing is ever truncated. The per-child
/// width cap covers the remaining case — a single label longer than the whole
/// sheet — by ellipsizing that one label instead of overflowing.
class _RememberRow extends StatelessWidget {
  final bool remember;
  final ValueChanged<bool> onChanged;
  const _RememberRow({required this.remember, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = BoxConstraints(maxWidth: constraints.maxWidth);
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.r(Insets.x3),
          runSpacing: context.r(Insets.x2),
          children: [
            ConstrainedBox(
              constraints: cap,
              child: _RememberToggle(
                remember: remember,
                onChanged: onChanged,
              ),
            ),
            ConstrainedBox(
              constraints: cap,
              child: _ForgotPasswordLink(
                onTap: () => _showForgotPasswordHelp(context),
              ),
            ),
          ],
        );
      },
    );
  }

  /// No self-service reset exists (Odoo admins manage credentials), so tapping
  /// "Forgot password?" explains who to contact instead of dead-ending.
  void _showForgotPasswordHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialogFrame(
        icon: Symbols.lock_reset,
        title: dialogContext.s.loginForgotPasswordTitle,
        body: Text(
          dialogContext.s.loginForgotPasswordBody,
          textAlign: TextAlign.center,
          style: dialogContext.text.bodyMedium?.copyWith(
            color: dialogContext.colors.onSurfaceVariant,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.s.commonClose),
          ),
        ],
      ),
    );
  }
}

/// Stroke weight of the tick inside the checkbox — heavier than the default
/// so it reads at 14dp.
const double _checkGlyphWeight = 700;

/// The custom checkbox + its label, as one tap target.
class _RememberToggle extends StatelessWidget {
  final bool remember;
  final ValueChanged<bool> onChanged;
  const _RememberToggle({required this.remember, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final box = context.r(CompSz.checkbox);
    return Semantics(
      checked: remember,
      label: context.s.loginRememberMe,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!remember),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              width: box,
              height: box,
              decoration: BoxDecoration(
                color: remember ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.badge),
                border: Border.all(
                  color: remember ? cs.primary : x.outlineVariant,
                  width: CompSz.outlineWidth,
                ),
              ),
              child: remember
                  ? Icon(Symbols.check,
                      size: context.r(IconSz.inline),
                      color: cs.onPrimary,
                      weight: _checkGlyphWeight)
                  : null,
            ),
            context.gapW(Insets.x2),
            // Flexible is safe here only because the parent caps this widget's
            // width — a Row lays its non-flexible children out unbounded, and a
            // flex child under an unbounded constraint throws rather than
            // merely overflowing.
            Flexible(
              child: Text(
                context.s.loginRememberMe,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: FontSz.base,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordLink extends StatelessWidget {
  final VoidCallback onTap;
  const _ForgotPasswordLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        context.s.loginForgotPassword,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: FontSz.base,
          fontWeight: FontWeight.w700,
          color: context.colors.primary,
        ),
      ),
    );
  }
}
