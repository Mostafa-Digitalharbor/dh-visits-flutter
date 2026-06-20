import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';

/// Settings — profile card + grouped cards (appearance, language) + logout.
/// Matches design screen 07.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s.settingsTitle)),
      body: const SettingsView(),
    );
  }
}

/// The settings content without a Scaffold/AppBar — usable both as a pushed
/// route ([SettingsPage]) and as an employee bottom-nav tab body.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

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
    return BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (user != null)
                _ProfileCard(name: user.displayName, isManager: user.canEditVisits),
              const SizedBox(height: 18),
              _GroupLabel(context.s.themeMode),
              _GroupCard(children: [
                _OptionRow(
                  icon: Symbols.light_mode,
                  label: context.s.themeLight,
                  selected: state.themeMode == ThemeMode.light,
                  onTap: () => context.read<SettingsCubit>().setThemeMode(ThemeMode.light),
                ),
                const _RowDivider(),
                _OptionRow(
                  icon: Symbols.dark_mode,
                  label: context.s.themeDark,
                  selected: state.themeMode == ThemeMode.dark,
                  onTap: () => context.read<SettingsCubit>().setThemeMode(ThemeMode.dark),
                ),
                const _RowDivider(),
                _OptionRow(
                  icon: Symbols.brightness_auto,
                  label: context.s.themeSystem,
                  selected: state.themeMode == ThemeMode.system,
                  onTap: () => context.read<SettingsCubit>().setThemeMode(ThemeMode.system),
                ),
              ]),
              const SizedBox(height: 18),
              _GroupLabel(context.s.language),
              _GroupCard(children: [
                _OptionRow(
                  icon: Symbols.translate,
                  label: context.s.languageArabic,
                  selected: state.locale.languageCode == 'ar',
                  onTap: () => context.read<SettingsCubit>().setLocale(const Locale('ar')),
                ),
                const _RowDivider(),
                _OptionRow(
                  icon: Symbols.translate,
                  label: context.s.languageEnglish,
                  selected: state.locale.languageCode == 'en',
                  onTap: () => context.read<SettingsCubit>().setLocale(const Locale('en')),
                ),
              ]),
              const SizedBox(height: 24),
              _LogoutButton(onTap: () => _onLogoutTap(context)),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Customer Visits · Digital Harbor',
                  style: AppType.bodySm.copyWith(color: context.x.textTertiary),
                ),
              ),
            ],
          );
        },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final bool isManager;
  const _ProfileCard({required this.name, required this.isManager});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: x.avatarGradient,
              shape: BoxShape.circle,
              boxShadow: x.elev1,
            ),
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppType.titleLg.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isManager ? Symbols.shield_person : Symbols.badge,
                          fill: 1, size: 15, color: cs.onPrimaryContainer),
                      const SizedBox(width: 5),
                      Text(isManager ? context.s.roleManager : context.s.roleUser,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer)),
                    ],
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

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: AppType.eyebrow.copyWith(color: context.colors.primary, letterSpacing: 1.0),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: context.x.divider);
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionRow(
      {required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, fill: selected ? 1 : 0, color: cs.onSurfaceVariant),
      title: Text(label, style: AppType.titleSm.copyWith(color: cs.onSurface)),
      trailing: selected
          ? Icon(Symbols.check_circle, fill: 1, color: cs.primary)
          : Icon(Symbols.radio_button_unchecked, color: context.x.textDisabled),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Material(
      color: cs.errorContainer,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Symbols.logout, fill: 1, size: 20, color: cs.error),
              const SizedBox(width: 8),
              Text(context.s.commonLogout,
                  style: AppType.button.copyWith(fontWeight: FontWeight.w800, color: cs.error)),
            ],
          ),
        ),
      ),
    );
  }
}
