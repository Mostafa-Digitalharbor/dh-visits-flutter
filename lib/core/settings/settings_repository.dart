import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';

/// The user's app settings, persisted in SharedPreferences.
///
/// Every read tolerates a value of the wrong type under its key (left by an
/// older build or a restored backup): SharedPreferences throws a TypeError
/// for those, and a settings read runs on start-up, where a throw means the
/// app never opens. The default is returned instead.
class SettingsRepository {
  static const _kThemeMode = StorageKeys.themeMode;
  static const _kLocale = StorageKeys.locale;
  static const _kNotifications = StorageKeys.notifications;
  static const _kRememberedLogin = StorageKeys.rememberedLogin;

  final SharedPreferences prefs;
  SettingsRepository({required this.prefs});

  /// The login (email/username) to pre-fill on the sign-in screen when the user
  /// ticked "Remember me". Only the identifier is kept — never the password.
  String? readRememberedLogin() => _string(_kRememberedLogin);

  Future<void> writeRememberedLogin(String value) =>
      prefs.setString(_kRememberedLogin, value);

  Future<void> clearRememberedLogin() => prefs.remove(_kRememberedLogin);

  String? readThemeMode() => _string(_kThemeMode);
  Future<void> writeThemeMode(String value) => prefs.setString(_kThemeMode, value);

  String? readLocale() => _string(_kLocale);
  Future<void> writeLocale(String value) => prefs.setString(_kLocale, value);

  /// Visit alerts/reminders toggle. Defaults to on when never set.
  bool readNotifications() {
    try {
      return prefs.getBool(_kNotifications) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> writeNotifications(bool value) =>
      prefs.setBool(_kNotifications, value);

  String? _string(String key) {
    try {
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }
}
