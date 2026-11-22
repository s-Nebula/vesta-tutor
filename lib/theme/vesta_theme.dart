import 'package:flutter/material.dart';

class VestaTheme {
  static const Color burgundy = Color(0xFF421827);
  static const Color wine = Color(0xFF792D43);
  static const Color rose = Color(0xFFC15B68);
  static const Color ivory = Color(0xFFF4EDEA);
  static const Color dark = Color(0xFF211B20);
  static const Color beige = Color(0xFFD6B7A6);

  // ---------------------------------------------------------------------
  // Semantic colours: they change with light/dark mode. Use them instead of
  // fixed values so every screen follows the chosen theme.
  // ---------------------------------------------------------------------
  static bool _isDark = true;

  static bool get isDark => _isDark;

  /// Called by MyApp when building the app with the effective mode.
  static void applyBrightness(Brightness brightness) {
    _isDark = brightness == Brightness.dark;
  }

  static Color get background => _isDark ? dark : ivory;
  static Color get surface => _isDark ? const Color(0xFF30232B) : Colors.white;
  static Color get surfaceLight =>
      _isDark ? const Color(0xFF3B2933) : const Color(0xFFF1E6E3);
  static Color get textPrimary => _isDark ? ivory : dark;
  static Color get textSecondary => _isDark ? beige : const Color(0xFF6E5A62);
  static Color get border =>
      _isDark ? beige.withValues(alpha: 0.12) : burgundy.withValues(alpha: 0.12);

  // Estados: iguales en ambos modos.
  static const Color danger = Color(0xFFE03131);
  static const Color warning = Color(0xFFE3A008);
  static const Color info = Color(0xFF537FCB);
  static const Color success = Color(0xFF3FA772);
  static const Color study = Color(0xFF3B5BA5);

  /// Minimum text size across the app (accessibility).
  static const double minFontSize = 12;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [wine, rose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get backgroundGradient => LinearGradient(
        colors: _isDark
            ? const [dark, burgundy]
            : const [ivory, Color(0xFFF1E1DF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Degradado de fondo de pantallas de contenido (estado, filtros...).
  static LinearGradient get screenGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isDark
            ? const [Color(0xFF211B20), Color(0xFF421827), Color(0xFF30232B)]
            : const [Color(0xFFF4EDEA), Color(0xFFF7E9E8), Color(0xFFF4EDEA)],
      );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: dark,
      colorScheme: const ColorScheme.dark(
        primary: rose,
        secondary: beige,
        surface: Color(0xFF30232B),
        onPrimary: Colors.white,
        onSecondary: dark,
        onSurface: ivory,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: dark,
        foregroundColor: ivory,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF30232B),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: beige.withValues(alpha: 0.10),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: wine,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          elevation: 4,
          shadowColor: rose.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3B2933),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: beige.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: rose, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: rose,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: ivory,
      colorScheme: const ColorScheme.light(
        primary: wine,
        secondary: rose,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ivory,
        foregroundColor: dark,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 3,
        shadowColor: burgundy.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: wine,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          elevation: 4,
          shadowColor: rose.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1E6E3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: burgundy.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: wine, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: wine,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
