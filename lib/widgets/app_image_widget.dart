import 'package:flutter/material.dart';

class AppImageWidget extends StatelessWidget {
  final String asset;

  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment? alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality? filterQuality;
  final bool? isAntiAlias;
  final String? semanticLabel;
  final bool? excludeFromSemantics;
  final double? scale;

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  final Widget Function(BuildContext, Widget, int?, bool)? frameBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const AppImageWidget({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.fit,
    this.alignment,
    this.color,
    this.colorBlendMode,
    this.filterQuality,
    this.isAntiAlias,
    this.semanticLabel,
    this.excludeFromSemantics,
    this.scale,
    this.frameBuilder,
    this.errorBuilder,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: top ?? 0,
        left: left ?? 0,
        right: right ?? 0,
        bottom: bottom ?? 0,
      ),
      child: Image.asset(
        asset,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment ?? Alignment.center,
        color: color,
        colorBlendMode: colorBlendMode,
        filterQuality: filterQuality ?? FilterQuality.medium,
        isAntiAlias: isAntiAlias ?? false,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics ?? false,
        scale: scale ?? 1.0,
        frameBuilder: frameBuilder,
        errorBuilder: errorBuilder,
      ),
    );
  }
}