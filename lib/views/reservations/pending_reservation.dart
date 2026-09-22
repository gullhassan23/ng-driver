import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/dashboard_controller.dart';
import '../../controllers/pending_reservation_controller.dart';
import '../../models/reservation_model.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text_styles.dart';
import '../../widgets/app_ride_history_widget.dart';
import '../../widgets/location/location_permission_handler.dart';
import '../../widgets/online_status_toggle.dart';
import '../../widgets/waiting_map_lottie.dart';
import 'new_reservation_request_view.dart';

class PendingReservation extends StatefulWidget {
  const PendingReservation({super.key});

  @override
  State<PendingReservation> createState() => _PendingReservationState();
}

class _PendingReservationState extends State<PendingReservation>
    with WidgetsBindingObserver {
  DashboardController get dashboard => Get.find<DashboardController>();
  PendingReservationController get controller =>
      Get.find<PendingReservationController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      dashboard.onAppResumed(forMode: DriverOnlineMode.reservation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      // clipBehavior: Clip.hardEdge,
      appBar: AppBar(
        backgroundColor: AppColors.dashboardBackground,
        elevation: 0,
        centerTitle: true,
        title: Obx(
          () => OnlineStatusToggle(
            isOnline: dashboard.isReservationOnline,
            isBusy: dashboard.isTogglingOnline.value,
            onTap: dashboard.toggleReservationOnline,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: LocationPermissionHandler(
        onEnabled: () =>
            dashboard.onAppResumed(forMode: DriverOnlineMode.reservation),
        child: Obx(() {
        if (!dashboard.isReservationOnline) {
          return Center(
            child: Text(
              'You are offline',
              style: AppTextStyles.medium(
                context,
              ).copyWith(color: AppColors.white, fontWeight: FontWeight.w600),
            ),
          );
        }

        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        final error = controller.errorMessage.value;
        if (error != null) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: responsive.w(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load reservations',
                    style: AppTextStyles.medium(context).copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: responsive.h(1)),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.small(
                      context,
                    ).copyWith(color: AppColors.white.withValues(alpha: 0.7)),
                  ),
                  SizedBox(height: responsive.h(2)),
                  TextButton(
                    onPressed: controller.retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final reservations = controller.pendingReservations;

        if (reservations.isEmpty) {
          return const WaitingMapLottie();
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
              onTap: () => _openReservation(reservation),
            );
          },
        );
      }),
      ),
    );
  }

  void _openReservation(ReservationModel reservation) {
    openNewReservationRequest(reservation);
  }
}
