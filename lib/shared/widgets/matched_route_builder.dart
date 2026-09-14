import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/di/service_locator.dart';
import '../../core/map_matching/route_geometry.dart';
import '../../core/map_matching/route_matcher.dart';

/// Builds its child with road-following geometry for each of [traces].
///
/// The first build uses whatever is already matched in memory (the rest drawn
/// raw), then rebuilds as the remaining stretches are matched. Matching runs
/// again only when a trace's fixes change — never on a rebuild, pan or zoom —
/// and the matcher's cache means a stretch matched once is not requested again.
///
/// Without a registered [RouteMatcher] (road matching disabled, a widget test)
/// every trace is built raw.
class MatchedRouteBuilder extends StatefulWidget {
  final List<List<TracePoint>> traces;
  final Widget Function(BuildContext context, List<RouteGeometry> geometries)
      builder;

  /// Defaults to the app's registered matcher.
  final RouteMatcher? matcher;

  const MatchedRouteBuilder({
    super.key,
    required this.traces,
    required this.builder,
    this.matcher,
  });

  @override
  State<MatchedRouteBuilder> createState() => _MatchedRouteBuilderState();
}

class _MatchedRouteBuilderState extends State<MatchedRouteBuilder> {
  List<RouteGeometry> _geometries = const [];
  final List<StreamSubscription<RouteGeometry>> _subscriptions = [];
  int? _signature;

  RouteMatcher? get _matcher => widget.matcher ?? slMaybe<RouteMatcher>();

  @override
  void initState() {
    super.initState();
    _match();
  }

  @override
  void didUpdateWidget(MatchedRouteBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sign(widget.traces) != _signature) _match();
  }

  void _match() {
    _cancel();
    final traces = widget.traces;
    _signature = _sign(traces);
    final matcher = _matcher;
    final geometries = [
      for (final t in traces) matcher?.peek(t) ?? RouteGeometry.raw(t),
    ];
    _geometries = geometries;
    if (matcher == null) return;
    for (var i = 0; i < traces.length; i++) {
      if (!geometries[i].pending) continue;
      _subscriptions.add(matcher.resolve(traces[i]).listen((g) {
        if (!mounted || !identical(_geometries, geometries)) return;
        setState(() => geometries[i] = g);
      }));
    }
  }

  void _cancel() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
  }

  static int _sign(List<List<TracePoint>> traces) => Object.hashAll([
        for (final t in traces)
          Object.hashAll([
            t.length,
            for (final p in t) ...[
              p.latitude,
              p.longitude,
              p.time.millisecondsSinceEpoch,
            ],
          ]),
      ]);

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _geometries);
}
