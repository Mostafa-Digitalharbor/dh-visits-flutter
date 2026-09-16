/// Tunables that belong to the visits feature alone.
///
/// App-wide values (page sizes, map zooms, the trail's sampling rules) stay in
/// `AppConstants`; these are the ones nothing outside `features/visits` reads.
abstract final class VisitConstants {
  /// Largest file a user may attach to a visit.
  ///
  /// The upload travels as base64 inside one JSON-RPC body, which inflates it
  /// by a third and has to fit in memory twice (bytes + text) on a budget
  /// phone. 10 MB covers a signed PDF or a handful of photos; a video does not
  /// belong on a visit record.
  static const int maxAttachmentBytes = 10 * 1024 * 1024;

  /// JPEG quality for a proof-of-visit photo taken in the app. Around 0.4 MB
  /// at [photoMaxWidth] — legible, and cheap to send from the field.
  static const int photoQuality = 70;

  /// Longest edge a proof-of-visit photo is scaled down to, in pixels.
  static const double photoMaxWidth = 1600;

  /// A visit shorter than this reads as suspiciously brief and is flagged on
  /// the detail screen.
  static const Duration shortVisit = Duration(minutes: 2);

  /// Rows fetched per search in the project / opportunity pickers. The search
  /// runs on the server, so this only bounds one page of matches.
  static const int pickerLimit = 80;

  /// Share of the screen height the action bar may take before it scrolls:
  /// enough for five stacked buttons on a phone, without burying the page.
  static const double actionBarMaxHeightFraction = 0.5;
}
