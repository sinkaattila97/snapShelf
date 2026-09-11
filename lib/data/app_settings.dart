import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing preferences (theme + privacy toggles).
class AppSettings extends ChangeNotifier {
  AppSettings();

  static const _themeKey = 'snapshelf_theme_mode_v1';
  static const _secureScreenKey = 'snapshelf_secure_screen_v1';

  ThemeMode _themeMode = ThemeMode.system;
  bool _secureScreen = true;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get secureScreen => _secureScreen;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeKey);
    _themeMode = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _secureScreen = prefs.getBool(_secureScreenKey) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeKey, value);
  }

  Future<void> setSecureScreen(bool value) async {
    _secureScreen = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_secureScreenKey, value);
  }

  bool get isDarkEffective {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }
}
