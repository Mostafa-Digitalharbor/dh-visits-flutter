import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/communications.dart';
import '../../../core/utils/distance.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/data/models/visit.dart';

/// Employee "today's route" tab (design screen 14). Plots today's stops on a
/// map with a connecting polyline + a numbered, drive-time-annotated stop
/// list. Derived from today's visits that have a customer location.
class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VisitsListBloc, VisitsListState>(
      builder: (context, state) {
        final now = DateTime.now();
        bool isToday(DateTime? d) {
          final l = d?.toLocal();
          return l != null && l.year == now.year && l.month == now.month && l.day == now.day;
        }

        final stops = state.items
            .where((v) => v.hasCustomerLocation && isToday(v.effectiveDate ?? v.visitDate))
            .toList()
          ..sort((a, b) => (a.visitDate ?? a.effectiveDate ?? DateTime(0))
              .compareTo(b.visitDate ?? b.effectiveDate ?? DateTime(0)));

        // Check failure before empty: a failed fetch rendering "no stops
        // today" tells the employee their day is clear when it isn't.
        if (state.status == VisitsListStatus.failure) {
          return ErrorView(
            message: state.error?.localize(context) ?? context.s.errUnknown,
            onRetry: () => context
                .read<VisitsListBloc>()
                .add(const VisitsListLoadRequested()),
          );
        }
        if (stops.isEmpty) {
          return EmptyView(icon: Symbols.route, message: context.s.routeEmpty);
        }

        final points = stops.map((v) => LatLng(v.customerLatitude!, v.customerLongitude!)).toList();
        double meters = 0;
        for (var i = 1; i < points.length; i++) {
          meters += haversineMeters(points[i - 1].latitude, points[i - 1].longitude,
              points[i].latitude, points[i].longitude);
        }
        final km = (meters / 1000);
        final nextIndex = stops.indexWhere((v) => !v.isDone);

        return Column(
          children: [
            _RouteMap(stops: stops, points: points, nextIndex: nextIndex, km: km),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: context.s.routeStops,
                          value: '${stops.length}',
                          icon: Symbols.pin_drop,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryTile(
                          label: context.s.routeTotalDistance,
                          value: context.s.unitKm(km.toStringAsFixed(1)),
                          icon: Symbols.route,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < stops.length; i++)
                    _StopRow(
                      index: i,
                      visit: stops[i],
                      isNext: i == nextIndex,
                      isLast: i == stops.length - 1,
                      driveMinutes: i == 0
                          ? null
                          : _driveMinutes(haversineMeters(points[i - 1].latitude,
                              points[i - 1].longitude, points[i].latitude, points[i].longitude)),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AppButton(
                  label: context.s.routeStartNav,
                  icon: Symbols.navigation,
                  onPressed: () {
                    final first = stops[nextIndex < 0 ? 0 : nextIndex];
                    context.openExternal(() => Communications.openInMaps(
                        first.customerLatitude!, first.customerLongitude!,
                        label: first.customerName));
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static int _driveMinutes(double meters) =>
      (meters / 1000 / AppConstants.driveSpeedKmh * 60).round().clamp(1, 999);
}

class _RouteMap extends StatelessWidget {
  final List<Visit> stops;
  final List<LatLng> points;
  final int nextIndex;
  final double km;
  const _RouteMap(
      {required this.stops, required this.points, required this.nextIndex, required this.km});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final isDark = context.isDark;
    // CameraFit.bounds throws (NaN/Infinity zoom) when the stops collapse to a
    // single distinct point. Only fit when there are ≥2 distinct points;
    // otherwise centre on the lone stop at a fixed zoom.
    final distinctPoints = points.toSet();
    final useFit = distinctPoints.length >= 2;
    final center = points.isNotEmpty
        ? points.first
        : const LatLng(AppConstants.mapFallbackLat, AppConstants.mapFallbackLng);
    return SizedBox(
      // A flat 280 is most of a landscape viewport: the sibling Expanded list
      // gets squeezed to nothing and the Column overflows. Cap it against the
      // screen so the stop list — the point of the screen — keeps its share.
      // In portrait this resolves to ~278, i.e. the design height.
      height: math.min(280, context.hp(0.33)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: AppConstants.mapZoomRoute,
              initialCameraFit: useFit
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(48),
                    )
                  : null,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              backgroundColor: AppColors.mapBackground(isDark),
            ),
            children: [
              const AppMapTileLayer(),
              PolylineLayer(polylines: [
                Polyline(points: points, strokeWidth: 3, color: Colors.white, borderStrokeWidth: 1, borderColor: cs.primary),
              ]),
              MarkerLayer(markers: [
                for (var i = 0; i < points.length; i++)
                  Marker(
                    point: points[i],
                    width: 32,
                    height: 32,
                    child: _NumberPin(n: i + 1, isNext: i == nextIndex, x: x),
                  ),
              ]),
            ],
          ),
          if (isDark)
            IgnorePointer(child: Container(color: Colors.black.withValues(alpha: 0.22))),
          PositionedDirectional(
            top: 12,
            start: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(Radii.pill)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.route, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                      '${stops.length} ${context.s.routeStops} · ${context.s.unitKm(km.toStringAsFixed(1))}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberPin extends StatelessWidget {
  final int n;

  /// The next stop is highlighted with the brand gradient; the rest are ink.
  final bool isNext;
  final AppX x;
  const _NumberPin({required this.n, required this.isNext, required this.x});

  @override
  Widget build(BuildContext context) => MapPin.label(
        text: '$n',
        size: 32,
        borderWidth: 2,
        gradient: isNext ? x.avatarGradient : null,
        color: isNext ? null : AppColors.ink,
      );
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: x.outlineVariant),
        boxShadow: x.elev1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: x.textTertiary),
            const Spacer(),
          ]),
          const SizedBox(height: 8),
          Text(value, style: AppType.number(20, cs.onSurface)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: x.textTertiary)),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final int index;
  final Visit visit;
  final bool isNext;
  final bool isLast;
  final int? driveMinutes;
  const _StopRow(
      {required this.index,
      required this.visit,
      required this.isNext,
      required this.isLast,
      required this.driveMinutes});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final timeFmt = AppDate.timeFormat(context);
    final eta = visit.visitDate != null ? timeFmt.format(visit.visitDate!) : '—';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.pill), boxShadow: isNext ? x.glowBrand : null),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isNext ? x.avatarGradient : null,
                    color: isNext ? null : cs.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          color: isNext ? Colors.white : cs.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: x.divider, margin: const EdgeInsets.symmetric(vertical: 4))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () =>
                  context.push(AppRoutes.visitDetail(visit.id), extra: visit),
              child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(visit.customerName ?? '#${visit.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.titleSm.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
                      ),
                      if (isNext)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(Radii.pill)),
                          child: Text(context.s.routeNextStop,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Flexible + ellipsis on both labels: "09:30 · Start point"
                  // plus "25 min drive" already exceeds a 320dp row at the
                  // 1.25 text-scale cap, and Arabic runs longer still.
                  Row(
                    children: [
                      Icon(Symbols.schedule, size: 14, color: x.textTertiary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          index == 0 ? '$eta · ${context.s.routeStartPoint}' : eta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: x.textTertiary),
                        ),
                      ),
                      if (driveMinutes != null) ...[
                        const SizedBox(width: 10),
                        Icon(Symbols.directions_car, size: 14, color: x.textTertiary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            context.s.routeDriveMinutes(driveMinutes!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: x.textTertiary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
