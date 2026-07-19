import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _kThemeMode = 'pref_theme_mode';
  static const _kLocale = 'pref_locale';
  static const _kNotifications = 'pref_notifications';
  static const _kRememberedLogin = 'pref_remembered_login';

  final SharedPreferences prefs;
  SettingsRepository({required this.prefs});

  /// The login (email/username) to pre-fill on the sign-in screen when the user
  /// ticked "Remember me". Only the identifier is kept — never the password.
  String? readRememberedLogin() => prefs.getString(_kRememberedLogin);

  Future<void> writeRememberedLogin(String value) =>
      prefs.setString(_kRememberedLogin, value);

  Future<void> clearRememberedLogin() => prefs.remove(_kRememberedLogin);

  String? readThemeMode() => prefs.getString(_kThemeMode);
  Future<void> writeThemeMode(String value) => prefs.setString(_kThemeMode, value);

  String? readLocale() => prefs.getString(_kLocale);
  Future<void> writeLocale(String value) => prefs.setString(_kLocale, value);

  /// Visit alerts/reminders toggle. Defaults to on when never set.
  bool readNotifications() => prefs.getBool(_kNotifications) ?? true;
  Future<void> writeNotifications(bool value) =>
      prefs.setBool(_kNotifications, value);
}
