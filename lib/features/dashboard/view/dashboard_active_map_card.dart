import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/data/models/visit.dart';

/// Static (non-interactive) map preview showing every currently
/// checked-in employee at their last recorded coordinates. Tapping a
/// pin opens the associated visit detail — the admin can drill from
/// "who's where right now?" to "what are they doing?".
class DashboardActiveMapCard extends StatelessWidget {
  final List<Visit> visits;
  const DashboardActiveMapCard({super.key, required this.visits});

  @override
  Widget build(BuildContext context) {
    final active = visits
        .where((v) =>
            v.isInProgress && v.hasCheckInLocation)
        .toList();
    if (active.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.location_on_rounded,
              label: context.s.dashboardActiveOnMapTitle,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.person_off_outlined,
                      size: 20, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.s.dashboardActiveEmpty,
                      style: TextStyle(
                          color: context.colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final points = active
        .map((v) => LatLng(v.checkInLat!, v.checkInLng!))
        .toList();
    final bounds = LatLngBounds.fromPoints(points);
    // CameraFit.bounds divides by the bounds' span to derive a zoom; a single
    // active visit (or several at the exact same spot) gives a zero-span box,
    // producing an Infinity/NaN zoom that crashes the tile layer. Only fit when
    // the points actually span an area, otherwise centre on them at a fixed zoom.
    final latSpan = (bounds.north - bounds.south).abs();
    final lngSpan = (bounds.east - bounds.west).abs();
    final canFitBounds = latSpan > 1e-4 && lngSpan > 1e-4;
    final mapCenter = LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );
    final isDark = context.isDark;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: SectionHeader(
                    icon: Icons.location_on_rounded,
                    label: context.s.dashboardActiveOnMapTitle,
                  ),
                ),
                _CountBadge(value: active.length),
              ],
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: SizedBox(
              height: 220,
              child: AbsorbPointer(
                // Block gesture forwarding into the map so the admin can
                // scroll past it. The buttons inside are still tappable
                // because they sit above this in the stack.
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: AppConstants.mapZoomDashboard,
                    initialCameraFit: canFitBounds
                        ? CameraFit.bounds(
                            bounds: bounds,
                            padding: const EdgeInsets.all(40),
                          )
                        : null,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                    backgroundColor: AppColors.mapBackground(isDark),
                  ),
                  children: [
                    const AppMapTileLayer(maxZoom: AppConstants.mapMaxZoom),
                    MarkerLayer(
                      markers: [
                        for (final v in active)
                          Marker(
                            point: LatLng(v.checkInLat!, v.checkInLng!),
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            child: _ActivePin(name: v.employeeName ?? '?'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              children: [
                for (final v in active.take(3))
                  ListTile(
                    visualDensity: VisualDensity.compact,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        InitialAvatar.initialOf(v.employeeName),
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      v.employeeName ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      v.customerName ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: context.colors.onSurfaceVariant),
                    onTap: () => context.push(AppRoutes.visitDetail(v.id), extra: v),
                  ),
                if (active.length > 3)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        context.s.dashboardActiveMore(active.length - 3),
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

class _ActivePin extends StatelessWidget {
  final String name;
  const _ActivePin({required this.name});

  @override
  Widget build(BuildContext context) => MapPin.label(
        text: InitialAvatar.initialOf(name),
        size: 38,
        // Green: these pins mean "checked in right now".
        gradient: LinearGradient(
          colors: [Colors.green.shade500, Colors.green.shade800],
        ),
      );
}

class _CountBadge extends StatelessWidget {
  final int value;
  const _CountBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade600.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
            color: Colors.green.shade600.withValues(alpha: 0.30)),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
