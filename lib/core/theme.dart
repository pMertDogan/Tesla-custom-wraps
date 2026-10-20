import 'package:flutter/material.dart';

/// Colours shared across the studio.
class StudioColors {
  const StudioColors._();

  /// Page background.
  static const Color background = Color(0xFF0A0A0A);

  /// Panel background.
  static const Color surface = Color(0xFF141414);

  /// Raised surface.
  static const Color surfaceHigh = Color(0xFF1E1E1E);

  /// Primary accent.
  static const Color accent = Color(0xFFE31937);

  /// Secondary accent used for AI actions.
  static const Color aiAccent = Color(0xFF3D7BFF);
}

/// Builds the dark theme used across the studio.
ThemeData buildStudioTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: StudioColors.accent,
    scaffoldBackgroundColor: StudioColors.background,
    colorScheme: const ColorScheme.dark(
      primary: StudioColors.accent,
      secondary: StudioColors.aiAccent,
      surface: StudioColors.surface,
    ),
    fontFamily: 'Roboto',
    useMaterial3: true,
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: StudioColors.surfaceHigh,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withAlpha(13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
