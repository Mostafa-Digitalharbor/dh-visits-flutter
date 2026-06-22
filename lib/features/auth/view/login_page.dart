import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
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
  bool _remember = true;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    context.read<AuthBloc>().add(
          AuthLoginRequested(
            login: _loginCtrl.text.trim(),
            password: _passwordCtrl.text,
          ),
        );
  }

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? context.s.commonRequired : null;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Scaffold(
      backgroundColor: cs.surface,
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (p, n) => p.error != n.error && n.error != null,
        listener: (context, state) {
          if (state.error != null) {
            HapticFeedback.heavyImpact();
            context.showSnack(state.error!.localize(context), kind: SnackKind.error);
          }
        },
        builder: (context, state) {
          final loading = state.status == AuthStatus.authenticating;
          return SingleChildScrollView(
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
                            title: context.s.loginWelcomeBack,
                            subtitle: context.s.loginSubtitle,
                          ),
                          const SizedBox(height: 18),
                          AuthField(
                            controller: _loginCtrl,
                            hint: context.s.loginUsername,
                            icon: Symbols.person,
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: 12),
                          AuthField(
                            controller: _passwordCtrl,
                            hint: context.s.loginPassword,
                            icon: Symbols.lock,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            validator: _requiredValidator,
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 14),
                          _RememberRow(
                            remember: _remember,
                            onChanged: (v) => setState(() => _remember = v),
                          ),
                          const SizedBox(height: 18),
                          AuthPrimaryButton(
                            loading: loading,
                            onPressed: _submit,
                            icon: Symbols.login,
                            label: context.s.loginSubmit,
                          ),
                          const SizedBox(height: 18),
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
    );
  }
}

// ─── Remember + forgot row ───────────────────────────────────────────────────

class _RememberRow extends StatelessWidget {
  final bool remember;
  final ValueChanged<bool> onChanged;
  const _RememberRow({required this.remember, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!remember),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: remember ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: remember ? cs.primary : x.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: remember
                    ? const Icon(Symbols.check, size: 14, color: Colors.white, weight: 700)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                context.s.loginRememberMe,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Text(
            context.s.loginForgotPassword,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary),
          ),
        ),
      ],
    );
  }
}
