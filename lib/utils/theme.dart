import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF6B4EFF);
  static const primaryLight = Color(0xFF9B7FFF);
  static const secondary = Color(0xFFFF6B9D);
  static const background = Color(0xFFF5F4FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0EEFF);
  static const onSurface = Color(0xFF1A1730);
  static const onSurfaceVariant = Color(0xFF6B6880);
  static const accent1 = Color(0xFF4ECBFF);
  static const accent2 = Color(0xFFFF9F4E);
  static const accent3 = Color(0xFF4EFF9F);

  static const stickyColors = [
    Color(0xFFFFF176), // yellow
    Color(0xFFFFCC80), // orange
    Color(0xFFA5D6A7), // green
    Color(0xFF80DEEA), // cyan
    Color(0xFFCE93D8), // purple
    Color(0xFFEF9A9A), // red
    Color(0xFF90CAF9), // blue
    Color(0xFFF48FB1), // pink
  ];

  static const coverColors = [
    Color(0xFF6B4EFF),
    Color(0xFFFF6B9D),
    Color(0xFF4ECBFF),
    Color(0xFFFF9F4E),
    Color(0xFF2D9CDB),
    Color(0xFF27AE60),
    Color(0xFFEB5757),
    Color(0xFF9B51E0),
    Color(0xFFF2994A),
    Color(0xFF219653),
    Color(0xFF1A1730),
    Color(0xFF4A90D9),
  ];

  static const coverEmojis = [
    '📓', '📔', '📒', '📕', '📗', '📘', '📙',
    '✨', '🌟', '💡', '🎨', '🎯', '🚀', '💎',
    '🌸', '🦋', '🌈', '⚡', '🔥', '❄️', '🌙',
    '📝', '✍️', '🖊️', '📌', '🗒️', '📋', '📄',
  ];

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          secondary: secondary,
          surface: surface,
          background: background,
        ),
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: onSurface),
          titleTextStyle: TextStyle(
            fontFamily: 'Nunito',
            color: onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: surface,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              color: onSurface),
          displayMedium: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              color: onSurface),
          headlineLarge: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              color: onSurface),
          headlineMedium: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: onSurface),
          titleLarge: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: onSurface),
          bodyLarge: TextStyle(fontFamily: 'Nunito', color: onSurface),
          bodyMedium:
              TextStyle(fontFamily: 'Nunito', color: onSurfaceVariant),
        ),
      );
}
