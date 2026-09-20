import 'package:flutter/material.dart';

class AppTextWidget extends StatelessWidget {
  // Text
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final double? textScaleFactor;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final StrutStyle? strutStyle;

  // Gradient
  final Gradient? gradient;

  // Padding
  final double? all;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  // Action
  final VoidCallback? onTap;

  const AppTextWidget({
    super.key,
    required this.text,

    // Text properties
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.strutStyle,

    // Gradient
    this.gradient,

    // Padding
    this.all,
    this.top,
    this.left,
    this.right,
    this.bottom,

    // Action
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      style: gradient != null
          ? (style ?? const TextStyle()).copyWith(color: Colors.white)
          : style,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaleFactor != null
          ? TextScaler.linear(textScaleFactor!)
          : null,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      strutStyle: strutStyle,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: top ?? all ?? 0,
        left: left ?? all ?? 0,
        right: right ?? all ?? 0,
        bottom: bottom ?? all ?? 0,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: gradient != null
            ? ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    gradient!.createShader(bounds),
                child: textWidget,
              )
            : textWidget,
      ),
    );
  }
}
