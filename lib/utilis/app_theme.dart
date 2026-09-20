import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  static const double smallFont = 14;
  static const double mediumFont = 18;

  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: AppColors.dashboardBackground,
    canvasColor: AppColors.dashboardBackground,

    textTheme: GoogleFonts.poppinsTextTheme(),

    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryGreen,
      secondary: AppColors.darkGreen,
      error: AppColors.secondaryRed,
    ),

    bottomAppBarTheme: const BottomAppBarThemeData(
      color: Colors.transparent,
      elevation: 0,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: AppColors.white,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
      ),
    ),
  );
}