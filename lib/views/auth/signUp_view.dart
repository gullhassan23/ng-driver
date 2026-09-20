import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/routes/app_routes.dart';
import 'package:ngtowncardriver/widgets/app_icon_button_widget.dart';
import 'package:ngtowncardriver/widgets/app_text_widget.dart';
import 'package:ngtowncardriver/widgets/auth_text.dart';

import '../../controllers/auth_controller.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text.dart';
import '../../utilis/app_text_styles.dart';
import '../../widgets/buttons/app_button_widget.dart';

import '../../widgets/app_image_widget.dart';

import '../../widgets/app_text_field_widget.dart';
import '../../widgets/phone_text_field_widget.dart';

class SignupView extends GetView<AuthController> {
  const SignupView({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: responsive.h(3)),
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
                height: responsive.h(10),
                top: responsive.h(5),
                left: responsive.w(7),
              ),
              AppTextWidget(
                text: AppText.welcomeBack,
                style: AppTextStyles.large(context),
                gradient: AppColors.gradientOrange,

                left: responsive.w(8),
              ),
              AppTextWidget(
                text: AppText.signupGetStarted,
                style: AppTextStyles.large(
                  context,
                ).copyWith(color: AppColors.white),
                left: responsive.w(8),
              ),
              Row(
                children: [
                  Expanded(
                    child: AppTextFieldWidget(
                      hintText: AppText.firstName,
                      controller: controller.firstName,
                      top: responsive.h(3),
                      left: responsive.w(5),
                      right: responsive.w(1),
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  Expanded(
                    child: AppTextFieldWidget(
                      hintText: AppText.lastName,
                      controller: controller.lastName,
                      top: responsive.h(3),
                      left: responsive.w(1),
                      right: responsive.w(5),
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),

              AppTextFieldWidget(
                hintText: AppText.email,
                controller: controller.signUpEmail,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                top: responsive.h(1),
                left: responsive.w(5),
                right: responsive.w(5),
              ),

              PhoneTextFieldWidget(
                controller: controller.phone,
                textInputAction: TextInputAction.next,
                top: responsive.h(1),
                left: responsive.w(5),
                right: responsive.w(5),
              ),

              Obx(
                () => AppTextFieldWidget(
                  hintText: AppText.password,
                  controller: controller.signUpPassword,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: controller.obscureSignUpPassword.value,
                  textInputAction: TextInputAction.next,
                  top: responsive.h(1),
                  left: responsive.w(5),
                  right: responsive.w(5),
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.obscureSignUpPassword.value
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      controller.obscureSignUpPassword.toggle();
                    },
                  ),
                ),
              ),

              Obx(
                () => AppTextFieldWidget(
                  hintText: AppText.confirmPassword,
                  controller: controller.confirmPassword,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: controller.obscureConfirmPassword.value,
                  textInputAction: TextInputAction.done,
                  top: responsive.h(1),
                  left: responsive.w(5),
                  right: responsive.w(5),
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.obscureConfirmPassword.value
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      controller.obscureConfirmPassword.toggle();
                    },
                  ),
                ),
              ),

              Obx(
                () => AppButtonWidget(
                  text: controller.isLoading.value
                      ? 'Creating account...'
                      : AppText.signUp,
                  width: double.infinity,
                  height: responsive.h(6),
                  top: responsive.h(4),
                  left: responsive.w(5),
                  right: responsive.w(5),
                  backgroundColor: AppColors.primaryGreen,
                  borderRadius: responsive.w(8),
                  textStyle: AppTextStyles.small(
                    context,
                  ).copyWith(color: AppColors.black),
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.signUp,
                ),
              ),
              AuthText(
                title: "Already have an account? ",
                text: "Sign In",
                onTap: () {
                  Get.toNamed(AppRoutes.signIn);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
