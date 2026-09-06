import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const forest = Color(0xFF0B4A30);
  static const forestDark = Color(0xFF073821);
  static const moss = Color(0xFF5A8C61);
  static const cream = Color(0xFFF7F3EA);
  static const creamStrong = Color(0xFFFFFCF6);
  static const ink = Color(0xFF173326);
  static const border = Color(0xFFD9DED8);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: forest,
      brightness: Brightness.light,
      surface: creamStrong,
    ).copyWith(
      primary: forest,
      onPrimary: Colors.white,
      secondary: moss,
      surface: creamStrong,
      onSurface: ink,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
      fontFamilyFallback: const ['Segoe UI', 'Roboto', 'Arial'],
      appBarTheme: const AppBarTheme(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerColor: border,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: forest,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: forest,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF64C47A),
        linearTrackColor: Color(0xFF285C43),
      ),
    );
  }
}
