import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_colors.dart';
import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/map_matching/route_geometry.dart';
import '../../../core/map_matching/route_matcher.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/app_number.dart';
import '../../../core/utils/communications.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/utils/user_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../bloc/visit_trail_cubit.dart';
import '../data/models/visit.dart';
import '../data/models/visit_location_log.dart';
import '../data/visit_trail_tracker.dart';
import '../data/visits_repository.dart';
import 'visit_trail_layers.dart';
import 'visit_trail_section.dart';

/// The whole route of one visit, full screen: the thread drawn across the map
/// with every logged position under it in a sheet.
///
/// Opened from the visit detail page. It builds its **own** [VisitTrailCubit]
/// rather than reusing the caller's, so the page keeps working when reached by
/// a deep link (a push notification, say) with no detail page beneath it.
class VisitTrailPage extends StatelessWidget {
  final Visit visit;
  const VisitTrailPage({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VisitTrailCubit(
        repository: sl<VisitsRepository>(),
        tracker: slMaybe<VisitTrailTracker>(),
        visitId: visit.id,
        live: visit.isTrackingLive,
      )..load(),
      child: _VisitTrailView(visit: visit),
    );
  }
}

class _VisitTrailView extends StatefulWidget {
  final Visit visit;
  const _VisitTrailView({required this.visit});

  @override
  State<_VisitTrailView> createState() => _VisitTrailViewState();
}

class _VisitTrailViewState extends State<_VisitTrailView> {
  /// Drives the "fit route" button. The first framing needs no call: the map
  /// is only built once there are points, and it opens fitted to them. Later
  /// polls (every 30s on a running visit) leave the camera where the user put
  /// it.
  final MapController _map = MapController();

  RouteLineMode _lineMode = RouteLineMode.roads;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  CameraFit? _fitFor(List<LatLng> points) => AppMap.fitOrNull(
    points,
    padding: context.padAll(Insets.x16),
    maxZoom: AppConstants.mapZoomVisitFitMax,
  );

  void _fit(List<LatLng> points) {
    if (!mounted || points.isEmpty) return;
    final fit = _fitFor(points);
    if (fit == null) {
      _map.move(points.first, AppConstants.mapZoomVisitDetail);
    } else {
      _map.fitCamera(fit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final visit = widget.visit;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.trailSectionTitle),
        actions: [
          BlocBuilder<VisitTrailCubit, VisitTrailState>(
            buildWhen: (p, c) => p.pendingUploads != c.pendingUploads,
            builder: (context, state) {
              if (state.pendingUploads == 0) return const SizedBox.shrink();
              return IconButton(
                icon: Badge(
                  label: Text(AppNumber.whole(state.pendingUploads)),
                  child: const Icon(Symbols.cloud_upload),
                ),
                tooltip: s.trailPendingUploads(state.pendingUploads),
                onPressed: () => uploadPendingTrail(context),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<VisitTrailCubit, VisitTrailState>(
        builder: (context, state) {
          if (state.status == VisitTrailStatus.loading && state.track.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == VisitTrailStatus.error && state.track.isEmpty) {
            return ErrorView(
              message: state.error?.localize(context) ?? s.errUnknown,
              onRetry: () => context.read<VisitTrailCubit>().load(),
            );
          }
          if (state.track.isEmpty) {
            return EmptyView(
              icon: Symbols.route,
              message: visit.isTrackingLive
                  ? s.trailEmptyRunning
                  : s.trailEmptyFinished,
            );
          }
          final map = _TrailMap(
            map: _map,
            track: state.track,
            live: visit.isTrackingLive,
            initialFit: _fitFor(TrailLayers.points(state.track)),
            onFit: () => _fit(TrailLayers.points(state.track)),
            lineMode: _lineMode,
            onLineMode: (m) => setState(() => _lineMode = m),
          );
          final stats = _TrailStats(track: state.track);
          // Side by side where the screen is wide: stacked, a landscape phone
          // left the stats and the list a sliver too short to use.
          if (context.isLandscape) {
            return SafeArea(
              top: false,
              bottom: false,
              child: Row(
                children: [
                  Expanded(flex: _mapFlex, child: map),
                  Expanded(flex: _listFlex, child: stats),
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(flex: _mapFlex, child: map),
              Expanded(flex: _listFlex, child: stats),
            ],
          );
        },
      ),
    );
  }

  /// The map's and the stats panel's shares of the screen.
  static const int _mapFlex = 3;
  static const int _listFlex = 2;
}

class _TrailMap extends StatelessWidget {
  final MapController map;
  final VisitTrack track;
  final bool live;
  final CameraFit? initialFit;
  final VoidCallback onFit;
  final RouteLineMode lineMode;
  final ValueChanged<RouteLineMode> onLineMode;

  const _TrailMap({
    required this.map,
    required this.track,
    required this.live,
    required this.initialFit,
    required this.onFit,
    required this.lineMode,
    required this.onLineMode,
  });

  /// Tiles kept loaded beyond the viewport while the user pans the route.
  static const int _tilePanBuffer = 2;

  @override
  Widget build(BuildContext context) {
    // Matched once per change of the trail's points, not per rebuild.
    return MatchedRouteBuilder(
      traces: [track.logs.trace],
      builder: (context, geometries) => _build(context, geometries.first),
    );
  }

  Widget _build(BuildContext context, RouteGeometry geometry) {
    final points = TrailLayers.points(track);
    final matching = RouteLineToggle.stateOf([geometry]);
    final inset = context.r(Insets.x3);

    return AppMap(
      controller: map,
      initialCenter: points.first,
      initialZoom: AppConstants.mapZoomVisitDetail,
      initialCameraFit: initialFit,
      panBuffer: _tilePanBuffer,
      // Start-side: the fit button owns the end-side corner.
      attributionAlignment: context.isRtl
          ? Alignment.bottomRight
          : Alignment.bottomLeft,
      layers: [
        TrailLayers.polyline(
          context,
          track,
          width: TrailLayers.strokeWidthFull,
          path: lineMode == RouteLineMode.roads ? geometry.path() : null,
        ),
        // The recorded fixes themselves, in both modes: where the device
        // actually reported the employee.
        TrailLayers.vertexDots(context, track),
        TrailLayers.endpoints(context, track, live: live),
      ],
      overlays: [
        PositionedDirectional(
          end: inset,
          bottom: inset,
          child: MapFab.rounded(
            icon: Symbols.fit_screen,
            onTap: onFit,
            semanticLabel: context.s.trailFitRoute,
          ),
        ),
        if ((slMaybe<RouteMatcher>()?.enabled ?? false) && points.length > 1)
          PositionedDirectional(
            top: inset,
            end: inset,
            child: RouteLineToggle(
              mode: lineMode,
              onChanged: onLineMode,
              pending: matching.pending,
              unmatched: matching.unmatched,
            ),
          ),
      ],
    );
  }
}

/// Distance / speed / duration summary above the list of individual fixes.
class _TrailStats extends StatelessWidget {
  final VisitTrack track;
  const _TrailStats({required this.track});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final span = track.span;
    final speed = track.averageSpeedKmh;
    final stats = [
      _Stat(
        icon: Symbols.straighten,
        label: s.trailDistance,
        value: AppNumber.km(s, track.trackedDistanceKm, precise: true),
      ),
      _Stat(
        icon: Symbols.timeline,
        label: s.trailPointsList,
        value: AppNumber.whole(track.locationLogCount),
      ),
      if (span != null)
        _Stat(
          icon: Symbols.timer,
          label: s.wfDurationLabel,
          value: span.localized(context),
        ),
      if (speed != null)
        _Stat(
          icon: Symbols.speed,
          label: s.trailAvgSpeed,
          value: AppNumber.speedKmh(s, speed),
        ),
    ];

    // The stats scroll away with the list rather than sitting above it: on a
    // short screen at a large font a fixed header left the list no room.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(
            context.r(Insets.x3h),
            context.r(Insets.x3),
            context.r(Insets.x3h),
            context.r(Insets.x2),
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final stat in stats) Expanded(child: stat)],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _divider(context)),
        _PointList(track: track),
      ],
    );
  }
}

Divider _divider(BuildContext context, {double indent = 0}) => Divider(
  height: 1,
  indent: indent,
  color: context.colors.outlineVariant.withValues(alpha: Alphas.subdued),
);

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Column(
      children: [
        Icon(icon, size: context.r(IconSz.label), color: cs.primary),
        context.gapH(Insets.x1),
        Text(
          value,
          style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Every logged fix, newest first — the audit view of the same data the map
/// draws. Reversed because the interesting end of a running visit is the newest
/// position, and scrolling a long trail from the bottom to find it is a chore.
class _PointList extends StatelessWidget {
  final VisitTrack track;
  const _PointList({required this.track});

  String _sourceLabel(BuildContext context, VisitLocationLog log) {
    final s = context.s;
    switch (log.source) {
      case TrailSource.start:
        return s.trailPointStart;
      case TrailSource.end:
        return s.trailPointEnd;
      case TrailSource.manual:
        return s.trailPointManual;
      case TrailSource.track:
      case TrailSource.unknown:
        return s.trailPointTrack;
    }
  }

  Color _sourceColor(BuildContext context, VisitLocationLog log) =>
      switch (log.source) {
        TrailSource.start => AppColors.routeStart,
        TrailSource.end => AppColors.routeEnd,
        _ => context.colors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tf = AppDate.timeWithSecondsFormat(context);
    final logs = track.logs.reversed.toList();
    // Lines up the separators with the text, past the leading glyph.
    final indent = context.r(Insets.x16) - context.r(Insets.x2);

    return SliverList.separated(
      itemCount: logs.length,
      separatorBuilder: (_, __) => _divider(context, indent: indent),
      itemBuilder: (context, i) {
        final log = logs[i];
        final accuracy = log.accuracy;
        final speed = log.speedKmh;
        final endpoint = log.isStart || log.isEnd;
        return ListTile(
          dense: true,
          leading: Icon(
            log.isStart
                ? Symbols.trip_origin
                : (log.isEnd ? Symbols.flag : Symbols.circle),
            color: _sourceColor(context, log),
            size: context.r(endpoint ? IconSz.tile : IconSz.xs),
          ),
          title: Text(
            tf.format(context.toUserTime(log.loggedAt)),
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            context.joinFacts([
              _sourceLabel(context, log),
              log.location,
              if (accuracy != null && accuracy > 0)
                s.trailAccuracy(AppNumber.whole(accuracy)),
              if (speed != null && speed > 0) AppNumber.speedKmh(s, speed),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(Symbols.open_in_new, size: context.r(IconSz.label)),
            tooltip: s.wfOpenInMaps,
            onPressed: () => context.openExternal(
              () => Communications.openInMaps(log.latitude, log.longitude),
            ),
          ),
        );
      },
    );
  }
}
