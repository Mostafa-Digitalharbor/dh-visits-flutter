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
  final MapController _map = MapController();

  /// Set once the map has framed a trail, so later polls (which arrive every
  /// 30s on a running visit) don't yank the camera back while the user is
  /// reading some other part of the route.
  bool _fitted = false;

  RouteLineMode _lineMode = RouteLineMode.roads;

  void _fit(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.first, AppConstants.mapZoomVisitDetail);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(56),
        maxZoom: AppConstants.mapZoomVisitFitMax,
      ),
    );
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
                  label: Text('${state.pendingUploads}'),
                  child: const Icon(Symbols.cloud_upload),
                ),
                tooltip: s.trailPendingUploads(state.pendingUploads),
                onPressed: () =>
                    context.read<VisitTrailCubit>().flushAndReload(),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<VisitTrailCubit, VisitTrailState>(
        listenWhen: (p, c) => p.track.logs.length != c.track.logs.length,
        listener: (context, state) {
          // Frame the route the first time points arrive, and only then.
          if (!_fitted && state.track.logs.isNotEmpty) {
            _fitted = true;
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _fit(TrailLayers.points(state.track)));
          }
        },
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
          return Column(
            children: [
              Expanded(
                flex: 3,
                child: _TrailMap(
                  map: _map,
                  track: state.track,
                  live: visit.isTrackingLive,
                  onFit: () => _fit(TrailLayers.points(state.track)),
                  lineMode: _lineMode,
                  onLineMode: (m) => setState(() => _lineMode = m),
                ),
              ),
              Expanded(
                flex: 2,
                child: _TrailStats(track: state.track, visit: visit),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrailMap extends StatelessWidget {
  final MapController map;
  final VisitTrack track;
  final bool live;
  final VoidCallback onFit;
  final RouteLineMode lineMode;
  final ValueChanged<RouteLineMode> onLineMode;

  const _TrailMap({
    required this.map,
    required this.track,
    required this.live,
    required this.onFit,
    required this.lineMode,
    required this.onLineMode,
  });

  @override
  Widget build(BuildContext context) {
    // Matched once per change of the trail's points, not per rebuild.
    return MatchedRouteBuilder(
      traces: [track.logs.trace],
      builder: (context, geometries) => _build(context, geometries.first),
    );
  }

  Widget _build(BuildContext context, RouteGeometry geometry) {
    final isDark = context.isDark;
    final points = TrailLayers.points(track);
    final matching = RouteLineToggle.stateOf([geometry]);

    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: AppColors.mapBackground(isDark)),
        ),
        FlutterMap(
          mapController: map,
          options: MapOptions(
            initialCenter: points.first,
            initialZoom: AppConstants.mapZoomVisitDetail,
            minZoom: AppConstants.mapMinZoom,
            maxZoom: AppConstants.mapMaxZoom,
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(56),
                    maxZoom: AppConstants.mapZoomVisitFitMax,
                  )
                : null,
          ),
          children: [
            const AppMapTileLayer(
                maxZoom: AppConstants.mapMaxZoom, panBuffer: 2),
            TrailLayers.polyline(
              context,
              track,
              strokeWidth: 5,
              path: lineMode == RouteLineMode.roads ? geometry.path() : null,
            ),
            // The recorded fixes themselves, in both modes: where the device
            // actually reported the employee.
            TrailLayers.vertexDots(context, track),
            TrailLayers.endpoints(context, track, live: live),
            const AppMapAttribution(alignment: Alignment.bottomLeft),
          ],
        ),
        if (isDark)
          IgnorePointer(
            child: Container(color: Colors.black.withValues(alpha: 0.22)),
          ),
        Positioned(
          right: 12,
          bottom: 12,
          child: MapFab.rounded(
            icon: Symbols.fit_screen,
            onTap: onFit,
            semanticLabel: context.s.trailFitRoute,
          ),
        ),
        if ((slMaybe<RouteMatcher>()?.enabled ?? false) && points.length > 1)
          Positioned(
            top: 12,
            right: 12,
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
  final Visit visit;
  const _TrailStats({required this.track, required this.visit});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cs = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.x3h, Insets.x3, Insets.x3h, Insets.x2),
          child: Row(
            children: [
              _Stat(
                icon: Symbols.straighten,
                label: s.trailDistance,
                value: s.trailDistanceKm(
                    track.trackedDistanceKm.toStringAsFixed(2)),
              ),
              _Stat(
                icon: Symbols.timeline,
                label: s.trailMapTitle,
                value: '${track.locationLogCount}',
              ),
              if (track.span != null)
                _Stat(
                  icon: Symbols.timer,
                  label: s.wfDurationLabel,
                  value: track.span!.localized(context),
                ),
              if (track.averageSpeedKmh != null)
                _Stat(
                  icon: Symbols.speed,
                  label: s.trailAvgSpeed,
                  value: s.trailSpeedKmh(
                      track.averageSpeedKmh!.toStringAsFixed(0)),
                ),
            ],
          ),
        ),
        Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: Alphas.subdued)),
        Expanded(
          child: _PointList(track: track),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          context.gapH(Insets.x1),
          Text(
            value,
            style: context.text.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: context.text.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

  Color _sourceColor(BuildContext context, VisitLocationLog log) {
    switch (log.source) {
      case TrailSource.start:
        return Colors.green.shade600;
      case TrailSource.end:
        return Colors.deepOrangeAccent.shade200;
      default:
        return context.colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tf = AppDate.timeWithSecondsFormat(context);
    final logs = track.logs.reversed.toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: Insets.x1),
      itemCount: logs.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 56,
        color: context.colors.outlineVariant
            .withValues(alpha: Alphas.subdued),
      ),
      itemBuilder: (context, i) {
        final log = logs[i];
        final tone = _sourceColor(context, log);
        final details = <String>[
          if (log.accuracy != null && log.accuracy! > 0)
            s.trailAccuracy(log.accuracy!.toStringAsFixed(0)),
          if (log.speedKmh != null && log.speedKmh! > 0)
            s.trailSpeedKmh(log.speedKmh!.toStringAsFixed(0)),
        ];
        return ListTile(
          dense: true,
          leading: Icon(
            log.isStart
                ? Symbols.trip_origin
                : (log.isEnd ? Symbols.flag : Symbols.circle),
            color: tone,
            size: log.isStart || log.isEnd ? 22 : 12,
          ),
          title: Text(
            tf.format(context.toUserTime(log.loggedAt)),
            style: context.text.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              _sourceLabel(context, log),
              if (log.location != null) log.location!,
              ...details,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Symbols.open_in_new, size: 18),
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
