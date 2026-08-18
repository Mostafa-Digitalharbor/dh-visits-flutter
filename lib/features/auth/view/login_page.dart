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
import '../bloc/auth_bloc.dart';
import 'auth_chrome.dart';

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

  @override
  void initState() {
    super.initState();
    // Pre-fill the identifier the user last signed in with (only if they asked
    // us to remember it). The password is never stored.
    final remembered = _settings.readRememberedLogin();
    _remember = remembered != null;
    if (remembered != null) _loginCtrl.text = remembered;
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    final login = _loginCtrl.text.trim();
    // Persist (or forget) the identifier for the next sign-in.
    if (_remember) {
      _settings.writeRememberedLogin(login);
    } else {
      _settings.clearRememberedLogin();
    }
    context.read<AuthBloc>().add(
          AuthLoginRequested(
            login: login,
            password: _passwordCtrl.text,
          ),
        );
  }

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? context.s.commonRequired : null;

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
          listenWhen: (p, n) => p.error != n.error && n.error != null,
          listener: (context, state) {
            if (state.error != null) {
              HapticFeedback.heavyImpact();
              context.showSnack(state.error!.localize(context),
                  kind: SnackKind.error);
            }
          },
          builder: (context, state) {
            final loading = state.status == AuthStatus.authenticating;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              validator: _requiredValidator,
                            ),
                            context.gapH(Insets.x3),
                            AuthField(
                              controller: _passwordCtrl,
                              hint: context.s.loginPassword,
                              icon: Symbols.lock,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              validator: _requiredValidator,
                              onSubmitted: (_) => _submit(),
                            ),
                            context.gapH(Insets.x3h),
                            _RememberRow(
                              remember: _remember,
                              onChanged: (v) => setState(() => _remember = v),
                            ),
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
                ),
              ),
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
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Symbols.lock_reset, size: IconSz.dialog),
        title: Text(dialogContext.s.loginForgotPasswordTitle),
        content: Text(dialogContext.s.loginForgotPasswordBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.s.commonClose),
          ),
        ],
      ),
    );
  }
}

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
    return GestureDetector(
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
                    color: Colors.white,
                    weight: 700)
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
