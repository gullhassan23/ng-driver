import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/widgets/app_image_widget.dart';
import 'package:ngtowncardriver/widgets/auth_text.dart';
import 'package:ngtowncardriver/widgets/privacy_content.dart';

import '../../controllers/auth_controller.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../routes/app_routes.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text.dart';
import '../../utilis/app_text_styles.dart';
import '../../widgets/buttons/app_button_widget.dart';

import '../../widgets/app_text_field_widget.dart';
import '../../widgets/app_text_widget.dart';

class SignInView extends GetView<AuthController> {
  const SignInView({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppImageWidget(
                      asset: 'assets/images/Appmain.webp',
                      height: responsive.h(10),
                      top: responsive.h(1),
                      left: responsive.w(5),
                    ),

                    AppTextWidget(
                      text: AppText.helloAgain,
                      style: AppTextStyles.large(context),
                      gradient: AppColors.gradientOrange,
                      top: responsive.h(2),
                      left: responsive.w(8),
                    ),

                    AppTextWidget(
                      text: AppText.welcomeBack,
                      style: AppTextStyles.large(
                        context,
                      ).copyWith(color: AppColors.white),
                      left: responsive.w(8),
                    ),

                    AppTextWidget(
                      text: AppText.signInSubtitle,
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
                      textInputAction: TextInputAction.next,
                      top: responsive.h(4),
                      left: responsive.w(8),
                      right: responsive.w(8),
                    ),

                    Obx(
                      () => AppTextFieldWidget(
                        hintText: AppText.password,
                        controller: controller.signInPassword,
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: controller.obscurePassword.value,
                        textInputAction: TextInputAction.done,
                        top: responsive.h(1),
                        left: responsive.w(8),
                        right: responsive.w(8),
                        suffixIcon: IconButton(
                          icon: Icon(
                            controller.obscurePassword.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white54,
                          ),
                          onPressed: () {
                            controller.obscurePassword.toggle();
                          },
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppTextWidget(
                        gradient: AppColors.gradientOrange,
                        text: AppText.forgotPassword,
                        style: AppTextStyles.small(context),
                        top: responsive.h(1),
                        left: responsive.w(8),
                        right: responsive.w(8),
                        onTap: () {
                          Get.toNamed(AppRoutes.forgotPassword);
                        },
                      ),
                    ),
                    Obx(
                      () => AppButtonWidget(
                        text: controller.isLoading.value
                            ? 'Signing in...'
                            : AppText.signIn,
                        width: double.infinity,
                        height: responsive.h(6),
                        top: responsive.h(4),
                        left: responsive.w(8),
                        right: responsive.w(8),
                        borderRadius: responsive.w(8),
                        textStyle: AppTextStyles.small(
                          context,
                        ).copyWith(color: AppColors.black),
                        onPressed: controller.isLoading.value
                            ? null
                            : controller.signIn,
                      ),
                    ),

                    AuthText(
                      title: "Don't have an account? ",
                      text: "Sign Up",
                      onTap: () {
                        Get.toNamed(AppRoutes.signUp);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: responsive.h(3)),
              child: const PrivacyContent(),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:ngtowncardriver/controllers/auth_controller.dart';
// import 'package:ngtowncardriver/utilis/app_colors.dart';
// import 'package:ngtowncardriver/utilis/app_text.dart';
// import 'package:ngtowncardriver/utilis/app_text_styles.dart';
// import 'package:ngtowncardriver/widgets/auth_rich_text_widget.dart';
// import 'package:ngtowncardriver/widgets/auth_term_rich_widget.dart';
// import 'package:url_launcher/url_launcher.dart';

// import '../../repositories/responsive_repo.dart';
// import '../../routes/app_routes.dart';

// import '../../widgets/app_button_widget.dart';
// import '../../widgets/app_image_widget.dart';
// import '../../widgets/app_rich_text_widget.dart';
// import '../../widgets/app_text_field_widget.dart';
// import '../../widgets/app_text_widget.dart';

// class SignInView extends GetView<AuthController> {
//   const SignInView({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final responsive = ResponsiveRepo(context);

//     return Scaffold(
//       backgroundColor: Colors.black,

//       // Screen scroll nahi hogi
//       resizeToAvoidBottomInset: false,

//       body: SafeArea(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // =========================================================
//             // LOGO
//             // =========================================================
//             AppImageWidget(
//               asset: 'assets/logo.webp',
//               height: responsive.h(8),
//               top: responsive.h(8),
//               left: responsive.w(8),
//             ),

//             // =========================================================
//             // HELLO AGAIN + WELCOME BACK
//             // =========================================================
//             AppRichTextWidget(
//               top: responsive.h(1.5),
//               left: responsive.w(8),
//               right: responsive.w(8),
//               children: [
//                 TextSpan(
//                   text: AppText.welcomeBack,
//                   style: AppTextStyles.large(
//                     context,
//                   ).copyWith(color: AppColors.secondaryRed),
//                 ),

//                 TextSpan(
//                   text: '\n${AppText.driver}',
//                   style: AppTextStyles.large(
//                     context,
//                   ).copyWith(color: AppColors.white),
//                 ),
//               ],
//             ),

//             // =========================================================
//             // EMAIL FIELD
//             // =========================================================
//             AppTextFieldWidget(
//               hintText: AppText.email,
//               keyboardType: TextInputType.emailAddress,
//               top: responsive.h(4),
//               left: responsive.w(8),
//               right: responsive.w(8),
//             ),

//             // =========================================================
//             // PASSWORD FIELD
//             // =========================================================
//             AppTextFieldWidget(
//               hintText: 'Password',
//               obscureText: true,
//               keyboardType: TextInputType.text,
//               top: responsive.h(1.5),
//               left: responsive.w(8),
//               right: responsive.w(8),
//             ),

//             // =========================================================
//             // FORGOT PASSWORD
//             // =========================================================
//             Align(
//               alignment: Alignment.centerRight,
//               child: Padding(
//                 padding: EdgeInsets.only(
//                   top: responsive.h(1.5),
//                   right: responsive.w(8),
//                 ),
//                 child: AppTextWidget(
//                   text: AppText.forgotPassword,
//                   style: AppTextStyles.small(
//                     context,
//                   ).copyWith(color: AppColors.secondaryRed),
//                   onTap: () {
//                     // Navigator.pushNamed(context, AppRoutes.forgot);
//                   },
//                 ),
//               ),
//             ),

//             // =========================================================
//             // SIGN IN BUTTON
//             // =========================================================
//             AppButtonWidget(
//               text: AppText.signIn,
//               width: double.infinity,
//               height: responsive.h(6),
//               top: responsive.h(8),
//               left: responsive.w(8),
//               right: responsive.w(8),
//               borderRadius: 25,

//               textStyle: AppTextStyles.small(
//                 context,
//               ).copyWith(color: AppColors.black),

//                onPressed: controller.isLoading.value
//                       ? null
//                       : controller.signIn,
//             ),

//             // =========================================================
//             // DON'T HAVE AN ACCOUNT? SIGN UP
//             // =========================================================
//             SizedBox(
//               width: double.infinity,
//               child: Padding(
//                 padding: EdgeInsets.only(
//                   top: responsive.h(3),
//                   left: responsive.w(8),
//                   right: responsive.w(8),
//                 ),
//                 child: AuthRichTextWidget(
//                   normalText: "Don't have an account?",
//                   highlightedText: "Sign Up",

//                   normalTextColor: const Color(0xFFB8B8B8),

//                   highlightedTextColor: AppColors.secondaryRed,

//                   normalFontSize: 1.7,
//                   highlightedFontSize: 1.7,

//                   normalFontWeight: FontWeight.w400,

//                   highlightedFontWeight: FontWeight.w500,

//                   textAlign: TextAlign.center,

//                   onHighlightedTap: () {
//                     Navigator.pushNamed(context, AppRoutes.signUp);
//                   },
//                 ),
//               ),
//             ),

//             // =========================================================
//             // EMPTY SPACE
//             // Terms ko automatically bottom ki taraf push karega
//             // =========================================================
//             const Spacer(),

//             // =========================================================
//             // TERMS & PRIVACY POLICY
//             // =========================================================
//             Padding(
//               padding: EdgeInsets.only(
//                 left: responsive.w(8),
//                 right: responsive.w(8),
//                 bottom: responsive.h(3),
//               ),
//               child: AuthTermsRichTextWidget(
//                 normalText: "By signing in, you agree to our ",

//                 firstHighlightedText: "Terms of Service",

//                 middleText: " and ",

//                 secondHighlightedText: "Privacy Policy",

//                 normalTextColor: const Color(0xFFB8B8B8),

//                 firstHighlightedTextColor: AppColors.secondaryRed,

//                 secondHighlightedTextColor: AppColors.secondaryRed,

//                 normalFontSize: 1.7,
//                 firstHighlightedFontSize: 1.7,
//                 secondHighlightedFontSize: 1.7,

//                 normalFontWeight: FontWeight.w400,

//                 firstHighlightedFontWeight: FontWeight.w500,

//                 secondHighlightedFontWeight: FontWeight.w500,

//                 textAlign: TextAlign.center,

//                 maxLines: 2,

//                 onFirstHighlightedTap: () async {
//                   final Uri url = Uri.parse('https://rankersforce.com/');

//                   if (await canLaunchUrl(url)) {
//                     await launchUrl(url, mode: LaunchMode.externalApplication);
//                   }
//                 },

//                 onSecondHighlightedTap: () async {
//                   final Uri url = Uri.parse('https://rankersforce.com/');

//                   if (await canLaunchUrl(url)) {
//                     await launchUrl(url, mode: LaunchMode.externalApplication);
//                   }
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
