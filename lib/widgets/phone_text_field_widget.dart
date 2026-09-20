import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../responsiveness/responsive_repo.dart';
import '../utilis/app_colors.dart';
import '../utilis/app_text_styles.dart';

/// Formats US phone input as `(555) 123-4567` while typing.
class UsPhoneNumberFormatter extends TextInputFormatter {
  const UsPhoneNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
    final formatted = format(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Formats up to 10 digits as `(555) 123-4567`.
  static String format(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Returns 10-digit US phone digits, or empty if invalid.
  static String digitsOf(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('1')) {
      digits = digits.substring(1);
    }
    return digits.length == 10 ? digits : '';
  }
}

class PhoneTextFieldWidget extends StatelessWidget {
  final TextEditingController controller;

  final double? width;
  final double? height;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double? borderRadius;
  final TextInputAction? textInputAction;

  const PhoneTextFieldWidget({
    super.key,
    required this.controller,
    this.width,
    this.height,
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.borderRadius,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
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
          keyboardType: TextInputType.phone,
          textInputAction: textInputAction,
          inputFormatters: const [UsPhoneNumberFormatter()],
          scrollPadding: const EdgeInsets.only(
            left: 20,
            top: 20,
            right: 20,
            bottom: 80,
          ),
          style: AppTextStyles.small(context).copyWith(color: AppColors.white),
          decoration: InputDecoration(
            hintText: '(555) 123-4567',
            hintStyle: AppTextStyles.small(
              context,
            ).copyWith(color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF2B2B2B),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 0,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    '+1',
                    style: AppTextStyles.small(
                      context,
                    ).copyWith(color: AppColors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  const SizedBox(
                    height: 24,
                    child: VerticalDivider(
                      thickness: 1,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
