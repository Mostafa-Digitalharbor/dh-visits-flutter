import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../extensions/context_extensions.dart';

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
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
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
                        color: white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('${context.s.dashboardGreeting} 👋',
                            style: TextStyle(
                                color: white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: white, fontSize: 22, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              _RoleChip(label: roleLabel, icon: roleIcon),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(context.s.dashboardTodayProgress,
                  style: TextStyle(
                      color: white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$done/$total · ${(pct * 100).round()}%',
                  style: const TextStyle(
                      color: white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 8, color: white.withValues(alpha: 0.20)),
                LayoutBuilder(
                  builder: (_, c) => Container(
                    height: 8,
                    width: c.maxWidth * pct,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                          colors: [Colors.white, AppColors.cyan400]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 20),
                  _Stat(stat: stats[i]),
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
        const SizedBox(width: 6),
        Text(stat.value,
            style: const TextStyle(
                color: white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(width: 4),
        Text(stat.label,
            style: TextStyle(
                color: white.withValues(alpha: 0.82),
                fontSize: 12,
                fontWeight: FontWeight.w500)),
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
    const white = Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, fill: 1, size: 15, color: white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
