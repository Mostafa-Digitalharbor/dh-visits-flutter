import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../core/map_matching/route_geometry.dart';
import '../extensions/context_extensions.dart';

/// Which line a route map draws.
enum RouteLineMode {
  /// Matched to the roads travelled, where a trustworthy match exists.
  roads,

  /// Straight lines between the recorded GPS fixes, exactly as stored.
  raw,
}

/// The switch between the road-matched line and the raw GPS line, with the
/// matching state underneath: "matching…" while it runs, and a plain notice
/// when no road match was possible so the raw line is what is shown.
class RouteLineToggle extends StatelessWidget {
  final RouteLineMode mode;
  final ValueChanged<RouteLineMode> onChanged;

  /// Road matching is still running for part of what is drawn.
  final bool pending;

  /// Nothing drawn could be matched to roads (and matching is finished).
  final bool unmatched;

  const RouteLineToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    this.pending = false,
    this.unmatched = false,
  });

  /// Combined state of several geometries drawn on one map.
  static ({bool pending, bool unmatched}) stateOf(
      Iterable<RouteGeometry> geometries) {
    final drawn = geometries.where((g) => g.edges.isNotEmpty).toList();
    final pending = drawn.any((g) => g.pending);
    return (
      pending: pending,
      unmatched: drawn.isNotEmpty &&
          !pending &&
          drawn.every((g) => g.source == RouteGeometrySource.raw),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final String? note = mode != RouteLineMode.roads
        ? null
        : pending
            ? s.routeLineMatching
            : unmatched
                ? s.routeLineUnmatched
                : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Segment(
                label: s.routeLineRoads,
                icon: Symbols.route,
                selected: mode == RouteLineMode.roads,
                onTap: () => onChanged(RouteLineMode.roads),
              ),
              _Segment(
                label: s.routeLineGps,
                icon: Symbols.my_location,
                selected: mode == RouteLineMode.raw,
                onTap: () => onChanged(RouteLineMode.raw),
              ),
            ],
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pending)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: 6),
                      child: SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: Colors.white),
                      ),
                    ),
                  Flexible(
                    child: Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: FontSz.xs,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.ink : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              context.gapW(Insets.x1),
              Text(label,
                  style: TextStyle(
                      color: fg,
                      fontSize: FontSz.xs,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
