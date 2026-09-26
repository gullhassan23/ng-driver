import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/controllers/reservation_detail_controller.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';
import 'package:ngtowncardriver/utilis/firestore_paths.dart';
import 'package:ngtowncardriver/widgets/app_icon_button_widget.dart';
import 'package:ngtowncardriver/widgets/buttons/app_button_widget.dart';
import 'package:ngtowncardriver/widgets/reservation/reservation_customer_card.dart';
import 'package:ngtowncardriver/widgets/reservation/reservation_detail_card.dart';
import 'package:ngtowncardriver/widgets/reservation/reservation_trip_card.dart';

import '../../models/reservation_model.dart';
import '../../responsiveness/responsive_repo.dart';

class ReservationDetailView extends GetView<ReservationDetailController> {
  const ReservationDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: SafeArea(
        child: Column(
          children: [
            Obx(() {
              final reservation = controller.reservation.value;
              return _buildHeader(context, responsive, reservation);
            }),
            Expanded(
              child: Obx(() {
                final reservation = controller.reservation.value;
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.w(4),
                    vertical: responsive.h(1),
                  ),
                  child: Column(
                    children: [
                      AppReservationCustomerCardWidget(
                        reservation: reservation,
                      ),
                      SizedBox(height: responsive.h(2)),
                      AppReservationTripCardWidget(reservation: reservation),
                      SizedBox(height: responsive.h(2)),
                      AppReservationDetailsCardWidget(
                        reservation: reservation,
                      ),
                      SizedBox(height: responsive.h(2)),
                    ],
                  ),
                );
              }),
            ),
            Obx(() {
              if (controller.canStartRide) {
                return _buildRideAction(
                  context,
                  responsive,
                  label: AppText.startRide,
                  icon: Icons.play_arrow_rounded,
                  onPressed: controller.startRide,
                  isEnabled: controller.isStartRideEnabled,
                );
              }
              if (controller.canContinueRide) {
                return _buildRideAction(
                  context,
                  responsive,
                  label: AppText.continueRide,
                  icon: Icons.map_outlined,
                  onPressed: controller.continueRide,
                  isEnabled: true,
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRideAction(
    BuildContext context,
    ResponsiveRepo responsive, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isEnabled,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.w(4),
        responsive.h(1),
        responsive.w(4),
        responsive.h(1.5),
      ),
      child: Obx(() {
        final busy = controller.isSubmitting.value;
        final effectiveOnPressed = (busy || !isEnabled) ? null : onPressed;

        final activeBg = AppColors.dashboardAccent;
        final disabledBg = const Color(0xFF2C2C2E);

        final activeFg = AppColors.black;
        final disabledFg = AppColors.white.withValues(alpha: 0.38);

        return AppButtonWidget(
          text: label,
          onPressed: effectiveOnPressed,
          backgroundColor: activeBg,
          disabledBackgroundColor: disabledBg,
          foregroundColor: isEnabled ? activeFg : disabledFg,
          borderRadius: responsive.w(3),
          showTrailingArrow: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: responsive.w(5),
                  height: responsive.w(5),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.black,
                  ),
                )
              else
                Icon(
                  icon,
                  color: isEnabled ? activeFg : disabledFg,
                  size: responsive.w(6),
                ),
              SizedBox(width: responsive.w(2)),
              Text(
                label,
                style: AppTextStyles.small(context).copyWith(
                  color: isEnabled ? activeFg : disabledFg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ResponsiveRepo responsive,
    ReservationModel reservation,
  ) {
    final String currentStatus = reservation.displayStatus;
    final Color statusColor = _statusColor(reservation.status);
    final IconData statusIcon = _statusIcon(reservation.status);

    return Padding(
      padding: EdgeInsets.only(
        left: responsive.w(4),
        right: responsive.w(4),
        top: responsive.h(1),
        bottom: responsive.h(1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconButtonWidget(
            icon: Icons.arrow_back,
            onPressed: () => Get.back(),
            backgroundColor: AppColors.primaryGreen,
            iconColor: AppColors.black,
            width: responsive.w(10),
            height: responsive.h(5),
            top: responsive.h(2),
            left: responsive.w(4),
            borderRadius: responsive.w(3),
          ),
          SizedBox(width: responsive.w(2.5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    maxLines: 1,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${AppText.reservation} ',
                          style: AppTextStyles.whiteMedium(context).copyWith(
                            color: AppColors.white,
                            fontSize: responsive.h(2.4),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Details',
                          style: AppTextStyles.whiteMedium(context).copyWith(
                            color: AppColors.primaryGreen,
                            fontSize: responsive.h(2.4),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: responsive.h(0.3)),
                Text(
                  'View complete information about this reservation',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small(context).copyWith(
                    fontSize: responsive.h(1.4),
                    color: AppColors.white.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: responsive.w(2)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.w(2.5),
              vertical: responsive.h(0.8),
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(responsive.w(6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: responsive.w(3.8)),
                SizedBox(width: responsive.w(1)),
                Text(
                  currentStatus,
                  maxLines: 1,
                  style: AppTextStyles.small(context).copyWith(
                    fontSize: responsive.h(1.45),
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (ReservationStatus.isCompleted(status)) return AppColors.primaryGreen;
    if (ReservationStatus.isCancelled(status)) {
      return const Color(0xFFFF3B4A);
    }
    if (ReservationStatus.isLiveActive(status)) {
      return AppColors.dashboardAccent;
    }
    if (ReservationStatus.isConfirm(status)) return AppColors.primaryGreen;
    if (lower == ReservationStatus.pending) return const Color(0xFFFFC928);
    return const Color(0xFFFFC928);
  }

  IconData _statusIcon(String status) {
    if (ReservationStatus.isCompleted(status)) {
      return Icons.check_circle_outline;
    }
    if (ReservationStatus.isCancelled(status)) return Icons.cancel_outlined;
    if (status.toLowerCase() == ReservationStatus.driverArriving) {
      return Icons.directions_car_outlined;
    }
    if (status.toLowerCase() == ReservationStatus.driverArrived) {
      return Icons.place_outlined;
    }
    if (status.toLowerCase() == ReservationStatus.rideStarted) {
      return Icons.route_outlined;
    }
    if (ReservationStatus.isConfirm(status)) {
      return Icons.verified_outlined;
    }
    return Icons.hourglass_empty;
  }
}

/// Opens [ReservationDetailView] with a scoped GetX controller.
void openReservationDetail(ReservationModel reservation) {
  Get.to(
    () => const ReservationDetailView(),
    binding: BindingsBuilder(() {
      Get.put(ReservationDetailController(reservation: reservation));
    }),
  );
}
