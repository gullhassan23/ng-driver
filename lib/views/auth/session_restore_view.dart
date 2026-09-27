import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../utilis/app_colors.dart';

/// Shown only while Firebase session + driver profile are restored.
/// Prevents Sign In from painting before a logged-in driver is routed.
class SessionRestoreView extends StatefulWidget {
  const SessionRestoreView({super.key});

  @override
  State<SessionRestoreView> createState() => _SessionRestoreViewState();
}

class _SessionRestoreViewState extends State<SessionRestoreView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<AuthController>()) return;
      final auth = Get.find<AuthController>();
      auth.markColdStartFromSessionRestore();
      auth.bootstrapColdStart();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }
}
