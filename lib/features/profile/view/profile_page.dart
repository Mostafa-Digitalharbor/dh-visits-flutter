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
import '../../auth/data/models/user.dart';

/// Profile — who you are signed in as, then everything scoped to that account:
/// the manager's own tools, notification/server settings, appearance, language,
/// sync/about, and sign-out. Matches design screen 07/14.
///
/// This screen used to be "Settings", reachable only from an app-bar gear and
/// wrapped in its own pushed route. It became the account **tab** of both role
/// shells instead, because the identity card was already its header and
/// sign-out already its footer — the gear was the odd one out, not the profile.
/// The shell supplies the app bar, so there is no page wrapper here and no
/// `/profile` route: nothing pushes it.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
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
    // Built once and reused for all six separators: this screen is a stack of
    // labelled groups, and the gap between them is one decision, not six.
    final groupGap = context.gapH(Insets.x4h);
    return BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            padding: _pagePadding(context),
            children: [
              if (user != null) _ProfileCard(user: user),
              // The launch snackbar that says this is long gone by the time
              // someone wonders where their buttons went, and the profile is
              // exactly where they come to check what they are. So it is
              // restated here, permanently, next to the role it contradicts.
              if (user?.profileIncomplete ?? false) ...[
                context.gapH(Insets.x3),
                const _ProfileIncompleteNotice(),
              ],
              groupGap,
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
                groupGap,
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
              groupGap,
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
              groupGap,
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
              groupGap,
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
              context.gapH(Insets.x6),
              _LogoutButton(onTap: () => _onLogoutTap(context)),
              groupGap,
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

/// Tighter at the top than the other screens — the profile card is its own
/// visual header, so it does not need a full screen inset above it. The deep
/// bottom inset clears the shell's nav bar under the footer text.
EdgeInsets _pagePadding(BuildContext context) => EdgeInsets.fromLTRB(
      context.r(Insets.screen),
      context.r(Insets.x3),
      context.r(Insets.screen),
      context.rh(Insets.x8),
    );

/// 64 — the largest avatar in the app after the customer-detail hero. Passed
/// unscaled: [InitialAvatar] sizes its glyph from this, and the card it sits in
/// is a fixed-height row that already breathes with the text scale.
const double _profileAvatarSize = 64.0;

/// The online dot, and how far it is inset from the avatar's edge — the same
/// 2dp doubles as its ring width, which is what makes the ring read as a
/// cut-out rather than an outline.
const double _presenceDotSize = 15.0;
const double _presenceDotInset = 2.0;

class _ProfileCard extends StatelessWidget {
  final AuthUser user;
  const _ProfileCard({required this.user});

  /// The badge names the user's *visit* role, not the manager/employee split
  /// the rest of the chrome uses. A project manager and a team manager both
  /// read as "manager" everywhere else in the app; this is the one screen whose
  /// job is to answer "what am I", so it answers precisely.
  ///
  /// [VisitRole.none] with the Odoo admin flag is a real combination — the
  /// database administrator on a server whose visit groups were never seeded —
  /// and calling that person a field employee would be actively misleading.
  String _roleLabel(BuildContext context) {
    switch (user.visitRole) {
      case VisitRole.admin:
        return context.s.roleAdmin;
      case VisitRole.projectManager:
        return context.s.roleProjectManager;
      case VisitRole.manager:
        return context.s.roleManager;
      case VisitRole.user:
        return context.s.roleUser;
      case VisitRole.none:
        return user.isAdmin ? context.s.roleAdmin : context.s.roleUser;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final dot = context.r(_presenceDotSize);
    final name = user.displayName;
    final login = user.username;
    final isManager = user.canEditVisits;
    return AppCard(
      child: Row(
        children: [
          Stack(
            children: [
              // [InitialAvatar], not a hand-rolled circle: it owns the gradient,
              // the proportional glyph size and — the part that matters — the
              // guard that stops an empty or whitespace-only Odoo name throwing
              // a RangeError on `name[0]`.
              InitialAvatar(name: name, size: _profileAvatarSize),
              // Online presence dot, inline-start so it mirrors in Arabic.
              PositionedDirectional(
                start: _presenceDotInset,
                bottom: _presenceDotInset,
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: x.success,
                    shape: BoxShape.circle,
                    // Ringed in the card colour so it reads as sitting on top
                    // of the avatar rather than merging into it.
                    border: Border.all(
                      color: cs.surfaceContainerLowest,
                      width: _presenceDotInset,
                    ),
                  ),
                ),
              ),
            ],
          ),
          context.gapW(Insets.x3h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppType.titleLg.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface)),
                context.gapH(Insets.hair),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(login,
                      style: AppType.bodySm.copyWith(color: cs.onSurfaceVariant)),
                ),
                context.gapH(Insets.x1h),
                Container(
                  padding: context.padSym(h: Insets.x2h, v: Insets.x1 + 1),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isManager ? Symbols.shield_person : Symbols.badge,
                          fill: 1,
                          size: context.r(IconSz.pill),
                          color: cs.onPrimaryContainer),
                      context.gapW(Insets.x1 + 1),
                      // Flexible: the pill is inside a Row inside a Column that
                      // the card already bounds, and "مدير المشروع" at 1.25×
                      // is wider than a 320dp card leaves for it.
                      Flexible(
                        child: Text(_roleLabel(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: FontSz.sm,
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimaryContainer)),
                      ),
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

/// Why the role above may be a fallback rather than the truth.
///
/// [AuthUser.profileIncomplete] means the post-login permission read failed, so
/// the badge shows the default role and every workflow button is hidden. Said
/// once in a launch snackbar it is gone before it is needed; said here it sits
/// next to the claim it qualifies.
class _ProfileIncompleteNotice extends StatelessWidget {
  const _ProfileIncompleteNotice();

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.warning, fill: 1, size: context.r(IconSz.sm), color: x.warning),
          context.gapW(Insets.x2h),
          Expanded(
            child: Text(
              context.s.errProfileIncomplete,
              style: AppType.bodySm.copyWith(color: context.colors.onSurfaceVariant),
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

/// 54 — taller than a standard button. Sign-out is the one destructive action
/// on this screen and is deliberately given its own weight at the foot of it.
const double _logoutHeight = 54.0;

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
          // fixedH: the row holds a label, so the button grows with the OS text
          // scale instead of clipping it.
          height: context.fixedH(_logoutHeight),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Symbols.logout,
                  fill: 1, size: context.r(IconSz.sm), color: cs.error),
              context.gapW(Insets.x2),
              Text(context.s.commonLogout,
                  style: AppType.button.copyWith(fontWeight: FontWeight.w800, color: cs.error)),
            ],
          ),
        ),
      ),
    );
  }
}
