// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Tailwind-like swatches
  static const MaterialColor emerald = MaterialColor(
    0xFF10B981,
    <int, Color>{
      50:  Color(0xFFECFDF5),
      100: Color(0xFFD1FAE5),
      200: Color(0xFFA7F3D0),
      300: Color(0xFF6EE7B7),
      400: Color(0xFF34D399),
      500: Color(0xFF10B981),
      600: Color(0xFF059669),
      700: Color(0xFF047857),
      800: Color(0xFF065F46),
      900: Color(0xFF064E3B),
    },
  );

  static const MaterialColor amber = Colors.amber;

  static const MaterialColor indigo = MaterialColor(
    0xFF6366F1,
    <int, Color>{
      50:  Color(0xFFEEF2FF),
      100: Color(0xFFE0E7FF),
      200: Color(0xFFC7D2FE),
      300: Color(0xFFA5B4FC),
      400: Color(0xFF818CF8),
      500: Color(0xFF6366F1),
      600: Color(0xFF4F46E5),
      700: Color(0xFF4338CA),
      800: Color(0xFF3730A3),
      900: Color(0xFF312E81),
    },
  );

  // Light Theme Colors
  static const Color lightBackground     = Color(0xFFEFF6FF);
  static const Color lightSurface        = Color(0xFFFFFFFF);
  static const Color lightPrimary        = Color(0xFF4F46E5);
  static const Color lightPrimaryHover   = Color(0xFF6366F1);
  static const Color lightPrimaryText    = Color(0xFF111827);
  static const Color lightSecondaryText  = Color(0xFF6B7280);
  static const Color lightBorder         = Color(0xFFE5E7EB);

  // Dark Theme Colors
  static const Color darkBackground      = Color(0xFF111827);
  static const Color darkSurface         = Color(0xFF1F2937);
  static const Color darkPrimary         = Color(0xFF6366F1);
  static const Color darkPrimaryHover    = Color(0xFF818CF8);
  static const Color darkPrimaryText     = Color(0xFFF9FAFB);
  static const Color darkSecondaryText   = Color(0xFF9CA3AF);
  static const Color darkBorder          = Color(0xFF374151);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    dividerColor: lightBorder, // <- used for borders/separators
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      secondary: lightPrimaryHover,
      surface: lightSurface,
      background: lightBackground,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightPrimaryText,
      onBackground: lightPrimaryText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightSurface,
      foregroundColor: lightPrimaryText,
      elevation: 1,
      shadowColor: Colors.black12,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black12,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: lightPrimary, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: lightPrimary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: lightPrimaryText,   fontFamily: 'Inter'),
      displayMedium:  TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: lightPrimaryText,   fontFamily: 'Inter'),
      headlineLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: lightPrimaryText,   fontFamily: 'Inter'),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: lightPrimaryText,   fontFamily: 'Inter'),
      titleLarge:     TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: lightPrimaryText,   fontFamily: 'Inter'),
      bodyLarge:      TextStyle(fontSize: 16, color: lightPrimaryText,      fontFamily: 'Inter'),
      bodyMedium:     TextStyle(fontSize: 14, color: lightSecondaryText,    fontFamily: 'Inter'),
    ),
    fontFamily: 'Inter',
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    dividerColor: darkBorder, // <- used for borders/separators
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      secondary: darkPrimaryHover,
      surface: darkSurface,
      background: darkBackground,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkPrimaryText,
      onBackground: darkPrimaryText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkPrimaryText,
      elevation: 1,
      shadowColor: Colors.black26,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black26,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: darkBorder),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: darkBorder),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: darkPrimary, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: darkPrimary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: darkPrimaryText,   fontFamily: 'Inter'),
      displayMedium:  TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: darkPrimaryText,   fontFamily: 'Inter'),
      headlineLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkPrimaryText,   fontFamily: 'Inter'),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: darkPrimaryText,   fontFamily: 'Inter'),
      titleLarge:     TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: darkPrimaryText,   fontFamily: 'Inter'),
      bodyLarge:      TextStyle(fontSize: 16, color: darkPrimaryText,       fontFamily: 'Inter'),
      bodyMedium:     TextStyle(fontSize: 14, color: darkSecondaryText,     fontFamily: 'Inter'),
    ),
    fontFamily: 'Inter',
  );
}

// --- Convenience shim so widgets can use AppColors.* ---
class AppColors {
  static const MaterialColor emerald = AppTheme.emerald;
  static const MaterialColor amber   = AppTheme.amber;
  static const MaterialColor indigo  = AppTheme.indigo;

  // Theme-aware border color
  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkBorder
          : AppTheme.lightBorder;
}
