import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/settings/settings_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';

/// Lean settings page — theme, language, logout. Accessed via the AppBar
/// icon (no longer a bottom-nav tab).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _onLogoutTap(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.s.confirmLogoutTitle,
      message: context.s.confirmLogoutMessage,
      icon: Icons.logout_rounded,
    );
    if (confirmed && context.mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    return Scaffold(
      appBar: AppBar(title: Text(context.s.settingsTitle)),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (user != null) _ProfileTile(name: user.displayName, isManager: user.canEditVisits),
              const SizedBox(height: 8),
              _SectionLabel(label: context.s.themeMode),
              _ThemeOption(
                label: context.s.themeLight,
                icon: Icons.light_mode_outlined,
                value: ThemeMode.light,
                groupValue: state.themeMode,
              ),
              _ThemeOption(
                label: context.s.themeDark,
                icon: Icons.dark_mode_outlined,
                value: ThemeMode.dark,
                groupValue: state.themeMode,
              ),
              _ThemeOption(
                label: context.s.themeSystem,
                icon: Icons.settings_brightness_outlined,
                value: ThemeMode.system,
                groupValue: state.themeMode,
              ),
              const Divider(),
              _SectionLabel(label: context.s.language),
              _LocaleOption(
                label: context.s.languageArabic,
                value: const Locale('ar'),
                groupValue: state.locale,
              ),
              _LocaleOption(
                label: context.s.languageEnglish,
                value: const Locale('en'),
                groupValue: state.locale,
              ),
              const Divider(),
              _LogoutTile(onTap: () => _onLogoutTap(context)),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final String name;
  final bool isManager;
  const _ProfileTile({required this.name, required this.isManager});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary,
                  Color.lerp(colors.primary, colors.tertiary, 0.55) ??
                      colors.primary,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                color: colors.onPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                Text(
                  isManager ? context.s.roleManager : context.s.roleUser,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        label.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemeMode value;
  final ThemeMode groupValue;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.value,
    required this.groupValue,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ListTile(
      shape: const RoundedRectangleBorder(),
      leading: Icon(icon, color: context.colors.onSurfaceVariant),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle, color: context.colors.primary)
          : null,
      onTap: () => context.read<SettingsCubit>().setThemeMode(value),
    );
  }
}

class _LocaleOption extends StatelessWidget {
  final String label;
  final Locale value;
  final Locale groupValue;

  const _LocaleOption({
    required this.label,
    required this.value,
    required this.groupValue,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value.languageCode == groupValue.languageCode;
    return ListTile(
      shape: const RoundedRectangleBorder(),
      leading: Icon(Icons.translate, color: context.colors.onSurfaceVariant),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle, color: context.colors.primary)
          : null,
      onTap: () => context.read<SettingsCubit>().setLocale(value),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = context.colors.error;
    return ListTile(
      shape: const RoundedRectangleBorder(),
      leading: Icon(Icons.logout_rounded, color: color),
      title: Text(
        context.s.commonLogout,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(Icons.chevron_right, color: color),
      onTap: onTap,
    );
  }
}
