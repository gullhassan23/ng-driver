import 'package:flutter/material.dart';

import '../responsiveness/responsive_repo.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle small(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: responsive.h(1.75),
      color: AppColors.darkGreen,
      fontWeight: FontWeight.w400,
    );
  }

  // =========================
  // Extra Large Text
  // =========================
  static TextStyle extraLarge(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: responsive.h(7.5),
      fontWeight: FontWeight.w300,
      height: 1.0,
      letterSpacing: -(responsive.h(4.5) * 0.03),
    );
  }

  // =========================
  // Extra Large Bold Text
  // =========================
  static TextStyle extraLargeBold(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return TextStyle(
      fontSize: responsive.h(5.5),
      fontWeight: FontWeight.w300,
      height: 1.0,
      letterSpacing: -(responsive.h(5.5) * 0.03),
    );
  }

  static TextStyle medium(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: responsive.h(2.87),
      color: AppColors.white,
      fontWeight: FontWeight.w300,
      height: 1.04, // Line height 104%
      letterSpacing: -(responsive.h(2.87) * 0.05), // Letter spacing -5%
    );
  }

  static TextStyle large(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return TextStyle(
      fontFamily: 'Poppins',

      fontSize: responsive.h(3.625), // 29px
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle whiteSmall(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: responsive.h(1.75),
      color: AppColors.white,
      fontWeight: FontWeight.w400,
    );
  }

  static TextStyle whiteMedium(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: responsive.h(2.25),
      color: AppColors.white,
      fontWeight: FontWeight.w500,
    );
  }
}
