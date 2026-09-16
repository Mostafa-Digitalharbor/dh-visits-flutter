// odoo_parse.dart — tolerant readers for values Odoo sends over JSON-RPC.
//
// Odoo serialises "empty" as `false` for every field type, a many2one as
// `[id, "Name"]`, an unset float as `0.0`, and a datetime as naive UTC text.
// Each model used to carry its own copy of these readers, and the copies had
// drifted: some cast with `as num` (a TypeError on `false`, which escaped every
// `on ApiException` handler), some did not. Every model parses through here.
import '../utils/app_log.dart';

/// An integer, or null for `false` / null / anything non-numeric.
int? odooInt(dynamic raw) => raw is num ? raw.toInt() : null;

/// A double, or null for `false` / null / anything non-numeric.
double? odooDouble(dynamic raw) => raw is num ? raw.toDouble() : null;

/// Trimmed text, or null for `false` / null / blank.
String? odooString(dynamic raw) {
  if (raw == null || raw == false) return null;
  final text = raw.toString().trim();
  return text.isEmpty || text == 'false' ? null : text;
}

/// `true` only for a real boolean `true`.
bool odooBool(dynamic raw) => raw == true;

/// A latitude/longitude value. Odoo stores an unset float as `0.0`, so zero
/// reads as "absent" — no customer sits on null island.
double? odooCoord(dynamic raw) {
  final value = odooDouble(raw);
  return value == null || value == 0.0 ? null : value;
}

/// Whether a coordinate pair is on the globe.
bool isValidLatLng(double lat, double lng) =>
    lat.abs() <= 90 && lng.abs() <= 180;

/// A many2one: `[id, "Name"]`, a bare id, or `false`.
({int? id, String? name}) odooMany2one(dynamic raw) {
  if (raw is List && raw.isNotEmpty) {
    return (
      id: odooInt(raw.first),
      name: raw.length > 1 ? odooString(raw[1]) : null,
    );
  }
  return (id: odooInt(raw), name: null);
}

/// A list, or empty for `false` / null / a non-list.
List<dynamic> odooList(dynamic raw) => raw is List ? raw : const [];

/// A string-keyed map, or null.
Map<String, dynamic>? odooMap(dynamic raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : null;

/// An Odoo datetime as **UTC**. Odoo serialises datetimes as naive UTC
/// (`"2026-07-01 09:00:00"`); the REST routes return ISO without a zone
/// (`"2026-07-01T09:00:00"`). An explicit `Z`/offset is respected.
DateTime? parseOdooUtc(dynamic raw) {
  final text = odooString(raw);
  if (text == null) return null;
  final hasZone = text.endsWith('Z') ||
      text.contains('+') ||
      (text.lastIndexOf('-') > 10);
  final iso = hasZone ? text : '${text.replaceFirst(' ', 'T')}Z';
  return DateTime.tryParse(iso)?.toUtc();
}

/// Parses every map in [rows] with [parse], skipping — and logging — the rows
/// it rejects or throws on.
///
/// One malformed record used to fail a whole screen: a list parse was a single
/// `.map(...).toList()`, so a stray `false` in row 37 cost the user rows 1–36
/// as well. A row that can't be read is now dropped on its own.
List<T> parseRows<T>(
  dynamic rows,
  T? Function(Map<String, dynamic> row) parse, {
  required String label,
}) {
  final out = <T>[];
  for (final raw in odooList(rows)) {
    final row = odooMap(raw);
    if (row == null) continue;
    try {
      final parsed = parse(row);
      if (parsed != null) out.add(parsed);
    } catch (e) {
      appLog('[$label] skipped unreadable row ${row['id']}: $e');
    }
  }
  return out;
}
