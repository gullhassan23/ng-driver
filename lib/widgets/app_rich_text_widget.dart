import 'package:flutter/material.dart';

class AppRichTextWidget extends StatelessWidget {
  final List<InlineSpan> children;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const AppRichTextWidget({
    super.key,
    required this.children,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
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
      child: RichText(
        textAlign: textAlign ?? TextAlign.start,
        textDirection: textDirection,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.clip,
        text: TextSpan(
          children: children,
        ),
      ),
    );
  }
}