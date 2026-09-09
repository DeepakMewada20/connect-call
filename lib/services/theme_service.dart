import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing dynamic Light, Dark, and System Default theme modes with persistence.
class ThemeService extends GetxService {
  static const String themePreferenceKey = 'app_theme_mode';
  static const String themeModeSystem = 'system';
  static const String themeModeLight = 'light';
  static const String themeModeDark = 'dark';

  static ThemeService? _instance;
  static ThemeService get instance => _instance ??= ThemeService();
  static void setInstance(ThemeService? service) => _instance = service;

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  SharedPreferences? _preferences;

  ThemeService({SharedPreferences? preferences}) {
    _preferences = preferences;
  }

  /// Initializes stored theme preference or defaults to system mode.
  Future<void> init({SharedPreferences? preferences}) async {
    try {
      _preferences = preferences ?? await SharedPreferences.getInstance();
      final storedMode = _preferences?.getString(themePreferenceKey);

      switch (storedMode) {
        case themeModeLight:
          themeMode.value = ThemeMode.light;
          break;
        case themeModeDark:
          themeMode.value = ThemeMode.dark;
          break;
        case themeModeSystem:
        default:
          themeMode.value = ThemeMode.system;
          break;
      }
    } catch (e) {
      debugPrint('[ThemeService] Failed to load theme mode preference: $e');
      themeMode.value = ThemeMode.system;
    }
  }

  /// Updates the active theme mode, saves to persistent storage, and triggers UI change.
  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;

    // Change GetX application-level theme mode
    try {
      Get.changeThemeMode(mode);
    } catch (_) {}

    // Persist choice
    try {
      _preferences ??= await SharedPreferences.getInstance();
      String modeString;
      switch (mode) {
        case ThemeMode.light:
          modeString = themeModeLight;
          break;
        case ThemeMode.dark:
          modeString = themeModeDark;
          break;
        case ThemeMode.system:
          modeString = themeModeSystem;
          break;
      }
      await _preferences?.setString(themePreferenceKey, modeString);
    } catch (e) {
      debugPrint('[ThemeService] Failed to persist theme mode: $e');
    }
  }

  /// Human-readable display label for the currently active theme mode.
  String get currentThemeName {
    switch (themeMode.value) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  /// Check whether the app is currently resolving to dark mode.
  bool isDark(BuildContext context) {
    if (themeMode.value == ThemeMode.dark) return true;
    if (themeMode.value == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}
