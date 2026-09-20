import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../widgets/app_image_widget.dart';

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
    final responsive = ResponsiveRepo(context);

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppImageWidget(
                asset: 'assets/images/Appmain.webp',
                height: responsive.h(10),
              ),
              SizedBox(height: responsive.h(4)),
              const CircularProgressIndicator(
                color: AppColors.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
