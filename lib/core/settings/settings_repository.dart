import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _kThemeMode = 'pref_theme_mode';
  static const _kLocale = 'pref_locale';

  final SharedPreferences prefs;
  SettingsRepository({required this.prefs});

  String? readThemeMode() => prefs.getString(_kThemeMode);
  Future<void> writeThemeMode(String value) => prefs.setString(_kThemeMode, value);

  String? readLocale() => prefs.getString(_kLocale);
  Future<void> writeLocale(String value) => prefs.setString(_kLocale, value);
}
