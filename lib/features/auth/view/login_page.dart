import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/settings/settings_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    debugPrint('[debug] LoginPage._submit pressed '
        '(login=${_loginCtrl.text.trim()})');
    if (!_formKey.currentState!.validate()) {
      debugPrint('[debug] LoginPage form validation failed');
      return;
    }
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
    final colors = context.colors;
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (p, n) => p.error != n.error && n.error != null,
        listener: (context, state) {
          if (state.error != null) {
            context.showSnack(state.error!.localize(context));
          }
        },
        builder: (context, state) {
          final loading = state.status == AuthStatus.authenticating;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(),
              ),
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
                  padding:
                      const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.s.loginTitle,
                              style: context.text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.s.loginSubtitle,
                              style: context.text.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 28),
                            AppTextField(
                              controller: _loginCtrl,
                              label: context.s.loginUsername,
                              prefixIcon: Icons.person_outline,
                              validator: _requiredValidator,
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _passwordCtrl,
                              label: context.s.loginPassword,
                              prefixIcon: Icons.lock_outline,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              validator: _requiredValidator,
                            ),
                            const SizedBox(height: 28),
                            AppButton(
                              label: context.s.loginSubmit,
                              loading: loading,
                              icon: Icons.login_rounded,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions();

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? context.colors.onSurface : context.colors.onPrimary;
    return BlocBuilder<SettingsCubit, SettingsState>(
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
                onPressed: () => context.read<SettingsCubit>().setLocale(
                      Locale(isArabic ? 'en' : 'ar'),
                    ),
              ),
              IconButton(
                tooltip: context.s.themeMode,
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: fg,
                ),
                onPressed: () => context.read<SettingsCubit>().setThemeMode(
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
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            const _HeaderActions(),
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
                color: isDark ? colors.onSurface : colors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.s.appTagline,
              style: context.text.bodyMedium?.copyWith(
                color: (isDark ? colors.onSurface : colors.onPrimary)
                    .withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
