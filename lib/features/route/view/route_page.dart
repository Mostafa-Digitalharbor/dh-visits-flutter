import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/app_number.dart';
import '../../../core/utils/communications.dart';
import '../../../core/utils/distance.dart';
import '../../../shared/extensions/bloc_extensions.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../analytics/view/metric_tile.dart';
import '../../dashboard/view/visits_list_feedback.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/data/models/visit.dart';
import '../../visits/data/models/visit_location_log.dart';
import '../../visits/data/visits_repository.dart';
import '../bloc/day_trails_cubit.dart';
import 'route_map.dart';
import 'route_sections.dart';

/// Employee "today's route" tab (design screen 14).
///
/// What was recorded is the GPS trail of each visit started today, read back
/// from the server — each its own line, because location is recorded only
/// while a visit is in progress, never between visits.
///
/// Today's planned stops (visits with a customer location) are plotted too,
/// with a numbered, drive-time-annotated stop list.
class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DayTrailsCubit(repository: slMaybe<VisitsRepository>()),
      child: const _RouteBody(),
    );
  }
}

class _RouteBody extends StatefulWidget {
  const _RouteBody();

  @override
  State<_RouteBody> createState() => _RouteBodyState();
}

class _RouteBodyState extends State<_RouteBody> {
  /// Road-matched line by default; the raw GPS line stays one tap away.
  RouteLineMode _lineMode = RouteLineMode.roads;

  static const double _metersPerKm = 1000;

  /// A leg's drive time is shown between these bounds: never "0 min", and
  /// never wider than three digits.
  static const int _minDriveMinutes = 1;
  static const int _maxDriveMinutes = 999;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadTrails());
    });
  }

  Future<void> _loadTrails({bool force = false}) =>
      context.read<DayTrailsCubit>().load(
            DayTrailsCubit.startedOn(
              context.read<VisitsListBloc>().state.items,
              DateTime.now(),
            ),
            force: force,
          );

  /// Pull-to-refresh and every Retry: the stops and the visit trails,
  /// together — the spinner lasts until both are back.
  Future<void> _refresh() {
    final visits = context.read<VisitsListBloc>()
      ..add(const VisitsListLoadRequested());
    return Future.wait([
      visits.untilSettled((s) => s.status == VisitsListStatus.loading),
      _loadTrails(force: true),
    ]);
  }

  /// Today's visits with a customer location, in planned order.
  static List<Visit> _plannedStops(List<Visit> items, DateTime now) {
    final stops = [
      for (final v in items)
        if (v.hasCustomerLocation && v.isOnDay(now)) v,
    ];
    // `isOnDay` guarantees an effective date, so every visit has a time here.
    DateTime plannedAt(Visit v) => v.visitDate ?? v.effectiveDate!;
    return stops..sort((a, b) => plannedAt(a).compareTo(plannedAt(b)));
  }

  static int _driveMinutes(double meters) =>
      (meters / _metersPerKm / AppConstants.driveSpeedKmh * Duration.minutesPerHour)
          .round()
          .clamp(_minDriveMinutes, _maxDriveMinutes);

  @override
  Widget build(BuildContext context) {
    return VisitsRefreshFailureListener(
      child: BlocListener<VisitsListBloc, VisitsListState>(
        listenWhen: (p, c) => p.items != c.items,
        listener: (context, state) => _loadTrails(),
        child: BlocBuilder<VisitsListBloc, VisitsListState>(
          builder: (context, state) => _content(
            context,
            state,
            context.watch<DayTrailsCubit>().state,
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    VisitsListState state,
    DayTrailsState trailsState,
  ) {
    final s = context.s;
    final stops = _plannedStops(state.items, DateTime.now());
    final trails = trailsState.trails;
    final listFailed = state.status == VisitsListStatus.failure;
    final listError = state.error?.localize(context) ?? s.errUnknown;

    if (stops.isEmpty && trails.isEmpty) {
      final listPending = state.items.isEmpty &&
          (state.status == VisitsListStatus.loading ||
              state.status == VisitsListStatus.initial);
      if (listPending || trailsState.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      // Check failure before empty: a failed fetch rendering "no stops
      // today" tells the employee their day is clear when it isn't.
      final failure = listFailed
          ? listError
          : trailsState.failed > 0
              ? s.routeTrailsLoadFailed(trailsState.failed)
              : null;
      if (failure != null) {
        return ErrorView(message: failure, onRetry: _refresh);
      }
      return AppRefreshIndicator(
        onRefresh: _refresh,
        child: RefreshableEmptyView(icon: Symbols.route, message: s.routeEmpty),
      );
    }

    final points = [
      for (final v in stops) LatLng(v.customerLatitude!, v.customerLongitude!),
    ];
    final legs = [
      for (var i = 1; i < points.length; i++)
        haversineMeters(points[i - 1].latitude, points[i - 1].longitude,
            points[i].latitude, points[i].longitude),
    ];
    final stopsKm = legs.fold(0.0, (sum, m) => sum + m) / _metersPerKm;
    final nextIndex = stops.indexWhere((v) => !v.isDone);

    return Column(
      children: [
        // The map and the stop list are siblings in one Column, so without
        // a boundary every scroll of the list re-rasterises the map's tile
        // and marker layers underneath it.
        RepaintBoundary(
          // Road geometry is derived per recorded trace and cached; it is
          // recomputed only when a trace's points change.
          child: MatchedRouteBuilder(
            traces: [
              for (final t in trails) t.track.logs.trace,
            ],
            builder: (context, geometries) => RouteMap(
              stops: stops,
              points: points,
              nextIndex: nextIndex,
              stopsKm: stopsKm,
              trails: trails,
              trailGeometries: geometries,
              lineMode: _lineMode,
              onLineMode: (m) => setState(() => _lineMode = m),
            ),
          ),
        ),
        Expanded(
          child: AppRefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: context.padAll(Insets.screen),
              children: [
                // With stops already on screen a failed reload is reported by
                // the listener above; with none, the reason goes here.
                if (listFailed && state.items.isEmpty)
                  RouteNotice(message: listError, onRetry: _refresh),
                if (stops.isNotEmpty) ...[
                  MetricTileRow(
                    start: MetricTile(
                      icon: Symbols.pin_drop,
                      tone: context.colors.primary,
                      value: AppNumber.whole(stops.length),
                      label: s.routeStops,
                    ),
                    end: MetricTile(
                      icon: Symbols.route,
                      tone: context.x.warning,
                      value: AppNumber.km(s, stopsKm),
                      label: s.routeTotalDistance,
                    ),
                  ),
                  context.gapH(Insets.x4),
                  for (var i = 0; i < stops.length; i++)
                    RouteStopRow(
                      index: i,
                      visit: stops[i],
                      isNext: i == nextIndex,
                      isLast: i == stops.length - 1,
                      driveMinutes: i == 0 ? null : _driveMinutes(legs[i - 1]),
                    ),
                ],
                if (trails.isNotEmpty || trailsState.failed > 0)
                  RecordedTrailsSection(
                    trails: trails,
                    failed: trailsState.failed,
                    onRetry: () => _loadTrails(force: true),
                  ),
              ],
            ),
          ),
        ),
        if (stops.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                context.r(Insets.screen),
                0,
                context.r(Insets.screen),
                context.rh(Insets.x3),
              ),
              child: AppButton(
                label: s.routeStartNav,
                icon: Symbols.navigation,
                onPressed: () {
                  final next = stops[math.max(nextIndex, 0)];
                  context.openExternal(() => Communications.openInMaps(
                      next.customerLatitude!, next.customerLongitude!,
                      label: next.customerName));
                },
              ),
            ),
          ),
      ],
    );
  }
}
