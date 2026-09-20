import 'package:flutter/material.dart';

import '../responsiveness/responsive_repo.dart';
import '../utilis/app_colors.dart';

class AppProgressIndicatorWidget extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  final double? dotSize;
  final double? lineThickness;

  final double? lineSpacing;
  final double? dotSpacing;

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  final Color? activeColor;
  final Color? inactiveColor;
  final Color? lineColor;

  const AppProgressIndicatorWidget({
    super.key,

    // Default: 3rd step active
    this.currentStep = 2,
    this.totalSteps = 3,

    this.dotSize,
    this.lineThickness,

    this.lineSpacing,
    this.dotSpacing,

    this.top,
    this.left,
    this.right,
    this.bottom,

    this.activeColor,
    this.inactiveColor,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    // Prevent invalid total steps
    final int safeTotalSteps = totalSteps < 1 ? 1 : totalSteps;

    // Keep current step within valid range
    final int safeCurrentStep = currentStep < 0
        ? 0
        : currentStep >= safeTotalSteps
        ? safeTotalSteps - 1
        : currentStep;

    return Padding(
      padding: EdgeInsets.only(
        top: top ?? 0,
        left: left ?? 0,
        right: right ?? 0,
        bottom: bottom ?? 0,
      ),
      child: Row(
        children: [
          // Left Line
          Expanded(
            child: Divider(
              color: lineColor ?? AppColors.progressLine,
              thickness: lineThickness ?? 1,
            ),
          ),

          // Space before dots
          SizedBox(
            width: lineSpacing ?? responsive.w(3),
          ),

          // Progress Dots
          ...List.generate(
            safeTotalSteps,
                (index) {
              final bool isActive = index <= safeCurrentStep;

              return Row(
                children: [
                  Container(
                    width: dotSize ?? responsive.w(2.5),
                    height: dotSize ?? responsive.w(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? activeColor ?? AppColors.white
                          : inactiveColor ??
                          AppColors.progressInactive,
                    ),
                  ),

                  // Space between dots
                  if (index != safeTotalSteps - 1)
                    SizedBox(
                      width: dotSpacing ?? responsive.w(1),
                    ),
                ],
              );
            },
          ),

          // Space after dots
          SizedBox(
            width: lineSpacing ?? responsive.w(3),
          ),

          // Right Line
          Expanded(
            child: Divider(
              color: lineColor ?? AppColors.progressLine,
              thickness: lineThickness ?? 1,
            ),
          ),
        ],
      ),
    );
  }
}