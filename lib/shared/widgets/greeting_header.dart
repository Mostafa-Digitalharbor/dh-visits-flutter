import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/app_number.dart';
import '../extensions/context_extensions.dart';
import 'initial_avatar.dart';
import 'progress_track.dart';
import 'tone_pill.dart';

/// Brand-gradient greeting/day header used on the manager dashboard and the
/// employee "my visits" screen. Matches design screens 02 + 10.
class GreetingHeader extends StatelessWidget {
  final String name;
  final String roleLabel;
  final IconData roleIcon;
  final int done;
  final int total;

  /// Optional trailing stats shown under the progress bar (e.g. field time).
  final List<GreetingStat> stats;

  /// The current time, for the greeting. Injectable for tests.
  final DateTime Function() now;

  const GreetingHeader({
    super.key,
    required this.name,
    required this.roleLabel,
    required this.roleIcon,
    required this.done,
    required this.total,
    this.stats = const [],
    this.now = DateTime.now,
  });

  /// Hours (local) at which the greeting changes.
  static const int _afternoonFrom = 12;
  static const int _eveningFrom = 17;

  /// A friendly mark after the greeting. Not a word, so not in the ARBs.
  static const String _wave = '👋';

  /// Text and chrome on the brand gradient.
  static const Color _onBrand = AppColors.onMap;

  String _greeting(BuildContext context) {
    final hour = now().hour;
    final s = context.s;
    if (hour >= _eveningFrom) return s.commonGreetingEvening;
    if (hour >= _afternoonFrom) return s.commonGreetingAfternoon;
    return s.commonGreetingMorning;
  }

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    final pct = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final muted = _onBrand.withValues(alpha: Alphas.onBrandMuted);

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        context.r(Insets.x4h),
        context.r(Insets.x4h),
        context.r(Insets.x4h),
        context.r(Insets.x4),
      ),
      decoration: BoxDecoration(
        gradient: x.brandGradient,
        borderRadius: BorderRadius.circular(Radii.xl),
        boxShadow: x.elev2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialAvatar(
                name: name,
                size: context.r(CompSz.avatar),
                background: _onBrand.withValues(alpha: Alphas.wash),
                foreground: _onBrand,
              ),
              context.gapW(Insets.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_greeting(context)} $_wave',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: muted,
                            fontSize: FontSz.base,
                            fontWeight: FontWeight.w600)),
                    context.gapH(Insets.hair),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _onBrand,
                            fontSize: FontSz.greeting,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              context.gapW(Insets.x2),
              // Flexible, not a bare child: a Row lays its inflexible children
              // out at their intrinsic width *first*, so a long role label
              // ("مدير المشروع") took the space the Expanded above needed and
              // pushed the whole header past the card.
              Flexible(child: _RoleChip(label: roleLabel, icon: roleIcon)),
            ],
          ),
          context.gapH(Insets.x4),
          // The label yields; the count must not be truncated — it is the
          // number the whole header exists to show. With 1200/1200 · 100%
          // on a 320dp screen the two together do not fit, and at the 1.25×
          // text cap the count alone is wider than the card, so it overflowed.
          // It now scales down only when it cannot fit, and is left alone
          // otherwise. A Row gives an inflexible child unbounded width, so the
          // LayoutBuilder supplies the bound.
          LayoutBuilder(
            builder: (context, box) {
              final gap = context.r(Insets.x2);
              return Row(
                children: [
                  Flexible(
                    child: Text(context.s.dashboardTodayProgress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: muted,
                            fontSize: FontSz.base,
                            fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(width: gap),
                  _ScaleDownTo(
                    maxWidth: box.maxWidth - gap,
                    child: Text(
                        context.joinFacts([
                          context.s.commonFraction(
                              AppNumber.whole(done), AppNumber.whole(total)),
                          AppNumber.percent(context.s, (pct * 100).round()),
                        ]),
                        maxLines: 1,
                        style: const TextStyle(
                            color: _onBrand,
                            fontSize: FontSz.base,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ],
              );
            },
          ),
          context.gapH(Insets.x2),
          ProgressTrack(
            value: pct,
            height: context.r(CompSz.headerTrackHeight),
            trackColor: _onBrand.withValues(alpha: Alphas.onBrandTrack),
            gradient: const LinearGradient(
              colors: [_onBrand, AppColors.cyan400],
            ),
          ),
          if (stats.isNotEmpty) ...[
            context.gapH(Insets.x3h),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) context.gapW(Insets.x5),
                  Flexible(child: _Stat(stat: stats[i])),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class GreetingStat {
  final IconData icon;
  final String value;
  final String label;
  const GreetingStat({required this.icon, required this.value, required this.label});
}

class _Stat extends StatelessWidget {
  final GreetingStat stat;
  const _Stat({required this.stat});

  @override
  Widget build(BuildContext context) {
    const onBrand = GreetingHeader._onBrand;
    final muted = onBrand.withValues(alpha: Alphas.onBrandMuted);
    final iconSize = context.r(IconSz.label);
    final gapBefore = context.r(Insets.x1h);
    final gapAfter = context.r(Insets.x1);
    // Same rule as the count: the value is never cut. A normal full day
    // ("12.5 h") on a 320dp screen at 1.25× is wider than this stat's share
    // of the row and used to overflow. Now the value scales down and the
    // label gives up its space.
    return LayoutBuilder(
      builder: (context, box) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stat.icon, size: iconSize, color: muted),
          SizedBox(width: gapBefore),
          _ScaleDownTo(
            maxWidth: box.maxWidth - iconSize - gapBefore - gapAfter,
            child: Text(stat.value,
                maxLines: 1,
                style: const TextStyle(
                    color: onBrand,
                    fontSize: FontSz.lg,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
          SizedBox(width: gapAfter),
          Flexible(
            child: Text(stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: muted,
                    fontSize: FontSz.sm,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Shows [child] at its natural size, or scaled down to [maxWidth] when it is
/// wider. It is never clipped, ellipsized or allowed to overflow.
class _ScaleDownTo extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const _ScaleDownTo({required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth.clamp(0.0, double.infinity),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      );
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _RoleChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    // Flexible label: this chip sits inside a bounded header row, and has to
    // yield to it rather than force its intrinsic width onto it.
    return TonePill(
      label: label,
      icon: icon,
      flexibleLabel: true,
      color: GreetingHeader._onBrand,
      tintAlpha: Alphas.wash,
      fontSize: FontSz.sm,
      padding: context.padSym(h: Insets.x2h, v: Insets.x1h),
    );
  }
}
