import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';

import '../responsiveness/responsive_repo.dart';


class AuthTermsRichTextWidget extends StatelessWidget {
  /// First normal text
  final String? normalText;

  /// Text before first highlighted text
  final String? prefixText;

  /// First highlighted / clickable text
  final String? firstHighlightedText;

  /// Text between first and second highlighted text
  final String? middleText;

  /// Second highlighted / clickable text
  final String? secondHighlightedText;

  /// Normal text color
  final Color? normalTextColor;

  /// First highlighted text color
  final Color? firstHighlightedTextColor;

  /// Second highlighted text color
  final Color? secondHighlightedTextColor;

  /// Normal text font size as responsive height percentage
  final double? normalFontSize;

  /// First highlighted text font size
  final double? firstHighlightedFontSize;

  /// Second highlighted text font size
  final double? secondHighlightedFontSize;

  /// Normal text font weight
  final FontWeight? normalFontWeight;

  /// First highlighted text font weight
  final FontWeight? firstHighlightedFontWeight;

  /// Second highlighted text font weight
  final FontWeight? secondHighlightedFontWeight;

  /// Text alignment
  final TextAlign? textAlign;

  /// Maximum number of lines
  final int? maxLines;

  /// Overflow behavior
  final TextOverflow? overflow;

  /// Callback for first highlighted text
  final VoidCallback? onFirstHighlightedTap;

  /// Callback for second highlighted text
  final VoidCallback? onSecondHighlightedTap;

  /// Optional padding
  final EdgeInsetsGeometry? padding;

  const AuthTermsRichTextWidget({
    super.key,
    this.normalText,
    this.prefixText,
    this.firstHighlightedText,
    this.middleText,
    this.secondHighlightedText,
    this.normalTextColor,
    this.firstHighlightedTextColor,
    this.secondHighlightedTextColor,
    this.normalFontSize,
    this.firstHighlightedFontSize,
    this.secondHighlightedFontSize,
    this.normalFontWeight,
    this.firstHighlightedFontWeight,
    this.secondHighlightedFontWeight,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.onFirstHighlightedTap,
    this.onSecondHighlightedTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    final normalStyle = TextStyle(
      color: normalTextColor ?? const Color(0xFFB8B8B8),
      fontSize: responsive.h(normalFontSize ?? 1.7),
      fontWeight: normalFontWeight ?? FontWeight.w400,
    );

    final firstHighlightedStyle = TextStyle(
      color: firstHighlightedTextColor ?? AppColors.orange,
      fontSize: responsive.h(firstHighlightedFontSize ?? 1.7),
      fontWeight: firstHighlightedFontWeight ?? FontWeight.w500,
    );

    final secondHighlightedStyle = TextStyle(
      color: secondHighlightedTextColor ?? AppColors.orange,
      fontSize: responsive.h(secondHighlightedFontSize ?? 1.7),
      fontWeight: secondHighlightedFontWeight ?? FontWeight.w500,
    );

    return Padding(
      padding: padding ?? EdgeInsets.zero,

      // ============================================================
      // FULL WIDTH
      // Iski wajah se TextAlign.center properly kaam karega.
      // ============================================================
      child: SizedBox(
        width: double.infinity,

        child: RichText(
          textAlign: textAlign ?? TextAlign.center,
          maxLines: maxLines,
          overflow: overflow ?? TextOverflow.visible,

          text: TextSpan(
            children: [
              // ======================================================
              // NORMAL TEXT
              // ======================================================
              if (normalText != null && normalText!.isNotEmpty)
                TextSpan(text: normalText, style: normalStyle),

              // ======================================================
              // PREFIX NORMAL TEXT
              // ======================================================
              if (prefixText != null && prefixText!.isNotEmpty)
                TextSpan(text: prefixText, style: normalStyle),

              // ======================================================
              // FIRST HIGHLIGHTED TEXT
              // ======================================================
              if (firstHighlightedText != null &&
                  firstHighlightedText!.isNotEmpty)
                TextSpan(
                  text: firstHighlightedText,
                  style: firstHighlightedStyle,
                  recognizer: onFirstHighlightedTap != null
                      ? (TapGestureRecognizer()..onTap = onFirstHighlightedTap)
                      : null,
                ),

              // ======================================================
              // MIDDLE TEXT
              // ======================================================
              if (middleText != null && middleText!.isNotEmpty)
                TextSpan(text: middleText, style: normalStyle),

              // ======================================================
              // SECOND HIGHLIGHTED TEXT
              // ======================================================
              if (secondHighlightedText != null &&
                  secondHighlightedText!.isNotEmpty)
                TextSpan(
                  text: secondHighlightedText,
                  style: secondHighlightedStyle,
                  recognizer: onSecondHighlightedTap != null
                      ? (TapGestureRecognizer()..onTap = onSecondHighlightedTap)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
