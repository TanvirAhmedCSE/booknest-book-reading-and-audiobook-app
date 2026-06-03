import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppThemeData {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.lightSurface,
      background: AppColors.lightBackground,
      onPrimary: Colors.white,
      onSurface: AppColors.lightText,
      onBackground: AppColors.lightText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.lightText),
      titleTextStyle: TextStyle(
        color: AppColors.lightText,
        fontSize: AppFontSizes.lg,
        fontWeight: AppFontWeights.semiBold,
        fontFamily: 'Playfair',
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: AppColors.lightText,
        fontFamily: 'Playfair',
        fontWeight: AppFontWeights.bold,
        fontSize: AppFontSizes.xxxl,
      ),
      titleLarge: TextStyle(
        color: AppColors.lightText,
        fontFamily: 'Playfair',
        fontWeight: AppFontWeights.bold,
        fontSize: AppFontSizes.xl,
      ),
      titleMedium: TextStyle(
        color: AppColors.lightText,
        fontFamily: 'Playfair',
        fontWeight: AppFontWeights.semiBold,
        fontSize: AppFontSizes.lg,
      ),
      bodyLarge: TextStyle(
        color: AppColors.lightText,
        fontSize: AppFontSizes.md,
      ),
      bodyMedium: TextStyle(
        color: AppColors.lightSubText,
        fontSize: AppFontSizes.sm,
      ),
      labelSmall: TextStyle(
        color: AppColors.lightSubText,
        fontSize: AppFontSizes.xs,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightNavBar,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightSubText,
    ),
    iconTheme: const IconThemeData(color: AppColors.lightText),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
      background: AppColors.darkBackground,
      onPrimary: Colors.white,
      onSurface: AppColors.darkText,
      onBackground: AppColors.darkText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.darkText),
      titleTextStyle: TextStyle(
        color: AppColors.darkText,
        fontSize: AppFontSizes.lg,
        fontWeight: AppFontWeights.semiBold,
        fontFamily: 'Playfair',
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: AppColors.darkText,
        fontFamily: 'Playfair',
        fontWeight: AppFontWeights.bold,
        fontSize: AppFontSizes.xxxl,
      ),
      titleLarge: TextStyle(
        color: AppColors.darkText,
        fontFamily: 'Playfair',
        fontWeight: AppFontWeights.bold,
        fontSize: AppFontSizes.xl,
      ),
      titleMedium: TextStyle(
        color: AppColors.darkText,
        fontFamily: 'Playfair',
        fontWeight: AppFontWeights.semiBold,
        fontSize: AppFontSizes.lg,
      ),
      bodyLarge: TextStyle(
        color: AppColors.darkText,
        fontSize: AppFontSizes.md,
      ),
      bodyMedium: TextStyle(
        color: AppColors.darkSubText,
        fontSize: AppFontSizes.sm,
      ),
      labelSmall: TextStyle(
        color: AppColors.darkSubText,
        fontSize: AppFontSizes.xs,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkNavBar,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkSubText,
    ),
    iconTheme: const IconThemeData(color: AppColors.darkText),
  );
}

// Theme Mode Notifier
class ThemeModeNotifier extends ValueNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light);

  void toggleTheme() {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  bool get isDark => value == ThemeMode.dark;
}

// Global instance
final themeModeNotifier = ThemeModeNotifier();
