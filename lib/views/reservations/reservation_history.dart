import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/controllers/reservation_history_controller.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';
import 'package:ngtowncardriver/utilis/firestore_paths.dart';
import 'package:ngtowncardriver/views/reservations/new_reservation_request_view.dart';
import 'package:ngtowncardriver/views/reservations/reservation_detail_view.dart';
import 'package:ngtowncardriver/widgets/app_icon_button_widget.dart';
import 'package:ngtowncardriver/widgets/app_ride_history_widget.dart';
import 'package:ngtowncardriver/widgets/reservation/reservation_filter_widget.dart';

import '../../models/reservation_model.dart';

class ReservationHistory extends GetView<ReservationHistoryController> {
  const ReservationHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, responsive),
            SizedBox(height: responsive.h(2)),
            Obx(
              () => AppReservationFilterWidget(
                selectedIndex: controller.selectedFilter.value,
                onChanged: controller.selectFilter,
              ),
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

                final reservations = controller.filteredReservations;

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
                    final isCancelled =
                        ReservationStatus.isCancelled(reservation.status);

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
                      isCancelled: isCancelled,
                      onTap: () => _openReservation(reservation),
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

  void _openReservation(ReservationModel reservation) {
    if (reservation.isPending) {
      openNewReservationRequest(reservation);
      return;
    }
    openReservationDetail(reservation);
  }

  Widget _buildHeader(BuildContext context, ResponsiveRepo responsive) {
    final canPop = Navigator.of(context).canPop();

    return Padding(
      padding: EdgeInsets.only(
        // left: responsive.w(canPop ? 1 : 4),
        // right: responsive.w(4),
        // top: responsive.h(1),
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
              onPressed: () => Get.back(),
              backgroundColor: AppColors.primaryGreen,
              iconColor: AppColors.black,
              width: responsive.w(10),
              height: responsive.w(10),
              borderRadius: responsive.w(3),
            ),
          SizedBox(width: responsive.w(5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${AppText.reservation} ',
                        style: AppTextStyles.large(
                          context,
                        ).copyWith(color: AppColors.white),
                      ),
                      TextSpan(
                        text: AppText.history,
                        style: AppTextStyles.large(
                          context,
                        ).copyWith(color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: responsive.h(0.2)),
                Text(
                  AppText.reservationHistorySubtitle,
                  style: AppTextStyles.small(
                    context,
                  ).copyWith(color: AppColors.white.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ResponsiveRepo responsive) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_outlined,
            color: AppColors.white.withValues(alpha: 0.35),
            size: responsive.w(15),
          ),
          SizedBox(height: responsive.h(2)),
          Text(
            'No reservations found',
            style: AppTextStyles.whiteMedium(context),
          ),
        ],
      ),
    );
  }
}
