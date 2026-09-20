// import 'package:flutter/material.dart';

// class AppColors {
//   // Green
//   static const Color primaryGreen = Color(0xFF01AA45);
//   static const Color secondaryGreen = Color(0xFF00702D);
//   static const Color darkGreen = Color(0xFF00702D);

//   // Red
//   static const Color primaryRed = Color(0xFFED3237);
//   static const Color secondaryRed = Color(0xFFA01D20);

//   // Common
//   static const Color white = Color(0xFFFFFFFF);
//   static const Color black = Color(0xFF181818);

//   // Input
//   static const Color inputBackground = Color(0xFF2B2B2B);

//   // Progress Indicator
//   static const Color progressLine = Color(0x1AFFFFFF);
//   static const Color progressInactive = Color(0x3DFFFFFF);

//   // Primary Gradient
//   static const LinearGradient primaryGradient = LinearGradient(
//     begin: Alignment.topCenter,
//     end: Alignment.bottomCenter,
//     colors: [
//       primaryGreen,
//       secondaryGreen,
//     ],
//   );

//   static const LinearGradient secondaryGradient = LinearGradient(
//     begin: Alignment.topCenter,
//     end: Alignment.bottomCenter,
//     colors: [
//       primaryRed,
//       secondaryRed,
//     ],
//   );
// }

import 'package:flutter/material.dart';

class AppColors {
  // Green
  static const Color primaryGreen = Color(0xFFC0FF00);
  static const Color secondaryOrange = Color(0xFFE6AB6D);
  static const Color smokeywhite = Color(0xFFF8F6F0);
  // static const Color secondaryGreen = Color(0xFFC8870A);
  static const Color secondaryGreen = Color(0xFF0b1f14);
  static const Color darkGreen = Color(0xFF00702D);
  static const Color darkRed = Color(0xFF540502);
  static const Color red = Color(0xFFB82205);
  static const Color orange = Color(0xFFE26E25);
  static const Color lightOrange = Color(0xFFE6AB6D);
  // Dashboard
  static const Color dashboardBackground = Color(0xFF181818);
  static const Color dashboardAccent = Color(0xFFC0FF00);
  static const Color dashboardWhite = Color(0xFFFFFFFF);

  // Red
  static const Color primaryRed = Color(0xFFED3237);
  static const Color secondaryRed = Color(0xFFA01D20);

  // Common
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF181818);

  // Input
  static const Color inputBackground = Color(0xFF2B2B2B);

  // Progress Indicator
  static const Color progressLine = Color(0x1AFFFFFF);
  static const Color progressInactive = Color(0x3DFFFFFF);

  // Primary Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryGreen, secondaryGreen],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryRed, secondaryRed],
  );

  static const LinearGradient gradientRed = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkRed, red],
  );

  static LinearGradient gradientOrange = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    // colors: [orange, lightOrange],
    colors: [primaryGreen, white],
  );
}
