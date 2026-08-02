/// The permanent audit note written to a visit's Odoo chatter when the OS
/// reports that a check-in / check-out coordinate came from a mock-location
/// provider (a fake-GPS app) rather than the GPS sensor.
///
/// Extracted from `VisitsRepository` so the wording — the one artefact of this
/// feature a human ever reads — can be asserted in a unit test rather than only
/// by triggering a spoof against a live server. The repository keeps the
/// posting logic; this file owns nothing but the text.
library;

/// Which end of the visit a verdict belongs to.
enum SpoofPhase { start, end }

/// Machine-readable marker embedded in every mock-location chatter note.
///
/// Detection keys off this token, never off the prose around it: the note is
/// bilingual and will be reworded, but this must keep matching. It doubles as
/// something a manager can paste into Odoo's own message search to pull every
/// suspect visit — which is the closest thing to a filterable flag we have
/// until `dh.visit` gains a real `is_mocked` column.
const String kMockLocationMarker = 'DH-MOCK-GPS';

/// The two bodies of one mock-location note.
///
/// **Why bilingual and not localised.** This is a permanent audit record read
/// by whoever reviews it later, not UI addressed to the person who triggered
/// it. Localising it to the *spoofer's* device language would mean an
/// Arabic-phone rep produces a note their English-reading manager cannot read
/// — so both languages go in, always.
///
/// **Why there are two.** Odoo 17+ trusts only a `markupsafe.Markup` body and
/// HTML-escapes a plain string, which JSON-RPC cannot send — verified live
/// 2026-07-18: an HTML body came back stored as `&lt;p&gt;&lt;strong&gt;…`,
/// i.e. the manager would read raw tags. Writing `mail.message.body` afterwards
/// is not escaped and does produce real markup. So [plain] is posted first and
/// is already complete and readable on its own; [html] is a pure formatting
/// upgrade, and if it fails the note still says everything. (Plain newlines are
/// not an option — Odoo stores them verbatim inside one `<p>`, where HTML
/// collapses them into a single run-on line.)
class MockLocationNote {
  final String plain;
  final String html;

  const MockLocationNote({required this.plain, required this.html});

  /// Human-readable coordinate pair, or a bilingual "unavailable" when the fix
  /// carried none.
  static String formatCoords(double? latitude, double? longitude) =>
      (latitude != null && longitude != null)
          ? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
          : 'unavailable / غير متاح';

  factory MockLocationNote.build({
    required SpoofPhase phase,
    double? latitude,
    double? longitude,
    String? location,
  }) {
    final at = phase == SpoofPhase.start ? 'check-in' : 'check-out';
    final atAr = phase == SpoofPhase.start ? 'بدء الزيارة' : 'إنهاء الزيارة';
    final coords = formatCoords(latitude, longitude);
    final where = location != null
        ? ' • Reported location / الموقع المُبلَّغ: $location'
        : '';

    // Reads correctly as one flowing line, because this is what survives if the
    // markup upgrade never lands.
    final plain = '⚠ Mock location detected at $at — تم رصد موقع وهمي عند $atAr'
        ' • The device reported these coordinates came from a fake-GPS app, not'
        ' the GPS sensor; this visit needs manual review.'
        ' • أبلغ الجهاز أن هذه الإحداثيات مصدرها تطبيق موقع وهمي وليست من مستشعر'
        ' GPS، وهذه الزيارة تحتاج مراجعة يدوية.'
        ' • Coordinates / الإحداثيات: $coords$where'
        ' • [$kMockLocationMarker]';

    final html = '<p><strong>⚠ Mock location detected at $at '
        '— تم رصد موقع وهمي عند $atAr</strong></p>'
        '<p>The device reported that these coordinates came from a mock '
        'location provider (a fake-GPS app), not the GPS sensor. '
        'This visit needs manual review.<br/>'
        'أبلغ الجهاز أن هذه الإحداثيات مصدرها تطبيق موقع وهمي وليست من '
        'مستشعر GPS. هذه الزيارة تحتاج مراجعة يدوية.</p>'
        '<ul><li>Coordinates / الإحداثيات: <code>$coords</code></li>'
        '${location != null ? '<li>Reported location / الموقع المُبلَّغ: $location</li>' : ''}'
        '</ul><p><code>$kMockLocationMarker</code></p>';

    return MockLocationNote(plain: plain, html: html);
  }
}
