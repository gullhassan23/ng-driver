import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/waiting_approval_controller.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text.dart';
import '../../utilis/app_text_styles.dart';
import '../../widgets/buttons/app_button_widget.dart';
import '../../widgets/app_image_widget.dart';
import '../../widgets/app_text_widget.dart';

class WaitingApprovalView extends GetView<WaitingApprovalController> {
  const WaitingApprovalView({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: responsive.w(8)),
          child: Column(
            children: [
              AppImageWidget(
                asset: 'assets/images/Appmain.webp',
                height: responsive.h(8),
                top: responsive.h(1),
                left: responsive.w(5),
              ),
              AppTextWidget(
                text: AppText.waitingForApproval,
                textAlign: TextAlign.center,
                style: AppTextStyles.large(
                  context,
                ).copyWith(color: AppColors.white),
                top: responsive.h(4),
              ),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    );
                  }

                  final error = controller.errorMessage.value;

                  if (error != null) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppTextWidget(
                          text: error,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.small(
                            context,
                          ).copyWith(color: AppColors.white),
                        ),
                        AppButtonWidget(
                          text: AppText.retry,
                          width: double.infinity,
                          height: responsive.h(6),
                          top: responsive.h(3),
                          onPressed: controller.listenForApproval,
                        ),
                      ],
                    );
                  }

                  return Center(
                    child: AppTextWidget(
                      text: AppText.waitingForApprovalMessage,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.small(
                        context,
                      ).copyWith(color: AppColors.white, height: 1.4),
                    ),
                  );
                }),
              ),
              AppButtonWidget(
                text: AppText.signOut,
                width: double.infinity,
                height: responsive.h(6),
                bottom: responsive.h(4),
                borderRadius: responsive.w(8),
                backgroundColor: AppColors.primaryGreen,
                gradient: AppColors.secondaryGradient,
                onPressed: controller.signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
