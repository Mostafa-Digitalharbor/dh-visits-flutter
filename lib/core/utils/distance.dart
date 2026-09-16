import 'dart:math' as math;

const double _earthRadiusMeters = 6371000.0;

/// Haversine distance in meters between two coordinates.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusMeters * c;
}

/// Total length in meters of a path through [points] (`(lat, lng)` pairs), in
/// order. Four screens summed their own polylines with slightly different
/// loops; they all measure through here.
double pathLengthMeters(Iterable<(double lat, double lng)> points) {
  var total = 0.0;
  (double, double)? previous;
  for (final p in points) {
    if (previous != null) {
      total += haversineMeters(previous.$1, previous.$2, p.$1, p.$2);
    }
    previous = p;
  }
  return total;
}

double _toRad(double deg) => deg * math.pi / 180.0;
