import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/utils/app_number.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/data/models/visit.dart';

/// Static (non-interactive) map preview showing every currently checked-in
/// employee at their check-in coordinates. Tapping a pin — or a row under the
/// map — opens that visit, so the manager can drill from "who's where right
/// now?" to "what are they doing?".
///
/// The map does not pan or zoom: it sits in a scrolling page, and the page
/// must scroll when a finger lands on it.
class DashboardActiveMapCard extends StatelessWidget {
  final List<Visit> visits;
  const DashboardActiveMapCard({super.key, required this.visits});

  /// Rows listed under the map; the rest are summarised as "+N more".
  static const int _maxListed = 3;

  /// Diameter of an employee pin on the map.
  static const double _pinSize = 38.0;

  /// Diameter of the initial in a row under the map.
  static const double _rowAvatarSize = 28.0;

  static void _open(BuildContext context, Visit visit) =>
      context.push(AppRoutes.visitDetail(visit.id), extra: visit);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // The same "checked in with a position" set feeds the pins, the rows and
    // the badge, so the three always agree. The dashboard's "Active now" tile
    // counts every running visit, including those with no position yet.
    final active = [
      for (final v in visits)
        if (v.isInProgress && v.hasCheckInLocation) v,
    ];
    final header = SectionHeader(
      icon: Icons.location_on_rounded,
      label: s.dashboardActiveOnMapTitle,
      trailing: active.isEmpty ? null : _CountBadge(value: active.length),
    );
    if (active.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            context.gapH(Insets.x2),
            InlineEmptyRow(
              icon: Icons.person_off_outlined,
              text: s.dashboardActiveEmpty,
            ),
          ],
        ),
      );
    }

    final points = [
      for (final v in active) LatLng(v.checkInLat!, v.checkInLng!),
    ];
    final cardPad = context.r(Insets.x3h);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                cardPad, cardPad, cardPad, context.r(Insets.x2h)),
            child: header,
          ),
          SizedBox(
            height: context.fixedH(CompSz.mapCard),
            child: AppMap(
              interactive: false,
              initialCenter: LatLngBounds.fromPoints(points).center,
              initialZoom: AppConstants.mapZoomDashboard,
              // Null for one employee (or several on one spot): fitting a
              // zero-size area produces an infinite zoom.
              initialCameraFit: AppMap.fitOrNull(
                points,
                padding: EdgeInsets.all(context.r(Insets.x10)),
              ),
              layers: [
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < active.length; i++)
                      Marker(
                        point: points[i],
                        width: _pinSize,
                        height: _pinSize,
                        child: GestureDetector(
                          onTap: () => _open(context, active[i]),
                          child: MapPin.label(
                            text: InitialAvatar.initialOf(
                                active[i].employeeName),
                            size: _pinSize,
                            // Map marks use fixed hues: the tiles look the
                            // same in both themes.
                            color: AppColors.green,
                            tooltip: active[i].employeeName,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: context.padSym(h: Insets.x2, v: Insets.x2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final v in active.take(_maxListed))
                  _ActiveRow(visit: v, onTap: () => _open(context, v)),
                if (active.length > _maxListed)
                  Padding(
                    padding: context.padSym(h: Insets.x4, v: Insets.x1),
                    child: Text(
                      s.dashboardActiveMore(active.length - _maxListed),
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
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

class _ActiveRow extends StatelessWidget {
  final Visit visit;
  final VoidCallback onTap;
  const _ActiveRow({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final x = context.x;
    return ListTile(
      visualDensity: VisualDensity.compact,
      leading: InitialAvatar(
        name: visit.employeeName,
        size: context.r(DashboardActiveMapCard._rowAvatarSize),
        background: x.successContainer,
        foreground: x.onSuccessContainer,
      ),
      title: Text(
        visit.employeeName ?? s.commonNoValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        visit.customerName ?? s.commonNoValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall,
      ),
      // Mirrors itself in RTL.
      trailing: Icon(Icons.chevron_right, color: context.colors.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int value;
  const _CountBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return TonePill(
      label: AppNumber.whole(value),
      color: context.x.success,
      fontSize: FontSz.md,
      fontWeight: FontWeight.w800,
      padding: context.padSym(h: Insets.x2h, v: Insets.x1),
      tintAlpha: Alphas.tintStrong,
      borderAlpha: Alphas.border,
    );
  }
}
