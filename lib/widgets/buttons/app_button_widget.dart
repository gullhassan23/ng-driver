// import 'package:flutter/material.dart';

// import '../utilis/app_colors.dart';
// import '../utilis/app_text_styles.dart';

// class AppButtonWidget extends StatelessWidget {
//   final String text;

//   final VoidCallback? onPressed;

//   // Size
//   final double? width;
//   final double? height;

//   // Padding / Margin
//   final double? top;
//   final double? left;
//   final double? right;
//   final double? bottom;

//   // Colors
//   final Color? backgroundColor;
//   final Color? disabledBackgroundColor;
//   final Color? foregroundColor;

//   // Gradient
//   final Gradient? gradient;
//   final bool useGradient;

//   // Border
//   final double? borderRadius;
//   final Color? borderColor;
//   final double? borderWidth;

//   // Button padding
//   final EdgeInsetsGeometry? padding;

//   // Text
//   final TextStyle? textStyle;

//   // Other
//   final double? elevation;
//   final Widget? child;

//   const AppButtonWidget({
//     super.key,
//     required this.text,
//     this.onPressed,

//     // Size
//     this.width,
//     this.height,

//     // Padding / Margin
//     this.top,
//     this.left,
//     this.right,
//     this.bottom,

//     // Colors
//     this.backgroundColor,
//     this.disabledBackgroundColor,
//     this.foregroundColor,

//     // Gradient
//     this.gradient,
//     this.useGradient = true,

//     // Border
//     this.borderRadius,
//     this.borderColor,
//     this.borderWidth,

//     // Button padding
//     this.padding,

//     // Text
//     this.textStyle,

//     // Other
//     this.elevation,
//     this.child,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final radius = BorderRadius.circular(
//       borderRadius ?? 6,
//     );

//     final bool isEnabled = onPressed != null;

//     return Padding(
//       padding: EdgeInsets.only(
//         top: top ?? 0,
//         left: left ?? 0,
//         right: right ?? 0,
//         bottom: bottom ?? 0,
//       ),
//       child: SizedBox(
//         width: width,
//         height: height,
//         child: DecoratedBox(
//           decoration: BoxDecoration(
//             gradient: isEnabled && useGradient
//                 ? (gradient ?? AppColors.primaryGradient)
//                 : null,
//             color: isEnabled
//                 ? (useGradient
//                     ? null
//                     : backgroundColor ?? AppColors.primaryGreen)
//                 : disabledBackgroundColor ?? Colors.grey,
//             borderRadius: radius,
//             border: Border.all(
//               color: borderColor ?? Colors.transparent,
//               width: borderWidth ?? 0,
//             ),
//           ),
//           child: ElevatedButton(
//             onPressed: onPressed,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.transparent,
//               disabledBackgroundColor: Colors.transparent,
//               foregroundColor: foregroundColor ?? AppColors.white,
//               shadowColor: Colors.transparent,
//               elevation: elevation ?? 0,
//               padding: padding ??
//                   const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 0,
//                   ),
//               shape: RoundedRectangleBorder(
//                 borderRadius: radius,
//                 side: BorderSide.none,
//               ),
//             ),
//             child: child ??
//                 Text(
//                   text,
//                   style: textStyle ?? AppTextStyles.small(context),
//                 ),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

import '../../responsiveness/responsive_repo.dart';

class AppButtonWidget extends StatelessWidget {
  final String text;

  final VoidCallback? onPressed;

  final double? width;
  final double? height;

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  final Color? backgroundColor;
  final Color? disabledBackgroundColor;
  final Color? foregroundColor;

  final Gradient? gradient;

  final double? borderRadius;
  final Color? borderColor;
  final double? borderWidth;

  final EdgeInsetsGeometry? padding;

  final TextStyle? textStyle;

  final double? elevation;
  final Widget? child;

  /// When false, hides the trailing circular arrow (e.g. Accept / Decline).
  final bool showTrailingArrow;

  const AppButtonWidget({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height,
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.foregroundColor,
    this.gradient,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.padding,
    this.textStyle,
    this.elevation,
    this.child,
    this.showTrailingArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    final double buttonHeight = height ?? responsive.h(7);

    // ============================================================
    // ⭐ OUTER BUTTON RADIUS
    // YAHAN SE CHANGE KARO
    // ============================================================
    final double radius = borderRadius ?? 0;

    final bool isEnabled = onPressed != null;

    return Padding(
      padding: EdgeInsets.only(
        top: top ?? 0,
        left: left ?? 0,
        right: right ?? 0,
        bottom: bottom ?? 0,
      ),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: width ?? double.infinity,
          height: buttonHeight,

          // ⭐ IMPORTANT
          // Container ke andar jo content hai usko bhi
          // rounded shape ke andar clip karega.
          clipBehavior: Clip.antiAlias,

          padding: padding ?? EdgeInsets.symmetric(horizontal: responsive.w(5)),

          decoration: BoxDecoration(
            color: isEnabled
                ? (backgroundColor ?? AppColors.primaryGreen)
                : (disabledBackgroundColor ?? Colors.grey),

            // ⭐ OUTER RADIUS
            borderRadius: BorderRadius.circular(radius),

            border: Border.all(
              color: borderColor ?? Colors.transparent,
              width: borderWidth ?? 0,
            ),
          ),

          child: Row(
            children: [
              Expanded(
                child:
                    child ??
                    Text(
                      text,
                      style:
                          textStyle ??
                          AppTextStyles.small(context).copyWith(
                            color: foregroundColor ?? AppColors.black,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
              ),
              if (showTrailingArrow)
                Container(
                  width: responsive.w(10),
                  height: responsive.w(10),
                  decoration: const BoxDecoration(
                    color: AppColors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: AppColors.dashboardWhite,
                    size: responsive.w(5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
