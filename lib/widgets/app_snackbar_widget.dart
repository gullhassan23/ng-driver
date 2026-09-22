import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utilis/app_colors.dart';

enum AppSnackbarType { success, error, info }

class AppSnackbar {
  AppSnackbar._();

  static void show({
    required String title,
    String message = '',
    AppSnackbarType type = AppSnackbarType.info,
    SnackPosition position = SnackPosition.TOP,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final Color backgroundColor;
    final Color colorText;

    switch (type) {
      case AppSnackbarType.success:
        backgroundColor = AppColors.primaryGreen;
        colorText = AppColors.black;
      case AppSnackbarType.error:
        backgroundColor = AppColors.secondaryRed;
        colorText = AppColors.white;
      case AppSnackbarType.info:
        backgroundColor = AppColors.inputBackground;
        colorText = AppColors.white;
    }

    Get.snackbar(
      title,
      message,
      backgroundColor: backgroundColor,
      colorText: colorText,
      snackPosition: position,
      duration: duration,
      mainButton: actionLabel != null && onAction != null
          ? TextButton(
              onPressed: onAction,
              child: Text(actionLabel, style: TextStyle(color: colorText)),
            )
          : null,
    );
  }

  static void success({
    required String title,
    String message = '',
    SnackPosition position = SnackPosition.BOTTOM,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      title: title,
      message: message,
      type: AppSnackbarType.success,
      position: position,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void error({
    required String title,
    String message = '',
    SnackPosition position = SnackPosition.BOTTOM,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      title: title,
      message: message,
      type: AppSnackbarType.error,
      position: position,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void info({
    required String title,
    String message = '',
    SnackPosition position = SnackPosition.BOTTOM,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      title: title,
      message: message,
      type: AppSnackbarType.info,
      position: position,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
