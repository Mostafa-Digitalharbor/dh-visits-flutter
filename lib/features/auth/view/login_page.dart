import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../bloc/auth_bloc.dart';

enum _LoginRole { manager, employee }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  _LoginRole _role = _LoginRole.manager;

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

  void _pickRole(_LoginRole role) {
    HapticFeedback.selectionClick();
    setState(() => _role = role);
  }

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? context.s.commonRequired : null;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Scaffold(
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
            child: Column(
              children: [
                const _Header(),
                Transform.translate(
                  offset: const Offset(0, -44),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(Radii.xl),
                      boxShadow: context.x.elev3,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(context.s.loginWelcomeBack,
                                  style: AppType.headline.copyWith(
                                      fontWeight: FontWeight.w800, color: cs.onSurface)),
                              const SizedBox(height: 4),
                              Text(context.s.loginSubtitle,
                                  style: AppType.titleSm.copyWith(
                                      fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
                              const SizedBox(height: 22),
                              _RoleSelector(role: _role, onPick: _pickRole),
                              const SizedBox(height: 20),
                              AppTextField(
                                controller: _loginCtrl,
                                label: context.s.loginUsername,
                                prefixIcon: Symbols.person,
                                validator: _requiredValidator,
                              ),
                              const SizedBox(height: 14),
                              AppTextField(
                                controller: _passwordCtrl,
                                label: context.s.loginPassword,
                                prefixIcon: Symbols.lock,
                                isPassword: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                validator: _requiredValidator,
                              ),
                              const SizedBox(height: 24),
                              AppButton(
                                label: context.s.loginSubmit,
                                loading: loading,
                                icon: Symbols.login,
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
            ),
          );
        },
      ),
    );
  }
}

/// The two-tile role chooser. Picking a role prefills the username field with
/// a sample login (mirrors the design's behaviour).
class _RoleSelector extends StatelessWidget {
  final _LoginRole role;
  final ValueChanged<_LoginRole> onPick;
  const _RoleSelector({required this.role, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.s.loginRoleLabel,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            textScaler: TextScaler.noScaling),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RoleTile(
                icon: Symbols.shield_person,
                label: context.s.roleManager,
                selected: role == _LoginRole.manager,
                onTap: () => onPick(_LoginRole.manager),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleTile(
                icon: Symbols.badge,
                label: context.s.roleUser,
                selected: role == _LoginRole.employee,
                onTap: () => onPick(_LoginRole.employee),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoleTile(
      {required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: AnimatedContainer(
        duration: AppDurations.base,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: selected ? cs.primary : x.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                fill: selected ? 1 : 0,
                size: 26,
                color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? cs.primary : cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions();

  ThemeMode _nextThemeMode(ThemeMode current, Brightness platformBrightness) {
    final effective = current == ThemeMode.system
        ? (platformBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light)
        : current;
    return effective == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const fg = Colors.white;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final isArabic = state.locale.languageCode == 'ar';
        return Row(
          children: [
            IconButton(
              tooltip: context.s.loginChangeServer,
              icon: Icon(context.isRtl ? Symbols.arrow_forward : Symbols.arrow_back, color: fg),
              onPressed: () => context.go('/setup'),
            ),
            const Spacer(),
            IconButton(
              tooltip: context.s.language,
              icon: const Icon(Symbols.translate, color: fg),
              onPressed: () =>
                  context.read<SettingsCubit>().setLocale(Locale(isArabic ? 'en' : 'ar')),
            ),
            IconButton(
              tooltip: context.s.themeMode,
              icon: Icon(isDark ? Symbols.light_mode : Symbols.dark_mode, color: fg),
              onPressed: () => context.read<SettingsCubit>().setThemeMode(
                    _nextThemeMode(state.themeMode, MediaQuery.platformBrightnessOf(context)),
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 64),
      decoration: BoxDecoration(
        gradient: x.brandGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Radii.xl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _HeaderActions(),
            const SizedBox(height: 12),
            Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: x.elev3,
              ),
              child: ClipOval(
                child: Image.asset('assets/images/logo.jpg', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 16),
            Text(context.s.appTitle,
                style: AppType.displayMd.copyWith(
                    fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 6),
            Text(context.s.appTagline,
                textAlign: TextAlign.center,
                style: AppType.titleSm.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.88))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
