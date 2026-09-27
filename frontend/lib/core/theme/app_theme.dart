import 'package:flutter/material.dart';
import 'beast_tokens.dart';

/// AppColors acts as a semantic bridge mapping to the official BeastColors token system.
class AppColors {
  // Brand Structural Palette
  static const Color primary = BeastColors.brandPrimary;           // #242321 Dark Structural
  static const Color primaryLight = BeastColors.dark700;          // #34312F
  static const Color secondary = BeastColors.peach400;            // #FEC5BB Peach Accent
  static const Color secondaryLight = BeastColors.peach300;       // #FCD5CE
  static const Color accent = BeastColors.accentWarm;             // #FEC89A Warm Accent

  // Surfaces & Backgrounds
  static const Color background = BeastColors.scaffoldBackground; // #FAF8F5 Warm organic off-white
  static const Color surface = BeastColors.white;                 // #FFFFFF Pure White
  static const Color surfaceElevated = BeastColors.white;
  static const Color surfaceMuted = BeastColors.neutral100;       // #ECE4DB
  static const Color surfaceWarm = BeastColors.warm100;           // #FFE5D9
  static const Color border = BeastColors.borderSubtle;           // #EBE6DF
  static const Color divider = BeastColors.divider;

  // Typography
  static const Color textPrimary = BeastColors.textPrimary;       // #242321
  static const Color textSecondary = BeastColors.textSecondary;   // #514A46
  static const Color textMuted = BeastColors.textMuted;           // #7A736E
  static const Color textOnPrimary = BeastColors.textOnDark;      // #FFFFFF

  // Status Indicators
  static const Color success = BeastColors.success;               // #2D6A4F
  static const Color successLight = BeastColors.successLight;
  static const Color warning = BeastColors.warning;               // #D97706
  static const Color warningLight = BeastColors.warningLight;
  static const Color error = BeastColors.danger;                  // #C92A2A
  static const Color errorLight = BeastColors.dangerLight;
  static const Color info = BeastColors.info;                     // #1D4ED8
  static const Color infoLight = BeastColors.infoLight;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: BeastColors.brandPrimary,
      scaffoldBackgroundColor: BeastColors.scaffoldBackground,
      colorScheme: const ColorScheme.light(
        primary: BeastColors.brandPrimary,
        onPrimary: BeastColors.textOnDark,
        secondary: BeastColors.peach400,
        onSecondary: BeastColors.dark900,
        surface: BeastColors.white,
        onSurface: BeastColors.textPrimary,
        error: BeastColors.danger,
        onError: BeastColors.white,
      ),
      fontFamily: 'SpaceGrotesk',
      fontFamilyFallback: const ['SpaceGrotesk', 'sans-serif'],
      textTheme: _buildTextTheme().apply(
        fontFamily: 'SpaceGrotesk',
        fontFamilyFallback: const ['SpaceGrotesk', 'sans-serif'],
      ),
      primaryTextTheme: _buildTextTheme().apply(
        fontFamily: 'SpaceGrotesk',
        fontFamilyFallback: const ['SpaceGrotesk', 'sans-serif'],
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BeastColors.white,
        foregroundColor: BeastColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: BeastColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: BeastColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeastRadius.md),
          side: const BorderSide(color: BeastColors.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BeastColors.brandPrimary,
          foregroundColor: BeastColors.textOnDark,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BeastRadius.sm),
          ),
          textStyle: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BeastColors.textPrimary,
          side: const BorderSide(color: BeastColors.borderStrong, width: 1.2),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BeastRadius.sm),
          ),
          textStyle: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BeastColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeastRadius.sm),
          borderSide: const BorderSide(color: BeastColors.borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeastRadius.sm),
          borderSide: const BorderSide(color: BeastColors.borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeastRadius.sm),
          borderSide: const BorderSide(color: BeastColors.focus, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeastRadius.sm),
          borderSide: const BorderSide(color: BeastColors.danger, width: 1),
        ),
        labelStyle: const TextStyle(fontFamily: 'SpaceGrotesk', color: BeastColors.textSecondary, fontSize: 14),
        hintStyle: const TextStyle(fontFamily: 'SpaceGrotesk', color: BeastColors.textMuted, fontSize: 14),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: BeastColors.white,
        titleTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: BeastColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: BeastColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BeastColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    const String font = 'SpaceGrotesk';
    const List<String> fallback = ['SpaceGrotesk', 'sans-serif'];
    return const TextTheme(
      displayLarge: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 32, fontWeight: FontWeight.w800, color: BeastColors.textPrimary, letterSpacing: -0.6),
      displayMedium: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 28, fontWeight: FontWeight.w800, color: BeastColors.textPrimary, letterSpacing: -0.5),
      displaySmall: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 24, fontWeight: FontWeight.w700, color: BeastColors.textPrimary, letterSpacing: -0.4),
      headlineLarge: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 22, fontWeight: FontWeight.w700, color: BeastColors.textPrimary, letterSpacing: -0.4),
      headlineMedium: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 20, fontWeight: FontWeight.w700, color: BeastColors.textPrimary, letterSpacing: -0.3),
      headlineSmall: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 18, fontWeight: FontWeight.w600, color: BeastColors.textPrimary, letterSpacing: -0.2),
      titleLarge: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 18, fontWeight: FontWeight.w600, color: BeastColors.textPrimary, letterSpacing: -0.2),
      titleMedium: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 16, fontWeight: FontWeight.w600, color: BeastColors.textPrimary, letterSpacing: -0.1),
      titleSmall: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 14, fontWeight: FontWeight.w600, color: BeastColors.textPrimary, letterSpacing: 0),
      bodyLarge: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 16, fontWeight: FontWeight.w400, color: BeastColors.textPrimary),
      bodyMedium: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 14, fontWeight: FontWeight.w400, color: BeastColors.textPrimary),
      bodySmall: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 12, fontWeight: FontWeight.w400, color: BeastColors.textSecondary),
      labelLarge: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 14, fontWeight: FontWeight.w600, color: BeastColors.textPrimary, letterSpacing: 0.1),
      labelMedium: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 12, fontWeight: FontWeight.w600, color: BeastColors.textSecondary, letterSpacing: 0.2),
      labelSmall: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 11, fontWeight: FontWeight.w500, color: BeastColors.textMuted, letterSpacing: 0.3),
    );
  }
}
