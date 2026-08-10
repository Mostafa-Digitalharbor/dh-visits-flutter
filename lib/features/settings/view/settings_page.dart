import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme.dart';
import '../../../core/config/server_config_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';

/// Settings — profile card + grouped cards (account, appearance, language,
/// sync/about) + logout. Matches design screen 07/14.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isManager = context.watch<AuthBloc>().state.user?.canEditVisits ?? false;
    return Scaffold(
      appBar: CvSubAppBar(
        title: context.s.settingsTitle,
        eyebrow: isManager ? context.s.roleManagerTitle : context.s.roleEmployeeTitle,
        topInset: MediaQuery.paddingOf(context).top,
      ),
      body: const SettingsView(),
    );
  }
}

/// The settings content without a Scaffold/AppBar — usable both as a pushed
/// route ([SettingsPage]) and as an employee bottom-nav tab body.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  /// Real build version, read from the platform package metadata (falls back to
  /// a placeholder until the async read completes).
  String _appVersion = '—';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  /// Host of the backend the app is pointed at, shown under "Change server"
  /// so the user can tell which company server they are on at a glance.
  String _serverHost(BuildContext context) {
    final url = context.watch<ServerConfigCubit>().state.baseUrl;
    if (url.isEmpty) return context.s.settingsServerNone;
    return Uri.tryParse(url)?.host.isNotEmpty == true
        ? Uri.parse(url).host
        : url;
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    }
  }

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

  /// Drain the offline queue on demand. Honest feedback: reports how many
  /// pending actions are waiting, or that everything is already up to date.
  Future<void> _onSyncNow(BuildContext context) async {
    final queue = sl<PendingActionsQueue>();
    final pending = queue.pendingCount.value;
    if (pending == 0) {
      context.showSnack(context.s.settingsSynced, kind: SnackKind.success);
      return;
    }
    context.showSnack(context.s.offlineSyncing(pending));
    await queue.flush();
    if (!context.mounted) return;
    // Honest outcome: if anything is still queued the flush didn't fully
    // succeed (usually still offline), so don't claim "synced".
    final remaining = queue.pendingCount.value;
    if (remaining == 0) {
      context.showSnack(context.s.settingsSynced, kind: SnackKind.success);
    } else {
      context.showSnack(context.s.offlinePendingCount(remaining),
          kind: SnackKind.error);
    }
  }

  void _onAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: context.s.aboutAppName,
      applicationVersion: _appVersion,
      applicationLegalese: context.s.aboutLegalese,
    );
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
                _ProfileCard(
                  name: user.displayName,
                  login: user.username,
                  isManager: user.canEditVisits,
                ),
              const SizedBox(height: 18),
              // ── الإدارة (للمدير فقط) ────────────────────────────────────
              if (user?.canEditVisits ?? false) ...[
                _GroupLabel(context.s.roleManagerTitle),
                _GroupCard(children: [
                  _NavRow(
                    icon: Symbols.groups,
                    label: context.s.customersTitle,
                    onTap: () => context.push(AppRoutes.customers),
                  ),
                ]),
                const SizedBox(height: 18),
              ],
              // ── الحساب ──────────────────────────────────────────────────
              _GroupLabel(context.s.settingsAccount),
              _GroupCard(children: [
                _SwitchRow(
                  icon: Symbols.notifications,
                  label: context.s.settingsNotifications,
                  subtitle: context.s.settingsNotificationsSub,
                  value: state.notifications,
                  onChanged: (v) =>
                      context.read<SettingsCubit>().setNotifications(v),
                ),
                const _RowDivider(),
                // The only in-app way back to the server-setup screen. Without
                // it, switching backends means wiping app data.
                _NavRow(
                  icon: Symbols.dns,
                  label: context.s.settingsServer,
                  subtitle: _serverHost(context),
                  onTap: () => context.push(AppRoutes.setup),
                ),
              ]),
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
              const SizedBox(height: 18),
              // ── المزامنة / المساعدة / حول التطبيق ───────────────────────
              _GroupCard(children: [
                _SyncRow(onSync: () => _onSyncNow(context)),
                const _RowDivider(),
                _NavRow(
                  icon: Symbols.info,
                  label: context.s.settingsAbout,
                  subtitle: '${context.s.settingsVersion} $_appVersion',
                  onTap: () => _onAbout(context),
                ),
              ]),
              const SizedBox(height: 24),
              _LogoutButton(onTap: () => _onLogoutTap(context)),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  context.s.aboutFooter,
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
  final String login;
  final bool isManager;
  const _ProfileCard({required this.name, required this.login, required this.isManager});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final initial = InitialAvatar.initialOf(name);
    return AppCard(
      child: Row(
        children: [
          Stack(
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
                        color: Colors.white, fontSize: FontSz.profileInitial, fontWeight: FontWeight.w800)),
              ),
              // Online presence dot (bottom inline-start), 2px surface border.
              PositionedDirectional(
                start: 2,
                bottom: 2,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: x.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surfaceContainerLowest, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppType.titleLg.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface)),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(login,
                      style: AppType.bodySm.copyWith(color: cs.onSurfaceVariant)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isManager ? Symbols.shield_person : Symbols.badge,
                          fill: 1, size: 15, color: cs.onPrimaryContainer),
                      const SizedBox(width: 5),
                      Text(isManager ? context.s.roleManager : context.s.roleUser,
                          style: TextStyle(
                              fontSize: FontSz.sm,
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

/// Eyebrow above a settings group card.
class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) => SectionHeader.eyebrow(
        label: label,
        padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
      );
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

/// A tappable row that navigates / triggers an action (icon + title + optional
/// subtitle + a direction-aware chevron).
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _NavRow({required this.icon, required this.label, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(label, style: AppType.titleSm.copyWith(color: cs.onSurface)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppType.bodySm.copyWith(color: context.x.textTertiary))
          : null,
      trailing: Icon(
        context.isRtl ? Symbols.chevron_left : Symbols.chevron_right,
        color: context.x.textDisabled,
      ),
    );
  }
}

/// Row with a trailing [Switch] (notifications toggle).
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return ListTile(
      onTap: () => onChanged(!value),
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(label, style: AppType.titleSm.copyWith(color: cs.onSurface)),
      subtitle: Text(subtitle, style: AppType.bodySm.copyWith(color: context.x.textTertiary)),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// "آخر مزامنة" row — last-sync sub-text + a "مزامنة الآن" action.
/// "Last sync" row. The subtitle is derived from the live queue — the count of
/// work still waiting, or when a queued action last actually reached the
/// server. It is never a fixed string: telling a field employee "synced just
/// now" while their GPS-stamped check-ins sit unsent is the one lie this row
/// must not tell.
class _SyncRow extends StatelessWidget {
  final VoidCallback onSync;
  const _SyncRow({required this.onSync});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final queue = sl<PendingActionsQueue>();
    return ListTile(
      leading: Icon(Symbols.sync, color: cs.onSurfaceVariant),
      title: Text(context.s.settingsLastSync, style: AppType.titleSm.copyWith(color: cs.onSurface)),
      subtitle: ValueListenableBuilder<int>(
        valueListenable: queue.pendingCount,
        builder: (context, pending, _) => ValueListenableBuilder<DateTime?>(
          valueListenable: queue.lastSyncedAt,
          builder: (context, lastSync, _) {
            // Outstanding work wins the row — that's what the user must act on.
            // Otherwise show when a queued action last really reached the
            // server, or say plainly that there has never been anything to
            // sync (which is not the same as "synced").
            final String text;
            final Color color;
            if (pending > 0) {
              text = context.s.settingsSyncPendingCount(pending);
              color = context.x.warning;
            } else {
              text = lastSync == null
                  ? context.s.settingsSyncNothingPending
                  : RelativeTime.format(context, lastSync);
              color = context.x.textTertiary;
            }
            return Text(text, style: AppType.bodySm.copyWith(color: color));
          },
        ),
      ),
      trailing: TextButton(
        onPressed: onSync,
        child: Text(context.s.settingsSyncNow),
      ),
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
