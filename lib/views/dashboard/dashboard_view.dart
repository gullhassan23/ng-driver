import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/routes/app_routes.dart';

import '../../controllers/dashboard_controller.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';


import '../../widgets/dashboard/dashboard_book_ride_widget.dart';
import '../../widgets/dashboard/dashboard_greeting_widget.dart';
import '../../widgets/dashboard/dashboard_stats_widget.dart';
import '../../widgets/dashboard/dashboard_suggestion_widget.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        responsive.w(5),
        responsive.h(2),
        responsive.w(5),
        responsive.h(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TEMPORARY SIGN OUT

          /// GREETING
          Obx(
            () => DashboardGreetingWidget(name: controller.greetingName.value),
          ),

          /// TITLE
          // Text(
          //   "Today's suggestion",
          //   style: TextStyle(
          //     fontSize: responsive.h(1.8),
          //     fontWeight: FontWeight.w600,
          //     color: AppColors.white,
          //   ),
          // ),
          SizedBox(height: responsive.h(2.5)),

          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: responsive.h(20),
              child: Image.asset(
                'assets/mapimage.png',
                width: double.infinity,
                height: responsive.h(20),
                fit: BoxFit.cover,
              ),
            ),
          ),

          /// CONTINUE
          DashboardContinueButton(
            onTap: () {
              Get.toNamed(AppRoutes.ridePending);
            },
          ),
          SizedBox(height: responsive.h(1.5)),

          /// BOOK A RIDEs
          DashboardBookRideWidget(
            color: AppColors.white,
            onTap: () {
              // Get.toNamed(AppRoutes.reservation);
              Get.toNamed(AppRoutes.pendingReservation);
            },
          ),

          SizedBox(height: responsive.h(1.5)),

          /// RIDES + REWARDS
          Obx(
            () => DashboardStatsWidget(
              ridesTaken: controller.ridesTaken.value,
              averageRating: controller.averageRating.value,
              reviewCount: controller.reviewCount.value,
            ),
          ),
        ],
      ),
    );
  }
}
