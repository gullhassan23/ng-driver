import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/connectivity_controller.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text_styles.dart';
import '../buttons/app_button_widget.dart';

/// Compact offline strip for Active Ride (does not block CTAs).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ConnectivityController>();
    return Material(
      color: AppColors.primaryRed.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No internet — ride controls may be delayed.',
                style: TextStyle(color: AppColors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: controller.retry,
              child: const Text(
                'Retry',
                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen overlay shown when the device has no internet.
/// Mounted via [GetMaterialApp.builder] — does not push a route.
class NoInternetOverlay extends StatelessWidget {
  const NoInternetOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
    final controller = Get.find<ConnectivityController>();

    return Material(
      color: AppColors.dashboardBackground,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: responsive.w(8)),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: responsive.w(28),
                height: responsive.w(28),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: responsive.w(14),
                  color: AppColors.primaryGreen,
                ),
              ),
              SizedBox(height: responsive.h(3.5)),
              Text(
                'No Internet Connection',
                textAlign: TextAlign.center,
                style: AppTextStyles.medium(context).copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: responsive.h(2.6),
                ),
              ),
              SizedBox(height: responsive.h(1.5)),
              Text(
                'Please check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: AppTextStyles.small(context).copyWith(
                  color: AppColors.white.withValues(alpha: 0.72),
                  height: 1.4,
                ),
              ),
              SizedBox(height: responsive.h(4)),
              Obx(
                () => AppButtonWidget(
                  text: controller.isRetrying.value ? 'Checking...' : 'Retry',
                  onPressed: controller.isRetrying.value
                      ? null
                      : controller.retry,
                  width: double.infinity,
                  height: responsive.h(6),
                  backgroundColor: AppColors.dashboardAccent,
                  disabledBackgroundColor: AppColors.dashboardAccent
                      .withValues(alpha: 0.55),
                  foregroundColor: AppColors.black,
                  borderRadius: responsive.w(3),
                  showTrailingArrow: false,
                  child: Center(
                    child: Text(
                      controller.isRetrying.value ? 'Checking...' : 'Retry',
                      style: AppTextStyles.small(context).copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
