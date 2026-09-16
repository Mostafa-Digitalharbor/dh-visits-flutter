import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../constants/app_locales.dart';
import 'settings_repository.dart';

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final Locale locale;
  final bool notifications;

  const SettingsState({
    required this.themeMode,
    required this.locale,
    this.notifications = true,
  });

  static const defaultLocale = AppLocales.fallback;

  SettingsState copyWith({ThemeMode? themeMode, Locale? locale, bool? notifications}) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
        notifications: notifications ?? this.notifications,
      );

  @override
  List<Object?> get props => [themeMode, locale, notifications];
}

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository repository;

  /// Told after the language changes — the push service relabels its Android
  /// channel, which the OS shows under Settings → Notifications.
  final Future<void> Function(Locale locale)? onLocaleChanged;

  /// Told after the Notifications switch changes — the push service registers
  /// or forgets this device, so the switch actually stops the pushes.
  final Future<void> Function(bool enabled)? onNotificationsChanged;

  SettingsCubit({
    required this.repository,
    this.onLocaleChanged,
    this.onNotificationsChanged,
  }) : super(_initial(repository));

  static SettingsState _initial(SettingsRepository repo) => SettingsState(
        themeMode: _parseThemeMode(repo.readThemeMode()),
        locale: AppLocales.fromCode(repo.readLocale()),
        notifications: repo.readNotifications(),
      );

  Future<void> setNotifications(bool value) async {
    await repository.writeNotifications(value);
    emit(state.copyWith(notifications: value));
    await onNotificationsChanged?.call(value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await repository.writeThemeMode(mode.name);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setLocale(Locale locale) async {
    await repository.writeLocale(locale.languageCode);
    emit(state.copyWith(locale: locale));
    await onLocaleChanged?.call(locale);
  }

  /// Stored as [ThemeMode.name] (`light` / `dark` / `system`); anything else
  /// follows the system.
  static ThemeMode _parseThemeMode(String? raw) => ThemeMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => ThemeMode.system,
      );
}
