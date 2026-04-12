import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppSettingsState {
  const AppSettingsState({
    required this.locale,
    required this.themeMode,
  });

  final Locale locale;
  final ThemeMode themeMode;

  AppSettingsState copyWith({
    Locale? locale,
    ThemeMode? themeMode,
  }) {
    return AppSettingsState(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit()
      : super(
          const AppSettingsState(
            locale: Locale('en'),
            themeMode: ThemeMode.system,
          ),
        );

  void setLocale(Locale locale) {
    emit(state.copyWith(locale: locale));
  }

  void toggleTheme(bool isDark) {
    emit(state.copyWith(themeMode: isDark ? ThemeMode.dark : ThemeMode.light));
  }
}
