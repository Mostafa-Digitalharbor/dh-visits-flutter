import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/config/server_config_cubit.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/inline_notice.dart';
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
  /// The installed build, read from the platform package metadata; null until
  /// that read completes (or if it fails).
  String? _appVersion;

  /// True while a user-started sync runs, so the button can't queue a second.
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion =
          context.s.profileBuildVersion(info.version, info.buildNumber));
    } catch (e) {
      // The row keeps its placeholder; nothing the user can act on.
      appLog('[ProfileView] app version unavailable: $e');
    }
  }

  Future<void> _onLogoutTap(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.s.confirmLogoutTitle,
      message: context.s.confirmLogoutMessage,
      icon: Symbols.logout,
      // The buttons name the outcome, not "yes" / "no".
      confirmLabel: context.s.commonLogout,
      cancelLabel: context.s.commonCancel,
    );
    if (confirmed && context.mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }

  /// Drain the offline queue on demand. Honest feedback: reports how many
  /// pending actions are waiting, or that everything is already up to date.
  Future<void> _onSyncNow(BuildContext context) async {
    if (_syncing) return;
    final queue = sl<PendingActionsQueue>();
    final pending = queue.pendingCount.value;
    if (pending == 0) {
      context.showSnack(context.s.settingsSynced, kind: SnackKind.success);
      return;
    }
    context.showSnack(context.s.offlineSyncing(pending));
    setState(() => _syncing = true);
    try {
      final result = await queue.flush();
      if (!context.mounted) return;
      // Honest outcome: anything still queued means the flush didn't fully go
      // through (usually still offline), so don't claim "synced". Dropped
      // actions are announced by the shell as they happen.
      if (result.remaining == 0) {
        context.showSnack(context.s.settingsSynced, kind: SnackKind.success);
      } else {
        context.showSnack(context.s.offlinePendingCount(result.remaining),
            kind: SnackKind.error);
      }
    } catch (e) {
      appLog('[ProfileView] manual sync failed: $e');
      if (context.mounted) {
        context.showSnack(
          context.s.offlinePendingCount(queue.pendingCount.value),
          kind: SnackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _onAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: context.s.aboutAppName,
      applicationVersion: _appVersion ?? context.s.commonNoValue,
      applicationLegalese: context.s.aboutLegalese,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final user = context.watch<AuthBloc>().state.user;
    final server = context.watch<ServerConfigCubit>().state;
    // Built once and reused for all the separators: this screen is a stack of
    // labelled groups, and the gap between them is one decision, not six.
    final groupGap = context.gapH(Insets.x4h);
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final settings = context.read<SettingsCubit>();
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
              InlineNotice(
                text: s.errProfileIncomplete,
                tone: NoticeTone.warning,
              ),
            ],
            groupGap,
            // ── Management (managers only) ─────────────────────────────────
            if (user?.canEditVisits ?? false) ...[
              _GroupLabel(s.roleManagerTitle),
              _GroupCard(children: [
                _NavRow(
                  icon: Symbols.groups,
                  label: s.customersTitle,
                  onTap: () => context.push(AppRoutes.customers),
                ),
              ]),
              groupGap,
            ],
            // ── Account ────────────────────────────────────────────────────
            _GroupLabel(s.settingsAccount),
            _GroupCard(children: [
              _SwitchRow(
                icon: Symbols.notifications,
                label: s.settingsNotifications,
                subtitle: s.settingsNotificationsSub,
                value: state.notifications,
                onChanged: settings.setNotifications,
              ),
              const _RowDivider(),
              // The only in-app way back to the server-setup screen. Without
              // it, switching backends means wiping app data.
              _NavRow(
                icon: Symbols.dns,
                label: s.settingsServer,
                subtitle: server.baseUrl.isEmpty ? s.settingsServerNone : server.host,
                onTap: () => context.push(AppRoutes.setup),
              ),
            ]),
            groupGap,
            _GroupLabel(s.themeMode),
            _GroupCard(children: [
              for (final (i, option) in [
                (mode: ThemeMode.light, icon: Symbols.light_mode, label: s.themeLight),
                (mode: ThemeMode.dark, icon: Symbols.dark_mode, label: s.themeDark),
                (mode: ThemeMode.system, icon: Symbols.brightness_auto, label: s.themeSystem),
              ].indexed) ...[
                if (i > 0) const _RowDivider(),
                _OptionRow(
                  icon: option.icon,
                  label: option.label,
                  selected: state.themeMode == option.mode,
                  onTap: () => settings.setThemeMode(option.mode),
                ),
              ],
            ]),
            groupGap,
            _GroupLabel(s.language),
            _GroupCard(children: [
              for (final (i, option) in [
                (locale: AppLocales.arabic, label: s.languageArabic),
                (locale: AppLocales.english, label: s.languageEnglish),
              ].indexed) ...[
                if (i > 0) const _RowDivider(),
                _OptionRow(
                  icon: Symbols.translate,
                  label: option.label,
                  selected: state.locale.languageCode == option.locale.languageCode,
                  onTap: () => settings.setLocale(option.locale),
                ),
              ],
            ]),
            groupGap,
            // ── Sync / about ───────────────────────────────────────────────
            _GroupCard(children: [
              _SyncRow(
                syncing: _syncing,
                onSync: () => _onSyncNow(context),
              ),
              const _RowDivider(),
              _NavRow(
                icon: Symbols.info,
                label: s.settingsAbout,
                subtitle: s.settingsVersionValue(_appVersion ?? s.commonNoValue),
                onTap: () => _onAbout(context),
              ),
            ]),
            context.gapH(Insets.x6),
            _LogoutButton(onTap: () => _onLogoutTap(context)),
            groupGap,
            Center(
              child: Text(
                s.aboutFooter,
                textAlign: TextAlign.center,
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
const double _presenceDotInset = Insets.hair;

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
              InitialAvatar(name: user.displayName, size: _profileAvatarSize),
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
                // Odoo names can be a full four-part Arabic name; two lines is
                // enough to recognise it without pushing the card taller.
                Text(
                  user.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.titleLg.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                context.gapH(Insets.hair),
                // Logins are e-mail addresses: always left-to-right.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodySm.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                context.gapH(Insets.x1h),
                Container(
                  padding: context.padSym(h: Insets.x2h, v: Insets.x1),
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
                      context.gapW(Insets.x1),
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

/// Eyebrow above a settings group card.
class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) => SectionHeader.eyebrow(
        label: label,
        padding: const EdgeInsetsDirectional.only(
          start: Insets.x1h,
          bottom: Insets.x2,
        ),
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
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: context.r(Insets.x4),
        endIndent: context.r(Insets.x4),
        color: context.x.divider,
      );
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
      selected: selected,
      leading: Icon(icon, fill: selected ? 1 : 0, color: cs.onSurfaceVariant),
      title: Text(label, style: AppType.titleSm.copyWith(color: cs.onSurface)),
      trailing: selected
          ? Icon(Symbols.check_circle, fill: 1, color: cs.primary)
          : Icon(Symbols.radio_button_unchecked, color: context.x.textDisabled),
    );
  }
}

/// A tappable row that navigates / triggers an action (icon + title + optional
/// subtitle + a chevron).
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
          ? Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodySm.copyWith(color: context.x.textTertiary),
            )
          : null,
      // `chevron_right` carries `matchTextDirection`: Flutter points it left in
      // Arabic by itself. Picking `chevron_left` for RTL mirrored it twice.
      trailing: Icon(Symbols.chevron_right, color: context.x.textDisabled),
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

/// "Last sync" row. The subtitle is derived from the live queue — the count of
/// work still waiting, or when a queued action last actually reached the
/// server. It is never a fixed string: telling a field employee "synced just
/// now" while their GPS-stamped check-ins sit unsent is the one lie this row
/// must not tell.
class _SyncRow extends StatelessWidget {
  final bool syncing;
  final VoidCallback onSync;
  const _SyncRow({required this.syncing, required this.onSync});

  /// Stroke of the in-button spinner, thin to match the text button.
  static const double _spinnerStroke = 2.0;

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
        onPressed: syncing ? null : onSync,
        child: syncing
            ? SizedBox.square(
                dimension: context.r(IconSz.xs),
                child: const CircularProgressIndicator(strokeWidth: _spinnerStroke),
              )
            : Text(context.s.settingsSyncNow),
      ),
    );
  }
}

/// 54 — taller than a standard button. Sign-out is the one destructive action
/// on this screen and is deliberately given its own weight at the foot of it,
/// in the error *container* colour rather than [AppButton.destructive]'s solid
/// red, which would shout over the settings above it.
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
          padding: context.padSym(h: Insets.x4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Symbols.logout,
                  fill: 1, size: context.r(IconSz.sm), color: cs.error),
              context.gapW(Insets.x2),
              Flexible(
                child: Text(
                  context.s.commonLogout,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.button.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
