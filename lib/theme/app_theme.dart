import 'package:flutter/material.dart';

//  Color Palette
class AppColors {
  // Brand / Accent
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8C5A);
  static const Color accent = Color(0xFF4A90D9);
  static const Color starColor = Color(0xFFFFC107);
  static const Color categoryChipSelected = Color(0xFF2C2C3E);

  // Light Mode
  static const Color lightBackground = Color(0xFFF5F0EB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1A1A2E);
  static const Color lightSubText = Color(0xFF6B6B80);
  static const Color lightDivider = Color(0xFFE5E0DB);
  static const Color lightSearchBg = Color(0xFFEFEAE4);
  static const Color lightNavBar = Color(0xFFFFFFFF);

  // Dark Mode
  static const Color darkBackground = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF252538);
  static const Color darkText = Color(0xFFF0EDE8);
  static const Color darkSubText = Color(0xFF9A97A8);
  static const Color darkDivider = Color(0xFF2E2E45);
  static const Color darkSearchBg = Color(0xFF252538);
  static const Color darkNavBar = Color(0xFF1A1A2E);

  // Gradient for top header
  static const LinearGradient headerGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB5A0), Color(0xFFFFD4C0)],
  );
  static const LinearGradient headerGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1A2E), Color(0xFF1A1A3E)],
  );
}

//  Box Shadows
class AppShadows {
  static List<BoxShadow> cardShadowLight = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadowDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> bookShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> navBarShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 12,
      offset: const Offset(0, -2),
    ),
  ];
}

//  Font Sizes
class AppFontSizes {
  static const double xs = 11.0;
  static const double sm = 13.0;
  static const double md = 15.0;
  static const double lg = 17.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 28.0;
}

//  Font Weights
class AppFontWeights {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

//  Spacing / Radius
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double cardRadius = 14.0;
  static const double bookCoverRadius = 10.0;
  static const double chipRadius = 20.0;
  static const double bottomSheetRadius = 24.0;
}
