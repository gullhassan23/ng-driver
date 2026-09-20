import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/widgets/app_text_widget.dart';
import 'package:ngtowncardriver/widgets/privacy_content.dart';
import '../../controllers/signup_controller.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text.dart';
import '../../utilis/app_text_styles.dart';
import '../../widgets/buttons/app_button_widget.dart';
import '../../widgets/auth/app_dropdown_widget.dart';
import '../../widgets/app_image_widget.dart';
import '../../widgets/app_progress_indicator_widget.dart';
import '../../widgets/app_text_field_widget.dart';
import '../../widgets/cnic_number_formatter.dart';

class DriverRegistration extends GetView<SignupController> {
  const DriverRegistration({super.key});

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
              AppImageWidget(
                asset: 'assets/images/Appmain.webp',
                height: responsive.h(10),
                top: responsive.h(5),
                left: responsive.w(7),
              ),

              AppTextWidget(
                text: AppText.driverDetail,
                style: AppTextStyles.large(context),
                gradient: AppColors.gradientOrange,

                left: responsive.w(8),
              ),
              AppTextWidget(
                text: AppText.entervehicleinfo,
                style: AppTextStyles.large(
                  context,
                ).copyWith(color: AppColors.white),

                left: responsive.w(8),
              ),

              AppTextFieldWidget(
                hintText: 'CNIC / National ID',
                controller: controller.cnic,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: const [CnicNumberFormatter()],
                height: responsive.h(5.5),
                top: responsive.h(3),
                left: responsive.w(7),
                right: responsive.w(7),
              ),

              // ==========================================
              // DRIVING LICENSE NUMBER
              // ==========================================
              AppTextFieldWidget(
                hintText: 'Driving License Number',
                controller: controller.licenseNumber,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                height: responsive.h(5.5),
                top: responsive.h(1),
                left: responsive.w(7),
                right: responsive.w(7),
              ),

              // ==========================================
              // VEHICLE TYPE
              // ==========================================
              Obx(
                () => AppDropdownWidget<String>(
                  value: controller.selectedVehicleType.value,
                  hintText: 'Vehicle Type',
                  height: responsive.h(5.5),
                  top: responsive.h(1),
                  left: responsive.w(7),
                  right: responsive.w(7),
                  hintColor: AppColors.primaryGreen,
                  iconColor: AppColors.primaryGreen,
                  onChanged: controller.setVehicleType,
                  items: SignupController.vehicleTypes
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                ),
              ),

              // ==========================================
              // VEHICLE MAKE
              // ==========================================
              AppTextFieldWidget(
                hintText: 'Vehicle Make',
                controller: controller.vehicleMake,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                height: responsive.h(5.5),
                top: responsive.h(1),
                left: responsive.w(7),
                right: responsive.w(7),
              ),

              // ==========================================
              // VEHICLE MODEL
              // ==========================================
              AppTextFieldWidget(
                hintText: 'Vehicle Model',
                controller: controller.vehicleModel,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                height: responsive.h(5.5),
                top: responsive.h(1),
                left: responsive.w(7),
                right: responsive.w(7),
              ),

              // ==========================================
              // VEHICLE COLOR
              // ==========================================
              AppTextFieldWidget(
                hintText: 'Vehicle Color',
                controller: controller.vehicleColor,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                height: responsive.h(5.5),
                top: responsive.h(1),
                left: responsive.w(7),
                right: responsive.w(7),
              ),

              // ==========================================
              // VEHICLE REGISTRATION NUMBER
              // ==========================================
              AppTextFieldWidget(
                hintText: 'Vehicle Identification Number',
                controller: controller.vehicleRegistration,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                height: responsive.h(5.5),
                top: responsive.h(1),
                left: responsive.w(7),
                right: responsive.w(7),
              ),

              // ==========================================
              // PROGRESS INDICATOR
              // ==========================================
              AppProgressIndicatorWidget(
                currentStep: 2,
                totalSteps: 2,
                top: responsive.h(2),
                left: responsive.w(14),
                right: responsive.w(14),
              ),

              // ==========================================
              // START BUTTON
              // ==========================================
              Obx(
                () => AppButtonWidget(
                  text: controller.isLoading.value
                      ? 'Saving...'
                      : AppText.submit,
                  width: double.infinity,
                  height: responsive.h(6),
                  top: responsive.h(3),
                  left: responsive.w(7),
                  right: responsive.w(7),
                  backgroundColor: AppColors.primaryGreen,
                  borderRadius: responsive.w(8),
                  textStyle: AppTextStyles.small(
                    context,
                  ).copyWith(color: AppColors.black),
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.submit,
                ),
              ),
              SizedBox(height: responsive.h(2)),
              Padding(
                padding: EdgeInsets.only(bottom: responsive.h(3)),
                child: const PrivacyContent(),
              ),

              // ==========================================
              // BOTTOM SPACE
              // ==========================================
            ],
          ),
        ),
      ),
    );
  }
}
