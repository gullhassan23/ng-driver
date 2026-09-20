import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';

import '../responsiveness/responsive_repo.dart';


class AuthRichTextWidget extends StatelessWidget {
  /// Normal text
  final String? normalText;

  /// Highlighted / clickable text
  final String? highlightedText;

  /// Normal text color
  final Color? normalTextColor;

  /// Highlighted text color
  final Color? highlightedTextColor;

  /// Highlighted text gradient. When set, this is used instead of [highlightedTextColor].
  final Gradient? highlightedGradient;

  /// Normal text font size as responsive height percentage
  final double? normalFontSize;

  /// Highlighted text font size as responsive height percentage
  final double? highlightedFontSize;

  /// Normal text font weight
  final FontWeight? normalFontWeight;

  /// Highlighted text font weight
  final FontWeight? highlightedFontWeight;

  /// Space between normal and highlighted text
  final double? spacing;

  /// Text alignment
  final TextAlign? textAlign;

  /// Maximum number of lines
  final int? maxLines;

  /// Overflow behavior
  final TextOverflow? overflow;

  /// Callback when highlighted text is tapped
  final VoidCallback? onHighlightedTap;

  /// Optional padding
  final EdgeInsetsGeometry? padding;

  const AuthRichTextWidget({
    super.key,
    this.normalText,
    this.highlightedText,
    this.normalTextColor,
    this.highlightedTextColor,
    this.highlightedGradient,
    this.normalFontSize,
    this.highlightedFontSize,
    this.normalFontWeight,
    this.highlightedFontWeight,
    this.spacing,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.onHighlightedTap,
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

    final highlightedStyle = TextStyle(
      color: highlightedTextColor ?? AppColors.orange,
      fontSize: responsive.h(highlightedFontSize ?? 1.7),
      fontWeight: highlightedFontWeight ?? FontWeight.w500,
    );

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: RichText(
        textAlign: textAlign ?? TextAlign.center,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.visible,
        text: TextSpan(
          children: [
            if (normalText != null && normalText!.isNotEmpty)
              TextSpan(text: normalText, style: normalStyle),

            if (normalText != null &&
                normalText!.isNotEmpty &&
                highlightedText != null &&
                highlightedText!.isNotEmpty)
              TextSpan(
                text: ' ' * (spacing == null ? 1 : 0),
                style: normalStyle,
              ),

            if (highlightedText != null && highlightedText!.isNotEmpty)
              highlightedGradient != null
                  ? WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: onHighlightedTap,
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) =>
                              highlightedGradient!.createShader(bounds),
                          child: Text(
                            highlightedText!,
                            style: highlightedStyle.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : TextSpan(
                      text: highlightedText,
                      style: highlightedStyle,
                      recognizer: onHighlightedTap != null
                          ? (TapGestureRecognizer()..onTap = onHighlightedTap)
                          : null,
                    ),
          ],
        ),
      ),
    );
  }
}
