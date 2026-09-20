import 'package:flutter/material.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

import '../../responsiveness/responsive_repo.dart';

class DashboardSuggestionWidget extends StatelessWidget {
  const DashboardSuggestionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Container(
      width: double.infinity,
      height: responsive.h(28),
      decoration: BoxDecoration(
        // color: AppColors.white,
        borderRadius: BorderRadius.circular(responsive.w(6.5)),
        image: const DecorationImage(
          image: AssetImage('assets/mapimage.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class DashboardContinueButton extends StatelessWidget {
  final VoidCallback? onTap;

  const DashboardContinueButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTap,

        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.w(5),
                vertical: responsive.h(2),
              ),
              decoration: BoxDecoration(
                gradient: AppColors.gradientOrange,
                borderRadius: BorderRadius.circular(responsive.w(15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppText.viewLiveRides,
                    // style: TextStyle(

                    //   color: AppColors.black,
                    //   fontSize: responsive.h(2.6),
                    //   fontWeight: FontWeight.w600,
                    // ),
                    style: AppTextStyles.medium(context).copyWith(
                      color: AppColors.black,
                      fontSize: responsive.h(2.6),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Container(
                    width: responsive.w(15),
                    height: responsive.w(15),
                    decoration: const BoxDecoration(
                      color: AppColors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      color: AppColors.dashboardWhite,
                      size: responsive.w(5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
