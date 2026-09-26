import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/widgets/auth_text.dart';

import '../../controllers/auth_controller.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../routes/app_routes.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text.dart';
import '../../utilis/app_text_styles.dart';
import '../../widgets/app_blur_dialog.dart';
import '../../widgets/buttons/app_button_widget.dart';
import '../../widgets/app_image_widget.dart';

import '../../widgets/app_icon_button_widget.dart';
import '../../widgets/app_text_field_widget.dart';
import '../../widgets/app_text_widget.dart';

class ForgotView extends GetView<AuthController> {
  const ForgotView({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconButtonWidget(
                icon: Icons.arrow_back,
                onPressed: () => Get.back(),
                backgroundColor: AppColors.primaryGreen,
                iconColor: AppColors.black,
                width: responsive.w(10),
                height: responsive.h(5),
                top: responsive.h(2),
                left: responsive.w(4),
                borderRadius: responsive.w(3),
              ),

              AppImageWidget(
                asset: 'assets/images/Appmain.webp',
                height: responsive.h(8),
                top: responsive.h(5),
                left: responsive.w(7),
              ),

              AppTextWidget(
                text: AppText.forgotPassword,
                style: AppTextStyles.large(context),
                gradient: AppColors.gradientOrange,
                top: responsive.h(2),
                left: responsive.w(8),
              ),

              AppTextWidget(
                text: '\n${AppText.enterEmailToReset}',
                style: AppTextStyles.large(
                  context,
                ).copyWith(color: AppColors.white),
                top: responsive.h(1),
                left: responsive.w(8),
              ),
              AppTextWidget(
                text: AppText.forgotPasswordSubtitle,

                style: AppTextStyles.small(
                  context,
                ).copyWith(color: AppColors.white.withOpacity(0.8)),
                top: responsive.h(1),
                left: responsive.w(8),
              ),

              AppTextFieldWidget(
                hintText: AppText.email,
                controller: controller.signInEmail,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                top: responsive.h(4),
                left: responsive.w(8),
                right: responsive.w(8),
              ),

              Obx(
                () => AppButtonWidget(
                  text: controller.isLoading.value
                      ? 'Sending...'
                      : AppText.resetPassword,
                  width: double.infinity,
                  height: responsive.h(6),
                  top: responsive.h(3),
                  left: responsive.w(8),
                  right: responsive.w(8),
                  borderRadius: responsive.w(8),
                  textStyle: AppTextStyles.small(
                    context,
                  ).copyWith(color: AppColors.black),
                  onPressed: controller.isLoading.value
                      ? null
                      : () async {
                          final sent = await controller.sendPasswordReset();
                          if (sent && context.mounted) {
                            _showResetSuccessDialog(context);
                          }
                        },
                ),
              ),

              AuthText(
                title: "Back to Sign in?",
                text: "Sign In",
                onTap: () {
                  Get.toNamed(AppRoutes.signIn);
                },
              ),

              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetSuccessDialog(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    showAppBlurDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.inputBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppTextWidget(
            text: AppText.success,
            style: AppTextStyles.medium(
              context,
            ).copyWith(color: AppColors.primaryGreen),
            textAlign: TextAlign.center,
          ),
          content: AppTextWidget(
            text: AppText.resetLinkSent,
            style: AppTextStyles.small(
              context,
            ).copyWith(color: AppColors.white),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: AppButtonWidget(
                text: AppText.ok,
                width: responsive.w(40),
                height: responsive.h(5),
                borderRadius: 12,
                textStyle: AppTextStyles.small(
                  context,
                ).copyWith(color: AppColors.white),
                onPressed: () {
                  Get.back();
                  Get.offAllNamed(AppRoutes.signIn);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
