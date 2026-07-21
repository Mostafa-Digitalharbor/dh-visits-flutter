import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import 'app_log.dart';

/// Small helpers around `url_launcher` for the two outbound actions the
/// app needs: calling the customer and opening their coords in the system
/// maps app. Both return `true` on success so callers can show a snackbar.
class Communications {
  Communications._();

  /// Launch the phone dialer pre-filled with [phone].
  static Future<bool> dial(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    return _launch(uri);
  }

  /// Open the mail composer addressed to [email].
  static Future<bool> mailto(String email) async {
    final uri = Uri(scheme: 'mailto', path: email.trim());
    return _launch(uri);
  }

  /// Open [url] in the browser. Prepends `https://` when the value has no
  /// scheme so a bare `example.com` still resolves.
  static Future<bool> openWeb(String url) async {
    var normalized = url.trim();
    if (!normalized.startsWith(RegExp(r'https?://'))) {
      normalized = 'https://$normalized';
    }
    return _launch(Uri.parse(normalized));
  }

  /// Open the user's preferred maps app at the given coordinates. The
  /// `geo:` scheme works on Android (Google Maps, Waze, etc.). On iOS we
  /// fall back to a universal Google Maps web URL which iOS knows to hand
  /// off to its installed maps apps.
  static Future<bool> openInMaps(
    double latitude,
    double longitude, {
    String? label,
  }) async {
    final query = '$latitude,$longitude';
    final geoUri = Uri.parse(
      'geo:$latitude,$longitude?q='
      '${Uri.encodeComponent(label != null ? "$query($label)" : query)}',
    );
    if (await canLaunchUrl(geoUri)) {
      return _launch(geoUri);
    }
    final webUri = Uri.parse('${AppConstants.googleMapsSearchUrl}$query');
    return _launch(webUri);
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      appLog('[debug] Communications.launch failed: $e');
      return false;
    }
  }
}
