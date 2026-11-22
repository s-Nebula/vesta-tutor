import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme chosen by the user (dark by default). Stored on the phone
/// so it is not lost when the app is closed.
class ThemeNotifier extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeNotifier() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
      if (mode != null && mode != _themeMode) {
        _themeMode = mode;
        notifyListeners();
      }
    } catch (_) {
      // No storage: the default theme is used.
    }
  }

  void setTheme(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_key, mode.name))
        .ignore();
  }
}
