import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

import '../responsiveness/responsive_repo.dart';

class AppTextFieldWidget extends StatelessWidget {
  final String hintText;

  final TextEditingController? controller;
  final TextInputType keyboardType;

  final double? width;
  final double? height;

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  final Color? fillColor;
  final Color? hintColor;
  final Color? textColor;

  // Change radius from here
  final double? borderRadius;

  final EdgeInsetsGeometry? contentPadding;

  final bool? obscureText;
  final bool? enabled;
  final bool? readOnly;

  final Widget? prefixIcon;
  final Widget? suffixIcon;

  final int? maxLines;
  final int? maxLength;

  final TextInputAction? textInputAction;

  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  const AppTextFieldWidget({
    super.key,
    required this.hintText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.width,
    this.height,
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.fillColor,
    this.hintColor,
    this.textColor,
    this.borderRadius,
    this.contentPadding,
    this.obscureText,
    this.enabled,
    this.readOnly,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines,
    this.maxLength,
    this.textInputAction,
    this.onChanged,
    this.onTap,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    // Default radius
    // Is value ko change karne se har border ka radius change hoga.
    final radius = borderRadius ?? responsive.w(8);

    return Padding(
      padding: EdgeInsets.only(
        top: top ?? 0,
        left: left ?? 0,
        right: right ?? 0,
        bottom: bottom ?? 0,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText ?? false,
          enabled: enabled ?? true,
          readOnly: readOnly ?? false,
          maxLines: obscureText == true ? 1 : maxLines,
          maxLength: maxLength,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onTap: onTap,
          scrollPadding: const EdgeInsets.only(
            left: 20,
            top: 20,
            right: 20,
            bottom: 80,
          ),

          style: AppTextStyles.small(
            context,
          ).copyWith(color: textColor ?? AppColors.white),

          decoration: InputDecoration(
            hintText: hintText,

            hintStyle: AppTextStyles.small(
              context,
            ).copyWith(color: hintColor ?? Colors.white54),

            filled: true,

            fillColor: fillColor ?? const Color(0xFF2B2B2B),

            contentPadding:
                contentPadding ??
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),

            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,

            // Normal border
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),

            // Enabled border
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),

            // Focused border
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),

            // Disabled border
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
