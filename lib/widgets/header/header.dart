import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/routes/app_navigator.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';
import 'package:ngtowncardriver/widgets/app_icon_button_widget.dart';

class AppHeader extends StatelessWidget {
  final ResponsiveRepo responsive;
  final String title;
  final String subtitle;
  final bool canPop;
  final VoidCallback? onBackPressed;

  // Optional bottom description
  final bool showDescription;
  final String? description;

  const AppHeader({
    super.key,
    required this.responsive,
    required this.title,
    required this.subtitle,
    required this.canPop,
    this.onBackPressed,
    this.showDescription = false,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: responsive.w(3),
        right: responsive.w(3),
        top: responsive.h(1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop)
            AppIconButtonWidget(
              icon: Icons.arrow_back,
              onPressed: onBackPressed ??
                  () {
                    if (Navigator.canPop(context)) {
                      Get.back();
                    } else {
                      AppNavigator.todashboard();
                    }
                  },
              backgroundColor: AppColors.primaryGreen,
              iconColor: AppColors.black,
              width: responsive.w(10),
              height: responsive.w(10),
              borderRadius: responsive.w(3),
            ),

          SizedBox(width: responsive.w(3)),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: AppTextStyles.large(
                          context,
                        ).copyWith(color: AppColors.white, height: 1),
                      ),
                      WidgetSpan(child: SizedBox(width: responsive.w(1))),
                      TextSpan(
                        text: subtitle,
                        style: AppTextStyles.large(
                          context,
                        ).copyWith(color: AppColors.primaryGreen, height: 1),
                      ),
                    ],
                  ),
                ),

                // Optional description
                if (showDescription && description != null) ...[
                  SizedBox(height: responsive.h(0.2)),
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.small(context).copyWith(
                      fontSize: responsive.h(1.4),
                      color: AppColors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
