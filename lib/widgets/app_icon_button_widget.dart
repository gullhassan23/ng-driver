import 'package:flutter/material.dart';

class AppIconButtonWidget extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  final double? width;
  final double? height;

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  final Color? backgroundColor;
  final Color? iconColor;

  final double? iconSize;
  final double? borderRadius;

  final EdgeInsetsGeometry? padding;

  const AppIconButtonWidget({
    super.key,
    required this.icon,
    this.onPressed,
    this.width,
    this.height,
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
    this.borderRadius,
    this.padding,
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
      child: SizedBox(
        width: width,
        height: height,
        child: IconButton(
          onPressed: onPressed,
          padding: padding ?? EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(
            width: width,
            height: height,
          ),
          style: IconButton.styleFrom(
            backgroundColor: backgroundColor,
            padding: EdgeInsets.zero,
            minimumSize: Size(width ?? 0, height ?? 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            alignment: Alignment.center,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? 6,
              ),
            ),
          ),
          icon: Icon(
            icon,
            color: iconColor,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}