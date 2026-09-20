import 'package:flutter/material.dart';

import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text_styles.dart';

class AppDropdownWidget<T> extends StatelessWidget {
  // Value & Items
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;

  // Hint
  final String? hintText;

  // Size
  final double? width;
  final double? height;

  // Padding / Margin
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  // Colors
  final Color? fillColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? iconColor;
  final Color? disabledColor;
  final Color? dropdownColor;

  // Border
  final double? borderRadius;
  final Color? borderColor;
  final double? borderWidth;
  final Color? focusedBorderColor;
  final double? focusedBorderWidth;

  // Content
  final EdgeInsetsGeometry? contentPadding;

  // Dropdown
  final Widget? icon;
  final bool? isExpanded;
  final bool? enabled;
  final bool? autofocus;
  final double? menuMaxHeight;
  final BorderRadius? menuBorderRadius;

  // Form
  final AutovalidateMode? autovalidateMode;

  const AppDropdownWidget({
    super.key,

    // Value & Items
    this.value,
    this.items,
    this.onChanged,
    this.validator,

    // Hint
    this.hintText,

    // Size
    this.width,
    this.height,

    // Padding / Margin
    this.top,
    this.left,
    this.right,
    this.bottom,

    // Colors
    this.fillColor,
    this.textColor,
    this.hintColor,
    this.iconColor,
    this.disabledColor,
    this.dropdownColor,

    // Border
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.focusedBorderColor,
    this.focusedBorderWidth,

    // Content
    this.contentPadding,

    // Dropdown
    this.icon,
    this.isExpanded,
    this.enabled,
    this.autofocus,
    this.menuMaxHeight,
    this.menuBorderRadius,

    // Form
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
    final double radiusValue = borderRadius ?? responsive.w(8);

    final BorderRadius radius = BorderRadius.circular(
      radiusValue,
    );

    final bool isEnabled = enabled ?? true;

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
        child: ClipRRect(
          borderRadius: radius,
          child: DropdownButtonFormField<T>(
          initialValue: value,

          // Items
          items: items,

          // Action
          onChanged: isEnabled ? onChanged : null,

          // Validation
          validator: validator,
          autovalidateMode: autovalidateMode,

          // State
          autofocus: autofocus ?? false,

          // Hint
          hint: hintText != null
              ? Text(
            hintText!,
            style: AppTextStyles.small(context).copyWith(
              color: isEnabled
                  ? hintColor ?? Colors.white54
                  : disabledColor ?? Colors.white38,
            ),
          )
              : null,

          // Dropdown
          isExpanded: isExpanded ?? true,

          menuMaxHeight: menuMaxHeight,

          dropdownColor:
          dropdownColor ??
              fillColor ??
              const Color(0xFF2B2B2B),

          borderRadius: menuBorderRadius ?? radius,

          // Icon
          icon: icon ??
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isEnabled
                    ? iconColor ?? AppColors.primaryGreen
                    : disabledColor ?? Colors.white38,
              ),

          // Selected Text
          style: AppTextStyles.small(context).copyWith(
            color: isEnabled
                ? textColor ?? AppColors.white
                : disabledColor ?? Colors.white38,
          ),

          // Decoration
          decoration: InputDecoration(
            enabled: isEnabled,

            filled: true,

            fillColor: isEnabled
                ? fillColor ?? const Color(0xFF2B2B2B)
                : disabledColor ?? const Color(0xFF222222),

            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),

            // Normal Border
            border: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: borderColor ?? Colors.transparent,
                width: borderWidth ?? 0,
              ),
            ),

            // Enabled Border
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: borderColor ?? Colors.transparent,
                width: borderWidth ?? 0,
              ),
            ),

            // Focused Border
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: focusedBorderColor ??
                    borderColor ??
                    Colors.transparent,
                width: focusedBorderWidth ??
                    borderWidth ??
                    0,
              ),
            ),

            // Disabled Border
            disabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: borderColor ?? Colors.transparent,
                width: borderWidth ?? 0,
              ),
            ),

            // Error Border
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(
                color: AppColors.secondaryRed,
              ),
            ),

            // Focused Error Border
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(
                color: AppColors.secondaryRed,
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}