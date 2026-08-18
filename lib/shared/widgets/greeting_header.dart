import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../extensions/context_extensions.dart';
import 'initial_avatar.dart';
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

  const GreetingHeader({
    super.key,
    required this.name,
    required this.roleLabel,
    required this.roleIcon,
    required this.done,
    required this.total,
    this.stats = const [],
  });

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    final pct = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final initial = InitialAvatar.initialOf(name);
    const white = Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Text(initial,
                    style: const TextStyle(
                        color: white, fontSize: FontSz.avatar, fontWeight: FontWeight.w800)),
              ),
              context.gapW(Insets.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Was wrapped in a bare `Row` purely to left-align, which
                    // handed the Text an unbounded width and overflowed once
                    // the greeting got long (Arabic, or a large font scale).
                    // The Column already aligns to the start.
                    Text('${context.s.dashboardGreeting} 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: white.withValues(alpha: 0.85),
                            fontSize: FontSz.base,
                            fontWeight: FontWeight.w600)),
                    context.gapH(Insets.hair),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: white, fontSize: FontSz.greeting, fontWeight: FontWeight.w800)),
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
          Row(
            children: [
              // The label yields; the count must not be truncated — it is the
              // number the whole header exists to show. With 1200/1200 · 100%
              // on a 320dp screen the two together do not fit.
              Flexible(
                child: Text(context.s.dashboardTodayProgress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: white.withValues(alpha: 0.85),
                        fontSize: FontSz.base,
                        fontWeight: FontWeight.w600)),
              ),
              context.gapW(Insets.x2),
              // ٪ in Arabic, % in English — the one place the sign was hard-coded.
              Text('$done/$total · ${(pct * 100).round()}${context.s.unitPercent}',
                  maxLines: 1,
                  style: const TextStyle(
                      color: white,
                      fontSize: FontSz.base,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          context.gapH(Insets.x2),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Stack(
              children: [
                Container(height: 8, color: white.withValues(alpha: 0.20)),
                LayoutBuilder(
                  builder: (_, c) => Container(
                    height: 8,
                    width: c.maxWidth * pct,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.pill),
                      gradient: const LinearGradient(
                          colors: [Colors.white, AppColors.cyan400]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (stats.isNotEmpty) ...[
            context.gapH(Insets.x3h),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) SizedBox(width: context.r(20)),
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
    const white = Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(stat.icon, size: 18, color: white.withValues(alpha: 0.85)),
        context.gapW(Insets.x1h),
        Text(stat.value,
            style: const TextStyle(
                color: white,
                fontSize: FontSz.lg,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()])),
        context.gapW(Insets.x1),
        Flexible(
          child: Text(stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: white.withValues(alpha: 0.82),
                  fontSize: FontSz.sm,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
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
      color: Colors.white,
      tintAlpha: 0.18,
      fontSize: FontSz.sm,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}
