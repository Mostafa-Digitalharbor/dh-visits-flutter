/// Every key the app persists under, in one registry.
///
/// Scattered across a dozen classes these were impossible to audit: nobody
/// could answer "what does logout have to clear?" or spot two features picking
/// the same name. The `_vN` suffixes are part of the key — bumping one is how a
/// payload shape change abandons the old data instead of misreading it.
///
/// Values must never change once shipped; renaming a key silently drops the
/// data stored under the old one.
abstract final class StorageKeys {
  // ---- SharedPreferences: settings ----
  static const themeMode = 'pref_theme_mode';
  static const locale = 'pref_locale';
  static const notifications = 'pref_notifications';
  static const rememberedLogin = 'pref_remembered_login';

  // ---- SharedPreferences: server ----
  static const serverBaseUrl = 'server_base_url';
  static const serverDatabase = 'server_database';
  static const serverClockOffset = 'server_clock_offset_ms_v1';

  // ---- SharedPreferences: offline visit actions ----
  static const pendingActions = 'pending_visit_actions_v1';
  static const pendingActionsLastSync = 'pending_visit_actions_last_sync_v1';

  // ---- SharedPreferences: push ----
  static const pushDeviceId = 'push_device_id';
  static const pushLastToken = 'push_last_token';
  static const pushRegistered = 'push_registered_v1';

  // ---- SharedPreferences: visit GPS trail ----
  static const trailBuffer = 'visit_trail_buffer_v1';
  static const trailActiveVisit = 'visit_trail_active_visit_v2';
  static const trailNativeSeq = 'visit_trail_native_seq_v1';
  static const trailEndedVisits = 'visit_trail_ended_visits_v1';
  static const visitTrackingDisclosure = 'visit_tracking_disclosure_v1';
  /// Keys only the retired "active visit" marker wrote. Never read:
  /// [VisitTrailTracker] deletes them on start-up.
  ///
  /// The `workday_*` keys are **not** listed here: whole-work-day tracking is
  /// live again (`WorkdayTracker` owns those keys directly), so purging them
  /// would throw away an unfinished day and its unsent points on every launch.
  static const legacyLocationKeys = [
    'visit_trail_active_visit_v1',
  ];

  // ---- Secure storage (keystore / keychain) ----
  static const sessionUser = 'session_user';
  static const sessionLogin = 'session_login';
  static const sessionPassword = 'session_password';
  static const deviceIdentity = 'device_identity_v1';
}
