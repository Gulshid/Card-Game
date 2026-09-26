import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Emits the app's `ThemeMode`. Deliberately a `Cubit<ThemeMode>` (not
/// a custom state class) — there is nothing else to carry, and adding
/// a wrapper class here would be ceremony without benefit.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({required SharedPreferences prefs})
      : _prefs = prefs,
        super(_readInitial(prefs));

  final SharedPreferences _prefs;
  static const String _key = 'settings.themeMode';

  static ThemeMode _readInitial(SharedPreferences prefs) {
    switch (prefs.getString(_key)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(mode);
    await _prefs.setString(_key, mode.name);
  }
}
