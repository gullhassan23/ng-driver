import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

const Color _kBlurBarrierColor = Color(0x59000000);

Widget _wrapWithBlur(Widget child) {
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Center(child: child),
    ),
  );
}

Future<T?> showAppBlurDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: _kBlurBarrierColor,
    builder: (ctx) => _wrapWithBlur(builder(ctx)),
  );
}

Future<T?> showAppBlurGetDialog<T>(
  Widget dialog, {
  bool barrierDismissible = true,
}) {
  return Get.dialog<T>(
    _wrapWithBlur(dialog),
    barrierDismissible: barrierDismissible,
    barrierColor: _kBlurBarrierColor,
  );
}
