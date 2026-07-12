import '../api/api_client.dart';
import '../api/endpoints.dart';

/// Talks to the `dh_visit_management` device-token endpoints so the backend
/// knows where to deliver a visit push. Both calls use the same session cookie
/// as the rest of the app, so they must run while the user is authenticated.
///
/// See docs/BACKEND_PUSH_NOTIFICATIONS.md §3.
class PushRepository {
  final ApiClient api;

  PushRepository({required this.api});

  /// Upserts the current user's FCM token on the server (`register_device`).
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    await api.jsonRpc(
      Endpoints.registerDevice,
      params: {
        'token': token,
        'platform': platform,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
  }

  /// Removes the token server-side (`unregister_device`), called on logout so a
  /// signed-out device stops receiving that user's pushes.
  Future<void> unregisterDevice({required String token}) async {
    await api.jsonRpc(
      Endpoints.unregisterDevice,
      params: {'token': token},
    );
  }
}
