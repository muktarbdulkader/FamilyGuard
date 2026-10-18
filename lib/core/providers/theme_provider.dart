import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemePreferenceKey = 'app_theme_mode_preference';

/// Notifier to manage dark/light theme toggle across all app screens
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_kThemePreferenceKey);
      if (savedMode == 'light') {
        state = ThemeMode.light;
      } else {
        // Default to dark navy matching the app design
        state = ThemeMode.dark;
      }
    } catch (e) {
      debugPrint('Theme preference load error: $e');
    }
  }

  Future<void> toggleTheme() async {
    final nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = nextMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kThemePreferenceKey,
        nextMode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('Theme preference save error: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kThemePreferenceKey,
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('Theme preference save error: $e');
    }
  }
}

/// Global provider for application ThemeMode (Dark Navy vs Light)
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
