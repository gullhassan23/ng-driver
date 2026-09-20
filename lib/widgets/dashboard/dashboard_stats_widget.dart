import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/routes/app_routes.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

import '../../responsiveness/responsive_repo.dart';

class DashboardStatsWidget extends StatelessWidget {
  final int ridesTaken;
  final double averageRating;
  final int reviewCount;

  const DashboardStatsWidget({
    super.key,
    this.ridesTaken = 0,
    this.averageRating = 0,
    this.reviewCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
    final filledStars = reviewCount == 0
        ? 0
        : averageRating.round().clamp(0, 5);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// RIDES TAKEN
          Expanded(
            child: GestureDetector(
              onTap: () {
                Get.toNamed(AppRoutes.rideCompleted);
              },
              child: Container(
                constraints: BoxConstraints(minHeight: responsive.h(10)),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(responsive.w(10)),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.w(3),
                  vertical: responsive.h(1.2),
                ),
                child: Column(
                  // crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$ridesTaken',
                      style: AppTextStyles.small(context).copyWith(
                        color: AppColors.black,
                        fontSize: responsive.h(2.8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: responsive.h(0.2)),
                    Text(
                      'Rides taken',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.small(context).copyWith(
                        color: AppColors.black,
                        fontSize: responsive.h(1.8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: responsive.w(2)),

          /// REVIEWS & RATINGS
          Expanded(
            child: GestureDetector(
              onTap: () {
                Get.toNamed(AppRoutes.reviewsRatings);
              },
              child: Container(
                constraints: BoxConstraints(minHeight: responsive.h(10)),
                decoration: BoxDecoration(
                  color: AppColors.smokeywhite,
                  borderRadius: BorderRadius.circular(responsive.w(10)),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.w(3),
                  vertical: responsive.h(1.2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(5, (index) {
                            final filled = index < filledStars;
                            return Icon(
                              filled ? Icons.star : Icons.star_border,
                              color: AppColors.black,
                              size: responsive.h(2.2),
                            );
                          }),
                          if (reviewCount > 0) ...[
                            SizedBox(width: responsive.w(1.2)),
                            Text(
                              averageRating.toStringAsFixed(1),
                              style: AppTextStyles.small(context).copyWith(
                                color: AppColors.black,
                                fontSize: responsive.h(1.7),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: responsive.h(0.2)),
                    Text(
                      'Reviews & Ratings',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.small(context).copyWith(
                        color: AppColors.black,
                        fontSize: responsive.h(1.8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
