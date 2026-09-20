import 'package:flutter/material.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

import '../../responsiveness/responsive_repo.dart';

class DashboardBookRideWidget extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  const DashboardBookRideWidget({
    super.key,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: responsive.w(5),
          vertical: responsive.h(1.5),
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(responsive.w(8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppText.checkNewReservationRequestsAndRespond,
                    // style: TextStyle(
                    //   color: AppColors.black,
                    //   fontSize: responsive.h(1.8),
                    //   fontWeight: FontWeight.w600,
                    // ),
                    style: AppTextStyles.medium(context).copyWith(
                      color: AppColors.black,
                      fontSize: responsive.h(2.2),
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  SizedBox(height: responsive.h(0.2)),

                  Text(
                    AppText.requestsandRespond,
                    style: AppTextStyles.small(context).copyWith(
                      color: AppColors.black.withValues(alpha: 0.54),
                      fontSize: responsive.h(1.25),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              width: responsive.w(10),
              height: responsive.w(10),
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
    );
  }
}
