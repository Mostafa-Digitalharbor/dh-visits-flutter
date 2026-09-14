import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

/// Matched road geometry by trace-chunk key, in memory and on disk.
///
/// A chunk's key is derived from its fixes, so an entry is valid for exactly
/// as long as those fixes are unchanged: a finished stretch of a route is
/// matched once and then read back — across rebuilds, screens and app
/// restarts — while only the stretch still growing is ever sent again.
///
/// The files live in app-private storage and are removed on logout (they
/// describe where the signed-in employee went).
class RouteMatchCache {
  /// Null keeps the cache in memory only (tests).
  final Directory? directory;
  final int maxMemoryEntries;
  final int maxDiskEntries;
  final Duration maxAge;

  RouteMatchCache({
    this.directory,
    this.maxMemoryEntries = 300,
    this.maxDiskEntries = 1500,
    this.maxAge = const Duration(days: 30),
  });

  static const int _format = 1;

  final LinkedHashMap<String, List<List<LatLng>?>> _memory =
      LinkedHashMap<String, List<List<LatLng>?>>();
  Future<void>? _pruning;

  /// Memory only; synchronous, so a rebuilt map paints cached roads at once.
  List<List<LatLng>?>? peek(String key) {
    final hit = _memory.remove(key);
    if (hit != null) _memory[key] = hit; // most recently used last
    return hit;
  }

  Future<List<List<LatLng>?>?> read(String key) async {
    final hit = peek(key);
    if (hit != null) return hit;
    final dir = directory;
    if (dir == null) return null;
    await (_pruning ??= _prune(dir));
    try {
      final file = File('${dir.path}/$key.json');
      if (!await file.exists()) return null;
      final edges = _decode(jsonDecode(await file.readAsString()));
      if (edges != null) _remember(key, edges);
      return edges;
    } catch (_) {
      return null; // unreadable entry: match again
    }
  }

  Future<void> write(String key, List<List<LatLng>?> edges) async {
    _remember(key, edges);
    final dir = directory;
    if (dir == null) return;
    try {
      await dir.create(recursive: true);
      final tmp = File('${dir.path}/$key.json.tmp');
      await tmp.writeAsString(jsonEncode(_encode(edges)), flush: true);
      await tmp.rename('${dir.path}/$key.json');
    } catch (_) {
      // Best effort: the geometry is recomputable.
    }
  }

  Future<void> clear() async {
    _memory.clear();
    final dir = directory;
    if (dir == null) return;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  void _remember(String key, List<List<LatLng>?> edges) {
    _memory.remove(key);
    _memory[key] = edges;
    while (_memory.length > maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<void> _prune(Directory dir) async {
    try {
      if (!await dir.exists()) return;
      final files = <(File, DateTime)>[];
      await for (final e in dir.list()) {
        if (e is File) files.add((e, (await e.stat()).modified));
      }
      final cutoff = DateTime.now().subtract(maxAge);
      files.sort((a, b) => b.$2.compareTo(a.$2)); // newest first
      for (var i = 0; i < files.length; i++) {
        if (i >= maxDiskEntries || files[i].$2.isBefore(cutoff)) {
          await files[i].$1.delete();
        }
      }
    } catch (_) {}
  }

  static Map<String, dynamic> _encode(List<List<LatLng>?> edges) => {
        'v': _format,
        'e': [
          for (final edge in edges)
            edge == null
                ? null
                : [
                    for (final p in edge) ...[
                      double.parse(p.latitude.toStringAsFixed(6)),
                      double.parse(p.longitude.toStringAsFixed(6)),
                    ],
                  ],
        ],
      };

  static List<List<LatLng>?>? _decode(Object? raw) {
    if (raw is! Map || raw['v'] != _format || raw['e'] is! List) return null;
    return [
      for (final edge in raw['e'] as List)
        edge is List
            ? [
                for (var i = 0; i + 1 < edge.length; i += 2)
                  LatLng((edge[i] as num).toDouble(),
                      (edge[i + 1] as num).toDouble()),
              ]
            : null,
    ];
  }
}
