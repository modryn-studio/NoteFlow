import 'package:flutter/material.dart';

class AppColors {
  // Primary Backgrounds
  static const Color deepIndigo = Color(0xFF0f0f1e);
  static const Color darkPurple = Color(0xFF1a1a2e);
  static const Color charcoal = Color(0xFF16161a);

  // Glass Tint (overlay on cards)
  static const Color glassTint = Color(0xFF2d2d3d);
  static const Color glassHighlight = Color(0xFF3d3d4d);

  // Accent Colors (Desaturated, calm)
  static const Color softLavender = Color(0xFF9d8fb8);
  static const Color mintGlow = Color(0xFF88c0c0);
  static const Color softTeal = Color(0xFF6b9ea8);

  // Text
  static const Color pearlWhite = Color(0xFFe8e8ea);
  static const Color subtleGray = Color(0xFFb0b0b5);

  // Frequency Glows
  static const Color warmGlow = Color(0xFFffa894);
  static const Color coolGlow = Color(0xFF94c3ff);
  static const Color archiveGlow = Color(0xFF8888aa);

  // Gradient helpers
  static LinearGradient get backgroundGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [deepIndigo, darkPurple],
      );

  static LinearGradient get glassGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          glassTint.withValues(alpha: 0.3),
          darkPurple.withValues(alpha: 0.2),
        ],
      );
}

class AppTypography {
  static const String fontFamily = 'Inter';

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    color: AppColors.pearlWhite,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    color: AppColors.pearlWhite,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.pearlWhite,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 18,
    color: AppColors.pearlWhite,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w300,
    fontSize: 14,
    color: AppColors.subtleGray,
  );

  static const TextStyle tag = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors.softLavender,
  );
}

class AppAnimations {
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve defaultCurve = Curves.easeOutCubic;
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.deepIndigo,
        primaryColor: AppColors.softLavender,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.softLavender,
          secondary: AppColors.mintGlow,
          surface: AppColors.darkPurple,
          error: AppColors.warmGlow,
        ),
        fontFamily: AppTypography.fontFamily,
        textTheme: const TextTheme(
          headlineLarge: AppTypography.heading,
          headlineMedium: AppTypography.headingSmall,
          bodyLarge: AppTypography.bodyLarge,
          bodyMedium: AppTypography.body,
          bodySmall: AppTypography.caption,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: AppTypography.heading,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.softLavender,
          foregroundColor: AppColors.deepIndigo,
        ),
      );
}
