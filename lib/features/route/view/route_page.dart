import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/design/app_decor.dart';
import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/map_matching/route_geometry.dart';
import '../../../core/map_matching/route_matcher.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/communications.dart';
import '../../../core/utils/distance.dart';
import '../../../core/utils/user_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/data/models/visit.dart';
import '../../visits/data/models/visit_location_log.dart';
import '../../visits/data/visits_repository.dart';
import '../../workday/data/models/workday_models.dart';
import '../../workday/data/workday_repository.dart';
import '../../workday/data/workday_tracker.dart';
import '../bloc/day_trails_cubit.dart';
import '../bloc/workday_route_cubit.dart';

/// One colour per visit, so several visits on the same day read as separate
/// stretches rather than one tangle.
const List<Color> _trailPalette = [
  Color(0xFF1E88E5),
  Color(0xFF8E24AA),
  Color(0xFFF4511E),
  Color(0xFF00897B),
  Color(0xFFC0CA33),
  Color(0xFF6D4C41),
];

Color _trailColor(int i) => _trailPalette[i % _trailPalette.length];

/// The work-day line outside visits: the movement between them.
const Color _movementColor = Color(0xFF455A64);

/// Visit ids in the order the day reached them — the numbering and colours
/// shared by the map pins and the list below it.
List<int> _visitOrder(List<WorkdayRoute> routes) {
  final out = <int>[];
  for (final r in routes) {
    for (final s in r.visitSegments) {
      if (!out.contains(s.visitId)) out.add(s.visitId!);
    }
  }
  return out;
}

/// Employee "today's route" tab (design screen 14).
///
/// The recorded route is the **work day** read back from the server: every
/// point between "Start work day" and "End work day", including the movement
/// between visits, with each visit's own stretch highlighted in its colour.
/// It is never assembled from the visit trails — those only cover the time
/// inside visits.
///
/// Without a work day for today (none was started, or the server has no
/// work-day store) it falls back to what it showed before: the recorded trail
/// of each visit started today, each its own line.
///
/// Today's planned stops (visits with a customer location) are plotted too,
/// with a numbered, drive-time-annotated stop list.
class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              DayTrailsCubit(repository: slMaybe<VisitsRepository>()),
        ),
        BlocProvider(
          create: (_) => WorkdayRouteCubit(
            repository: slMaybe<WorkdayRepository>(),
            sessionStorage: slMaybe<SessionStorage>(),
            tracker: slMaybe<WorkdayTracker>(),
          ),
        ),
      ],
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadTrails(context.read<VisitsListBloc>().state);
      context.read<WorkdayRouteCubit>().load();
    });
  }

  void _loadTrails(VisitsListState list, {bool force = false}) {
    context.read<DayTrailsCubit>().load(
          DayTrailsCubit.startedOn(list.items, DateTime.now()),
          force: force,
        );
  }

  Future<void> _refresh() async {
    _loadTrails(context.read<VisitsListBloc>().state, force: true);
    await context.read<WorkdayRouteCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VisitsListBloc, VisitsListState>(
      listenWhen: (p, c) => p.items != c.items,
      listener: (context, state) => _loadTrails(state),
      child: BlocBuilder<VisitsListBloc, VisitsListState>(
        builder: (context, state) {
          final trailsState = context.watch<DayTrailsCubit>().state;
          final dayState = context.watch<WorkdayRouteCubit>().state;
          return _build(context, state, trailsState, dayState);
        },
      ),
    );
  }

  Widget _build(
    BuildContext context,
    VisitsListState state,
    DayTrailsState trailsState,
    WorkdayRouteState dayState,
  ) {
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
    final dayRoutes = [
      for (final r in dayState.routes)
        if (r.logs.isNotEmpty) r,
    ];
    // The work-day route already contains every visit's stretch; drawing the
    // per-visit trails on top would only draw the same movement twice.
    final trails = dayRoutes.isEmpty ? trailsState.trails : const <DayTrail>[];

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
    if (stops.isEmpty && trails.isEmpty && dayRoutes.isEmpty) {
      if (trailsState.loading || dayState.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: c.maxHeight,
              child: EmptyView(icon: Symbols.route, message: context.s.routeEmpty),
            ),
          ),
        ),
      );
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
        // The map and the stop list are siblings in one Column, so without
        // a boundary every scroll of the list re-rasterises the map's tile
        // and marker layers underneath it.
        RepaintBoundary(
          // Road geometry is derived per recorded trace and cached; it is
          // recomputed only when a trace's points change.
          child: MatchedRouteBuilder(
            traces: [
              for (final r in dayRoutes) r.logs.trace,
              for (final t in trails) t.track.logs.trace,
            ],
            builder: (context, geometries) => _RouteMap(
              stops: stops,
              points: points,
              nextIndex: nextIndex,
              km: km,
              trails: trails,
              dayRoutes: dayRoutes,
              dayGeometries: geometries.take(dayRoutes.length).toList(),
              trailGeometries: geometries.skip(dayRoutes.length).toList(),
              lineMode: _lineMode,
              onLineMode: (m) => setState(() => _lineMode = m),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                if (dayRoutes.isNotEmpty)
                  _WorkdaySection(routes: dayRoutes, visits: state.items),
                if (dayState.failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(context.s.routeWorkdayFailed,
                        style: TextStyle(fontSize: FontSz.sm, color: context.colors.error)),
                  ),
                if (stops.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: context.s.routeStops,
                          value: '${stops.length}',
                          icon: Symbols.pin_drop,
                        ),
                      ),
                      context.gapW(Insets.x3),
                      Expanded(
                        child: _SummaryTile(
                          label: context.s.routeTotalDistance,
                          value: context.s.unitKm(km.toStringAsFixed(1)),
                          icon: Symbols.route,
                        ),
                      ),
                    ],
                  ),
                  context.gapH(Insets.x4),
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
                if (dayRoutes.isEmpty && (trails.isNotEmpty || trailsState.failed > 0))
                  _RecordedTrails(
                    trails: trails,
                    failed: trailsState.failed,
                  ),
              ],
            ),
          ),
        ),
        if (stops.isNotEmpty)
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
  }

  static int _driveMinutes(double meters) =>
      (meters / 1000 / AppConstants.driveSpeedKmh * 60).round().clamp(1, 999);
}

class _RouteMap extends StatelessWidget {
  final List<Visit> stops;
  final List<LatLng> points;
  final int nextIndex;
  final double km;
  final List<DayTrail> trails;
  final List<WorkdayRoute> dayRoutes;

  /// Road-matched geometry of each of [dayRoutes] / [trails], same order.
  final List<RouteGeometry> dayGeometries;
  final List<RouteGeometry> trailGeometries;
  final RouteLineMode lineMode;
  final ValueChanged<RouteLineMode> onLineMode;
  const _RouteMap({
    required this.stops,
    required this.points,
    required this.nextIndex,
    required this.km,
    required this.trails,
    required this.dayRoutes,
    required this.dayGeometries,
    required this.trailGeometries,
    required this.lineMode,
    required this.onLineMode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final isDark = context.isDark;
    // The recorded fixes. Markers and the camera fit always use these.
    final trailPoints = [
      for (final t in trails)
        [for (final l in t.track.logs) LatLng(l.latitude, l.longitude)],
    ];
    final dayPoints = [
      for (final r in dayRoutes)
        [for (final l in r.logs) LatLng(l.latitude, l.longitude)],
    ];
    // The lines: road-matched where a match exists, else the fixes joined.
    final roads = lineMode == RouteLineMode.roads;
    final trailLines = [
      for (var i = 0; i < trails.length; i++)
        roads && i < trailGeometries.length
            ? trailGeometries[i].path()
            : trailPoints[i],
    ];
    final dayLines = [
      for (var i = 0; i < dayRoutes.length; i++)
        roads && i < dayGeometries.length ? dayGeometries[i].path() : dayPoints[i],
    ];
    List<LatLng> visitLine(int route, RouteSegment seg) =>
        roads && route < dayGeometries.length
            ? dayGeometries[route].path(seg.start, seg.end)
            : dayPoints[route].sublist(seg.start, seg.end + 1);
    final matching = RouteLineToggle.stateOf([...dayGeometries, ...trailGeometries]);
    final showToggle = (slMaybe<RouteMatcher>()?.enabled ?? false) &&
        (dayPoints.any((p) => p.length > 1) || trailPoints.any((p) => p.length > 1));
    final visitOrder = _visitOrder(dayRoutes);
    final dayKm = dayRoutes.fold<double>(0, (sum, r) => sum + r.distanceKm);
    // Every recorded vertex joins the planned stops in the camera fit, so a
    // route that wandered away from the customers still sits inside the frame.
    final allPoints = [
      ...points,
      for (final p in trailPoints) ...p,
      for (final p in dayPoints) ...p,
    ];
    // CameraFit.bounds throws (NaN/Infinity zoom) when the stops collapse to a
    // single distinct point. Only fit when there are ≥2 distinct points;
    // otherwise centre on the lone stop at a fixed zoom.
    final distinctPoints = allPoints.toSet();
    final useFit = distinctPoints.length >= 2;
    final center = allPoints.isNotEmpty
        ? allPoints.first
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
            // `initialCameraFit` only applies on creation; re-key when the
            // recorded routes arrive so the frame takes them in.
            key: ValueKey(allPoints.length),
            options: MapOptions(
              initialCenter: center,
              initialZoom: AppConstants.mapZoomRoute,
              initialCameraFit: useFit
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(allPoints),
                      // Extra room at the top: the summary chip overlays it,
                      // and a work-day end flag there was drawn underneath.
                      padding: const EdgeInsets.fromLTRB(48, 72, 48, 40),
                    )
                  : null,
              // Zoomable, like the visit map card: at whole-day scale a turn
              // is a few pixels, and comparing the road-matched line with the
              // raw GPS line needs a closer look. Rotation stays off.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.scrollWheelZoom,
              ),
              backgroundColor: AppColors.mapBackground(isDark),
            ),
            children: [
              const AppMapTileLayer(),
              if (points.length > 1)
                PolylineLayer(polylines: [
                  Polyline(points: points, strokeWidth: 3, color: Colors.white, borderStrokeWidth: 1, borderColor: cs.primary),
                ]),
              // Fallback only: one polyline per visit, never joined.
              PolylineLayer(polylines: [
                for (var i = 0; i < trails.length; i++)
                  if (trailLines[i].length > 1)
                    Polyline(
                      points: trailLines[i],
                      strokeWidth: 4,
                      color: _trailColor(i),
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.white,
                    ),
              ]),
              if (dayRoutes.isNotEmpty) ...[
                // The whole day, in the movement colour…
                PolylineLayer(polylines: [
                  for (var i = 0; i < dayRoutes.length; i++)
                    if (dayLines[i].length > 1)
                      Polyline(
                        points: dayLines[i],
                        strokeWidth: 4,
                        color: _movementColor,
                        borderStrokeWidth: 1.5,
                        borderColor: Colors.white,
                      ),
                ]),
                // …with each visit's stretch drawn over it in the visit's colour.
                PolylineLayer(polylines: [
                  for (var i = 0; i < dayRoutes.length; i++)
                    for (final seg in dayRoutes[i].visitSegments)
                      if (seg.length > 1)
                        Polyline(
                          points: visitLine(i, seg),
                          strokeWidth: 6,
                          color: _trailColor(visitOrder.indexOf(seg.visitId!)),
                          borderStrokeWidth: 1.5,
                          borderColor: Colors.white,
                        ),
                ]),
              ],
              MarkerLayer(markers: [
                for (var i = 0; i < trails.length; i++) ...[
                  Marker(
                    point: trailPoints[i].first,
                    width: 16,
                    height: 16,
                    child: _TrailEndDot(color: Colors.green.shade600),
                  ),
                  if (trailPoints[i].length > 1)
                    Marker(
                      point: trailPoints[i].last,
                      width: 16,
                      height: 16,
                      child: _TrailEndDot(color: _trailColor(i)),
                    ),
                ],
                for (var i = 0; i < dayRoutes.length; i++)
                  ..._dayMarkers(context, dayRoutes[i], dayPoints[i], visitOrder),
                for (var i = 0; i < points.length; i++)
                  Marker(
                    point: points[i],
                    width: 32,
                    height: 32,
                    child: _NumberPin(n: i + 1, isNext: i == nextIndex, x: x),
                  ),
              ]),
              const AppMapAttribution(),
            ],
          ),
          if (isDark)
            IgnorePointer(child: Container(color: Colors.black.withValues(alpha: 0.22))),
          if (showToggle)
            PositionedDirectional(
              top: 12,
              end: 12,
              child: RouteLineToggle(
                mode: lineMode,
                onChanged: onLineMode,
                pending: matching.pending,
                unmatched: matching.unmatched,
              ),
            ),
          if (stops.isNotEmpty || dayRoutes.isNotEmpty)
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
                    context.gapW(Insets.x1h),
                    Text(
                        stops.isNotEmpty
                            ? '${stops.length} ${context.s.routeStops} · ${context.s.unitKm(km.toStringAsFixed(1))}'
                            : '${context.s.routeWorkdayTitle} · ${context.s.unitKm(dayKm.toStringAsFixed(1))}',
                        style: const TextStyle(color: Colors.white, fontSize: FontSz.sm, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Work-day start and end (or the current position while the day is open),
  /// and a numbered pin where each visit's stretch begins.
  static List<Marker> _dayMarkers(
    BuildContext context,
    WorkdayRoute route,
    List<LatLng> pts,
    List<int> visitOrder,
  ) {
    final logs = route.logs;
    final s = context.s;
    final startIdx = math.max(0, logs.indexWhere((l) => l.isStart));
    final lastEnd = logs.lastIndexWhere((l) => l.isEnd);
    final endIdx = route.session.isActive || lastEnd < 0 ? logs.length - 1 : lastEnd;
    return [
      for (final seg in route.visitSegments)
        Marker(
          point: pts[seg.start],
          width: 28,
          height: 28,
          child: MapPin.label(
            text: '${visitOrder.indexOf(seg.visitId!) + 1}',
            size: 26,
            borderWidth: 2,
            color: _trailColor(visitOrder.indexOf(seg.visitId!)),
            tooltip: route.visitRefs[seg.visitId],
          ),
        ),
      if (endIdx != startIdx)
        Marker(
          point: pts[endIdx],
          width: 36,
          height: 36,
          child: route.session.isActive
              ? MapPin.icon(
                  icon: Symbols.navigation,
                  color: context.colors.primary,
                  size: 30,
                  tooltip: s.routeWorkdayNow,
                )
              : MapPin.icon(
                  icon: Symbols.flag,
                  color: Colors.deepOrangeAccent.shade200,
                  size: 30,
                  tooltip: s.routeWorkdayEnd,
                ),
        ),
      Marker(
        point: pts[startIdx],
        width: 36,
        height: 36,
        child: MapPin.icon(
          icon: Symbols.trip_origin,
          color: Colors.green.shade600,
          size: 30,
          tooltip: s.routeWorkdayStart,
        ),
      ),
    ];
  }
}

class _TrailEndDot extends StatelessWidget {
  final Color color;
  const _TrailEndDot({required this.color});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
      );
}

/// The day's work-day route in figures, and each visit on it — keyed to its
/// numbered pin and coloured stretch on the map, opening the visit's own trail.
class _WorkdaySection extends StatelessWidget {
  final List<WorkdayRoute> routes;
  final List<Visit> visits;
  const _WorkdaySection({required this.routes, required this.visits});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final x = context.x;
    final cs = context.colors;
    final tf = AppDate.timeFormat(context);
    String time(DateTime d) => tf.format(context.toUserTime(d));

    final order = _visitOrder(routes);
    final pointCount = routes.fold<int>(0, (n, r) => n + r.logs.length);
    final km = routes.fold<double>(0, (n, r) => n + r.distanceKm);
    final started = routes.first.session.startedAt;
    final last = routes.last;
    final ended = last.session.isActive ? null : last.session.endedAt;
    final refs = {for (final r in routes) ...r.visitRefs};

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.routeWorkdayTitle,
              style: AppType.titleSm.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
          context.gapH(Insets.x1),
          Text(
            s.routeWorkdaySpan(time(started), ended == null ? s.routeWorkdayNow : time(ended)),
            style: TextStyle(fontSize: FontSz.sm, fontWeight: FontWeight.w600, color: x.textTertiary),
          ),
          context.gapH(Insets.x3),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: s.routeWorkdayPoints,
                  value: '$pointCount',
                  icon: Symbols.pin_drop,
                ),
              ),
              context.gapW(Insets.x3),
              Expanded(
                child: _SummaryTile(
                  label: s.routeTotalDistance,
                  value: s.unitKm(km.toStringAsFixed(2)),
                  icon: Symbols.route,
                ),
              ),
            ],
          ),
          context.gapH(Insets.x3),
          Row(
            children: [
              Container(
                width: 22,
                height: 5,
                decoration: BoxDecoration(
                  color: _movementColor,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
              context.gapW(Insets.x2),
              Expanded(
                child: Text(s.routeWorkdayMovement,
                    style: TextStyle(fontSize: FontSz.sm, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              ),
            ],
          ),
          context.gapH(Insets.x2),
          for (var i = 0; i < order.length; i++)
            _WorkdayVisitRow(
              index: i,
              visitId: order[i],
              visit: _find(order[i]),
              reference: refs[order[i]],
              logs: [
                for (final r in routes)
                  for (final l in r.logs)
                    if (l.visitId == order[i]) l,
              ],
            ),
        ],
      ),
    );
  }

  Visit? _find(int id) {
    for (final v in visits) {
      if (v.id == id) return v;
    }
    return null;
  }
}

class _WorkdayVisitRow extends StatelessWidget {
  final int index;
  final int visitId;
  final Visit? visit;
  final String? reference;
  final List<VisitLocationLog> logs;
  const _WorkdayVisitRow({
    required this.index,
    required this.visitId,
    required this.visit,
    required this.reference,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final x = context.x;
    final cs = context.colors;
    final tf = AppDate.timeFormat(context);
    String time(DateTime d) => tf.format(context.toUserTime(d));
    var meters = 0.0;
    for (var i = 1; i < logs.length; i++) {
      meters += haversineMeters(logs[i - 1].latitude, logs[i - 1].longitude,
          logs[i].latitude, logs[i].longitude);
    }
    final ref = visit?.name ?? reference ?? '#$visitId';
    final title = visit?.customerName ?? ref;

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: () => context.push(AppRoutes.visitTrail(visitId), extra: visit),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            MapPin.label(
              text: '${index + 1}',
              size: 28,
              borderWidth: 2,
              color: _trailColor(index),
            ),
            context.gapW(Insets.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.titleSm.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                  context.gapH(Insets.x1),
                  Text(
                    logs.isEmpty
                        ? ref
                        : '$ref · ${s.routeWorkdaySpan(time(logs.first.loggedAt), time(logs.last.loggedAt))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: FontSz.sm, fontWeight: FontWeight.w600, color: x.textTertiary),
                  ),
                ],
              ),
            ),
            context.gapW(Insets.x2),
            Flexible(
              child: Text(
                s.routeTrailSummary(logs.length, (meters / 1000).toStringAsFixed(2)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: FontSz.sm, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
              ),
            ),
            Icon(Symbols.chevron_right, color: x.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Fallback when there is no work day for today: the day's recorded visit
/// routes, one row per visit in the order they were done, each keyed to its
/// line on the map by colour and opening that visit's own full trail.
class _RecordedTrails extends StatelessWidget {
  final List<DayTrail> trails;
  final int failed;
  const _RecordedTrails({required this.trails, required this.failed});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final x = context.x;
    final cs = context.colors;
    final tf = AppDate.timeFormat(context);
    String time(DateTime? d) => d == null ? '—' : tf.format(context.toUserTime(d));

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.routeRecordedTrails,
              style: AppType.titleSm.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
          context.gapH(Insets.x2),
          for (var i = 0; i < trails.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () => context.push(
                AppRoutes.visitTrail(trails[i].visit.id),
                extra: trails[i].visit,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _trailColor(i),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                    context.gapW(Insets.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trails[i].visit.customerName ?? trails[i].visit.name ?? '#${trails[i].visit.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.titleSm.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                          ),
                          context.gapH(Insets.x1),
                          Text(
                            '${trails[i].visit.name ?? ''} · '
                            '${time(trails[i].visit.startDatetime)} – ${time(trails[i].visit.endDatetime)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: FontSz.sm, fontWeight: FontWeight.w600, color: x.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    context.gapW(Insets.x2),
                    Flexible(
                      child: Text(
                        s.routeTrailSummary(
                          trails[i].track.locationLogCount,
                          trails[i].track.trackedDistanceKm.toStringAsFixed(2),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: FontSz.sm, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                      ),
                    ),
                    Icon(Symbols.chevron_right, color: x.textTertiary),
                  ],
                ),
              ),
            ),
          if (failed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.routeTrailsPartial,
                  style: TextStyle(fontSize: FontSz.sm, color: cs.error)),
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
      decoration: AppDecor.panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: x.textTertiary),
            const Spacer(),
          ]),
          context.gapH(Insets.x2),
          Text(value, style: AppType.number(20, cs.onSurface)),
          context.gapH(Insets.hair),
          Text(label, style: TextStyle(fontSize: FontSz.sm, fontWeight: FontWeight.w500, color: x.textTertiary)),
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
                          fontSize: FontSz.base,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: x.divider, margin: const EdgeInsets.symmetric(vertical: 4))),
            ],
          ),
          context.gapW(Insets.x3),
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
                              style: TextStyle(fontSize: FontSz.xs, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
                        ),
                    ],
                  ),
                  context.gapH(Insets.x1),
                  // Flexible + ellipsis on both labels: "09:30 · Start point"
                  // plus "25 min drive" already exceeds a 320dp row at the
                  // 1.25 text-scale cap, and Arabic runs longer still.
                  Row(
                    children: [
                      Icon(Symbols.schedule, size: 14, color: x.textTertiary),
                      context.gapW(Insets.x1),
                      Flexible(
                        child: Text(
                          index == 0 ? '$eta · ${context.s.routeStartPoint}' : eta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: FontSz.sm, fontWeight: FontWeight.w600, color: x.textTertiary),
                        ),
                      ),
                      if (driveMinutes != null) ...[
                        context.gapW(Insets.x2h),
                        Icon(Symbols.directions_car, size: 14, color: x.textTertiary),
                        context.gapW(Insets.x1),
                        Flexible(
                          child: Text(
                            context.s.routeDriveMinutes(driveMinutes!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: FontSz.sm, fontWeight: FontWeight.w600, color: x.textTertiary),
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
