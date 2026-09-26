import 'package:flutter/material.dart';

/// B.E.A.S.T ACADEMY — Master Design Tokens
/// Semantic design system defining palette, typography, spacing, radius,
/// elevation, motion, and responsive breakpoints.
class BeastColors {
  // --- Raw Color Palette ---

  // Pink / Peach Family
  static const Color peach100 = Color(0xFFF8EDEB);
  static const Color peach200 = Color(0xFFFAE1DD);
  static const Color peach300 = Color(0xFFFCD5CE);
  static const Color peach400 = Color(0xFFFEC5BB);

  // Neutral / Organic Family
  static const Color neutral100 = Color(0xFFECE4DB);
  static const Color neutral200 = Color(0xFFE8E8E4);
  static const Color neutral300 = Color(0xFFD8E2DC);
  static const Color neutral400 = Color(0xFFC0BCB5);

  // Warm Accent Family
  static const Color warm100 = Color(0xFFFFE5D9);
  static const Color warm200 = Color(0xFFFFD7BA);
  static const Color warm300 = Color(0xFFFEC89A);

  // Dark Structural Tones (Readability & Authority)
  static const Color dark900 = Color(0xFF242321);
  static const Color dark800 = Color(0xFF2B2927);
  static const Color dark700 = Color(0xFF34312F);
  static const Color dark600 = Color(0xFF403B38);
  static const Color dark500 = Color(0xFF514A46);

  // White Surface
  static const Color white = Color(0xFFFFFFFF);

  // --- Semantic Color Tokens ---

  // Surfaces
  static const Color surfacePrimary = white;
  static const Color surfaceSecondary = peach100;
  static const Color surfaceElevated = white;
  static const Color surfaceMuted = neutral100;
  static const Color surfaceWarm = warm100;
  static const Color surfaceAccent = peach400;
  static const Color surfaceDark = dark900;
  static const Color surfaceCard = white;
  static const Color scaffoldBackground = Color(0xFFFAF8F5); // Warm organic off-white

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFFEBE6DF);
  static const Color borderStrong = neutral300;
  static const Color borderFocus = dark700;
  static const Color divider = Color(0xFFE8E4DF);

  // Typography
  static const Color textPrimary = dark900;
  static const Color textSecondary = dark500;
  static const Color textMuted = Color(0xFF7A736E);
  static const Color textOnDark = white;
  static const Color textOnPeach = dark900;

  // Brand Structural
  static const Color brandPrimary = dark900;
  static const Color primary = brandPrimary;
  static const Color brandSecondary = peach400;
  static const Color accentWarm = warm300;
  static const Color accentPeach = peach300;

  // Semantic Status Colors
  static const Color success = Color(0xFF2D6A4F);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFC92A2A);
  static const Color dangerLight = Color(0xFFFDE8E8);
  static const Color error = danger;
  static const Color errorLight = dangerLight;
  static const Color surfaceNeutral = Color(0xFFFAF8F5);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoLight = Color(0xFFEFF6FF);

  // Interactive
  static const Color focus = dark700;
  static const Color hover = Color(0x0A242321);
}

class BeastSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;
}

class BeastRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double full = 999.0;

  static BorderRadius get borderXs => BorderRadius.circular(xs);
  static BorderRadius get borderSm => BorderRadius.circular(sm);
  static BorderRadius get borderMd => BorderRadius.circular(md);
  static BorderRadius get borderLg => BorderRadius.circular(lg);
  static BorderRadius get borderXl => BorderRadius.circular(xl);
  static BorderRadius get borderFull => BorderRadius.circular(full);
}

class BeastShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A242321),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0C242321),
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x12242321),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> dialog = [
    BoxShadow(
      color: Color(0x24242321),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];
}

class BeastMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasis = Duration(milliseconds: 300);

  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
}

class BeastBreakpoints {
  static const double mobileMax = 599.0;
  static const double tabletMax = 899.0;
  static const double desktopMin = 900.0;
  static const double desktopLarge = 1200.0;
  static const double desktopUltra = 1440.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width <= mobileMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w > mobileMax && w <= tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopMin;
}

class BeastTypography {
  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: BeastColors.textPrimary,
    letterSpacing: -0.6,
    height: 1.2,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: BeastColors.textPrimary,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: BeastColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: BeastColors.textSecondary,
    letterSpacing: -0.1,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: BeastColors.textPrimary,
    letterSpacing: 0,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: BeastColors.textPrimary,
    letterSpacing: 0,
    height: 1.45,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: BeastColors.textSecondary,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: BeastColors.textMuted,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const TextStyle metric = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: BeastColors.textPrimary,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w900,
    color: BeastColors.textPrimary,
    letterSpacing: -0.8,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle h1 = display;
  static const TextStyle h2 = headline;
  static const TextStyle h3 = title;
  static const TextStyle bodyLarge = bodyMedium;
}
