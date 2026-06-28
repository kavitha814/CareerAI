import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  static const String _settingsBoxName = 'settings_box';
  static const String _themeKey = 'theme_mode';

  Future<void> _loadTheme() async {
    final box = await Hive.openBox(_settingsBoxName);
    final savedMode = box.get(_themeKey) as String?;
    if (savedMode != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedMode,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    final box = Hive.box(_settingsBoxName);
    await box.put(_themeKey, newMode.toString());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final box = Hive.box(_settingsBoxName);
    await box.put(_themeKey, mode.toString());
  }
}
