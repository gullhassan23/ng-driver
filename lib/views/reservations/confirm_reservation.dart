import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/controllers/confirm_reservation_controller.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';
import 'package:ngtowncardriver/views/reservations/reservation_detail_view.dart';

import 'package:ngtowncardriver/widgets/app_ride_history_widget.dart';
import 'package:ngtowncardriver/widgets/header/header.dart';

class ConfirmReservation extends GetView<ConfirmReservationController> {
  const ConfirmReservation({super.key});

  @override
  Widget build(BuildContext context) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              responsive: responsive,
              title: AppText.confirm,
              subtitle: AppText.reservation,
              canPop: false,
            ),
            SizedBox(height: responsive.h(2)),
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
                  return Center(
                    child: Text(
                      error,
                      style: AppTextStyles.whiteSmall(context),
                    ),
                  );
                }

                final reservations = controller.confirmedReservations;

                if (reservations.isEmpty) {
                  return _buildEmptyState(context, responsive);
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: responsive.w(3),
                    right: responsive.w(3),
                    top: responsive.h(0.5),
                    bottom: responsive.h(2),
                  ),
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final reservation = reservations[index];

                    return AppRideHistoryCardWidget(
                      pickupLocation: reservation.pickupAddress.isEmpty
                          ? 'Pickup'
                          : reservation.pickupAddress,
                      dropOffLocation: reservation.dropOffAddress.isEmpty
                          ? 'Drop-off'
                          : reservation.dropOffAddress,
                      date: reservation.displayPickupDate,
                      time: reservation.displayPickupTime,
                      fare: reservation.displayFare,
                      distance: reservation.displayDistance,
                      status: reservation.displayStatus,
                      isCancelled: false,
                      onTap: () => openReservationDetail(reservation),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ResponsiveRepo responsive) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available_outlined,
            color: AppColors.white.withValues(alpha: 0.35),
            size: responsive.w(15),
          ),
          SizedBox(height: responsive.h(2)),
          Text(
            'No confirmed reservations',
            style: AppTextStyles.whiteMedium(context),
          ),
        ],
      ),
    );
  }
}
