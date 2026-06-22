import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

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

  static const defaultLocale = Locale('ar');

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

  SettingsCubit({required this.repository})
      : super(_initial(repository));

  static SettingsState _initial(SettingsRepository repo) {
    final mode = _parseThemeMode(repo.readThemeMode());
    final locale = _parseLocale(repo.readLocale());
    return SettingsState(
      themeMode: mode,
      locale: locale,
      notifications: repo.readNotifications(),
    );
  }

  Future<void> setNotifications(bool value) async {
    await repository.writeNotifications(value);
    emit(state.copyWith(notifications: value));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await repository.writeThemeMode(_themeModeToString(mode));
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setLocale(Locale locale) async {
    await repository.writeLocale(locale.languageCode);
    emit(state.copyWith(locale: locale));
  }

  static ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static Locale _parseLocale(String? code) {
    if (code == 'en') return const Locale('en');
    return SettingsState.defaultLocale;
  }
}
