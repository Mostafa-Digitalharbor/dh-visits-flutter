import 'dart:async';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../utils/app_log.dart';
import 'osrm_map_matcher.dart';
import 'route_geometry.dart';
import 'route_match_cache.dart';

/// Derives road-following display geometry for recorded GPS traces.
///
/// **Raw GPS stays the truth.** This only ever produces a line to draw; the
/// recorded fixes it is given are never changed, stored differently or sent
/// back to the server. Wherever matching is unavailable or not believable the
/// line simply joins the recorded fixes, so a map is never left empty.
///
/// **Cost.** A trace is cut into fixed chunks of [MapMatcher.maxPoints] fixes
/// sharing their boundary fix. Each chunk is matched once and cached under a
/// key computed from its fixes ([RouteMatchCache]); a growing work day
/// therefore only ever re-sends its last, still-growing chunk. Requests are
/// serialised and spaced ([requestSpacing]), identical concurrent requests
/// are shared, and after a transient failure (offline, rate limited) the
/// service is left alone for [failureBackoff].
class RouteMatcher {
  /// Null disables road matching: every trace is drawn raw.
  final MapMatcher? matcher;
  final RouteMatchCache cache;
  final Duration requestSpacing;
  final Duration failureBackoff;
  final DateTime Function() _now;

  RouteMatcher({
    required this.matcher,
    RouteMatchCache? cache,
    this.requestSpacing = const Duration(milliseconds: 1100),
    this.failureBackoff = const Duration(minutes: 1),
    DateTime Function()? now,
  })  : cache = cache ?? RouteMatchCache(),
        _now = now ?? DateTime.now;

  /// Bumped whenever the way a response is turned into geometry changes, so
  /// geometry cached under the old rules is not reused.
  static const int _algorithm = 2;

  final Map<String, Future<List<List<LatLng>?>?>> _inFlight = {};
  Future<void> _lane = Future<void>.value();
  DateTime? _lastRequestAt;
  DateTime? _blockedUntil;

  /// Requests sent to the matching service (diagnostics and tests).
  int requestCount = 0;

  bool get enabled => matcher != null;

  /// What can be drawn right now from memory, without waiting: cached chunks
  /// follow roads, the rest is raw and [RouteGeometry.pending].
  RouteGeometry peek(List<TracePoint> trace) {
    final m = matcher;
    if (m == null || trace.length < 2) return RouteGeometry.raw(trace);
    final roads = List<List<LatLng>?>.filled(trace.length - 1, null);
    var missing = false;
    for (final c in _chunks(trace.length, m.maxPoints)) {
      final hit = cache.peek(_key(m, trace, c));
      if (hit == null || hit.length != c.edges) {
        missing = true;
      } else {
        _apply(roads, c, hit);
      }
    }
    return RouteGeometry.fromRoads(_fixes(trace), roads, pending: missing);
  }

  /// The trace's geometry, emitted first from memory and then again each time
  /// another chunk is resolved; the last event has `pending == false`.
  Stream<RouteGeometry> resolve(List<TracePoint> trace) async* {
    final m = matcher;
    if (m == null || trace.length < 2) {
      yield RouteGeometry.raw(trace);
      return;
    }
    final fixes = _fixes(trace);
    final roads = List<List<LatLng>?>.filled(trace.length - 1, null);
    final todo = <_Chunk>[];
    for (final c in _chunks(trace.length, m.maxPoints)) {
      final hit = cache.peek(_key(m, trace, c));
      if (hit == null || hit.length != c.edges) {
        todo.add(c);
      } else {
        _apply(roads, c, hit);
      }
    }
    yield RouteGeometry.fromRoads(fixes, roads, pending: todo.isNotEmpty);
    for (var i = 0; i < todo.length; i++) {
      final edges = await _resolveChunk(m, trace, todo[i]);
      final last = i == todo.length - 1;
      if (edges != null) _apply(roads, todo[i], edges);
      if (edges != null || last) {
        yield RouteGeometry.fromRoads(fixes, roads, pending: !last);
      }
    }
  }

  /// Forgets every matched geometry (logout).
  Future<void> clear() => cache.clear();

  Future<List<List<LatLng>?>?> _resolveChunk(
    MapMatcher m,
    List<TracePoint> trace,
    _Chunk chunk,
  ) {
    final key = _key(m, trace, chunk);
    final running = _inFlight[key];
    if (running != null) return running;
    final future = () async {
      try {
        final stored = await cache.read(key);
        if (stored != null && stored.length == chunk.edges) return stored;
        final blocked = _blockedUntil;
        if (blocked != null && _now().isBefore(blocked)) return null;
        final points = trace.sublist(chunk.start, chunk.end + 1);
        final edges = await _throttled(() => m.match(points));
        if (edges.length != chunk.edges) return null;
        await cache.write(key, edges);
        return edges;
      } on MapMatchingException catch (e) {
        if (e.retryable) _blockedUntil = _now().add(failureBackoff);
        appLog('[RouteMatcher] road matching unavailable, drawing raw GPS: $e');
        return null;
      } catch (e) {
        appLog('[RouteMatcher] road matching failed, drawing raw GPS: $e');
        return null;
      } finally {
        _inFlight.remove(key);
      }
    }();
    _inFlight[key] = future;
    return future;
  }

  /// Runs [body] after every earlier request, at least [requestSpacing] after
  /// the previous one finished (public OSRM allows about one per second).
  Future<T> _throttled<T>(Future<T> Function() body) {
    final previous = _lane;
    final done = Completer<void>();
    _lane = done.future;
    return () async {
      await previous;
      try {
        final last = _lastRequestAt;
        if (last != null) {
          final wait = last.add(requestSpacing).difference(_now());
          if (wait > Duration.zero) await Future<void>.delayed(wait);
        }
        requestCount++;
        return await body();
      } finally {
        _lastRequestAt = _now();
        done.complete();
      }
    }();
  }

  static List<LatLng> _fixes(List<TracePoint> trace) =>
      [for (final p in trace) p.latLng];

  /// Consecutive chunks of at most [size] fixes, each starting on the fix the
  /// previous one ended with, so every edge belongs to exactly one chunk.
  static List<_Chunk> _chunks(int n, int size) {
    final step = math.max(1, size - 1);
    final out = <_Chunk>[];
    for (var start = 0; start < n - 1; start += step) {
      out.add(_Chunk(start, math.min(start + step, n - 1)));
    }
    return out;
  }

  static void _apply(
      List<List<LatLng>?> roads, _Chunk chunk, List<List<LatLng>?> edges) {
    for (var j = 0; j < edges.length; j++) {
      roads[chunk.start + j] = edges[j];
    }
  }

  /// Everything the service's answer depends on: the fixes (position,
  /// spacing, accuracy, heading, speed), the service, and [_algorithm].
  static String _key(MapMatcher m, List<TracePoint> trace, _Chunk chunk) {
    final b = StringBuffer('${m.cacheId}|a$_algorithm');
    final t0 = trace[chunk.start].time.millisecondsSinceEpoch;
    for (var i = chunk.start; i <= chunk.end; i++) {
      final p = trace[i];
      b
        ..write('|')
        ..write(p.latitude.toStringAsFixed(6))
        ..write(',')
        ..write(p.longitude.toStringAsFixed(6))
        ..write(',')
        ..write((p.time.millisecondsSinceEpoch - t0) ~/ 1000)
        ..write(',')
        ..write(p.accuracy?.round() ?? '')
        ..write(',')
        ..write(p.heading?.round() ?? '')
        ..write(',')
        ..write(p.speed?.toStringAsFixed(1) ?? '');
    }
    return _hash(b.toString());
  }

  /// Two independent 32-bit FNV-1a style hashes plus the length: a file-name
  /// safe digest with negligible collision odds for this use.
  static String _hash(String s) {
    var h1 = 0x811c9dc5;
    var h2 = 0x050c5d1f;
    for (final u in s.codeUnits) {
      h1 = ((h1 ^ u) * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 ^ u) * 0x0100019d + 0x9e3779b9) & 0xFFFFFFFF;
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}'
        '${h2.toRadixString(16).padLeft(8, '0')}'
        '${s.length.toRadixString(16)}';
  }
}

class _Chunk {
  final int start;
  final int end;
  const _Chunk(this.start, this.end);

  int get edges => end - start;
}
