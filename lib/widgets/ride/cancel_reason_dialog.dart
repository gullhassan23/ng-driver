import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utilis/app_colors.dart';
import '../app_blur_dialog.dart';
import '../app_snackbar_widget.dart';

/// Collects a required free-text cancellation reason from the driver.
///
/// Returns the trimmed reason via [showAppBlurGetDialog], or `null` if dismissed.
class CancelReasonDialog extends StatefulWidget {
  const CancelReasonDialog({
    super.key,
    this.title = 'Why do you want to cancel?',
  });

  final String title;

  /// Shows the dialog and returns a non-empty trimmed reason, or `null`.
  static Future<String?> show({
    String title = 'Why do you want to cancel?',
  }) {
    return showAppBlurGetDialog<String>(
      CancelReasonDialog(title: title),
      barrierDismissible: true,
    );
  }

  @override
  State<CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<CancelReasonDialog> {
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _reasonController.text.trim();
    if (text.isEmpty) {
      AppSnackbar.show(
        title: 'Reason required',
        message: 'Please enter a reason to cancel.',
        type: AppSnackbarType.info,
      );
      return;
    }
    Get.back(result: text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: AppColors.inputBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: TextField(
        controller: _reasonController,
        autofocus: true,
        maxLines: 4,
        minLines: 3,
        style: const TextStyle(color: AppColors.white),
        cursorColor: AppColors.primaryRed,
        decoration: InputDecoration(
          hintText: 'Write your reason…',
          hintStyle: TextStyle(color: AppColors.white.withValues(alpha: 0.5)),
          filled: true,
          fillColor: const Color(0xFF1C1C1C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryRed),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            'Back',
            style: TextStyle(color: AppColors.white.withValues(alpha: 0.6)),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text(
            'Continue',
            style: TextStyle(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
