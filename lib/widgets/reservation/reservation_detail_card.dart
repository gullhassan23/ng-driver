import 'package:flutter/material.dart';
import 'package:ngtowncardriver/models/reservation_model.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';
import 'package:ngtowncardriver/utilis/firestore_paths.dart';

class AppReservationDetailsCardWidget extends StatelessWidget {
  final ReservationModel reservation;

  const AppReservationDetailsCardWidget({
    super.key,
    required this.reservation,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
    final BorderRadius radius = BorderRadius.circular(responsive.w(4));
    final double accentWidth = responsive.w(0.8);

    final String passengers = '${reservation.passengerCount}';
    final String luggage = '${reservation.luggageCount}';
    final String distance = reservation.displayDistance;
    final String serviceType = reservation.serviceType.trim().isNotEmpty
        ? reservation.serviceType
        : '—';
    final String vehicleType = reservation.vehicleType.trim().isNotEmpty
        ? reservation.vehicleType
        : '—';
    final bool isCancelled = ReservationStatus.isCancelled(reservation.status);
    final String? cancelReason = reservation.cancelReason?.trim();
    final bool showCancelReason =
        isCancelled && cancelReason != null && cancelReason.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: radius,
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.w(3.5) + accentWidth,
                responsive.w(3.5),
                responsive.w(3.5),
                responsive.w(3.5),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: responsive.w(10),
                        height: responsive.w(10),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen,
                        ),
                        child: Icon(
                          Icons.description,
                          color: AppColors.black,
                          size: responsive.w(5),
                        ),
                      ),
                      SizedBox(width: responsive.w(3)),
                      Expanded(
                        child: Text(
                          'Reservation Details',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.whiteMedium(context).copyWith(
                            fontSize: responsive.h(2.25),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.h(2)),
                  Divider(color: AppColors.white.withValues(alpha: 0.10)),
                  SizedBox(height: responsive.h(2)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _DetailItem(
                              icon: Icons.groups,
                              title: 'Passengers',
                              value: passengers,
                              responsive: responsive,
                            ),
                            _DetailItem(
                              icon: Icons.luggage,
                              title: 'Luggage',
                              value: luggage,
                              responsive: responsive,
                            ),
                            if (showCancelReason)
                              _DetailItem(
                                icon: Icons.cancel_outlined,
                                title: 'Reason of Cancel',
                                value: cancelReason,
                                responsive: responsive,
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: responsive.h(showCancelReason ? 24 : 18),
                        margin: EdgeInsets.symmetric(
                          horizontal: responsive.w(4),
                        ),
                        color: AppColors.white.withValues(alpha: 0.10),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _DetailItem(
                              icon: Icons.route,
                              title: 'Distance',
                              value: distance,
                              responsive: responsive,
                            ),
                            _DetailItem(
                              icon: Icons.sync,
                              title: 'Service Type',
                              value: serviceType,
                              responsive: responsive,
                            ),
                            _DetailItem(
                              icon: Icons.directions_car_outlined,
                              title: 'Vehicle',
                              value: vehicleType,
                              responsive: responsive,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: accentWidth,
                color: AppColors.primaryGreen.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final ResponsiveRepo responsive;

  const _DetailItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: responsive.h(2.5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: responsive.w(6)),
          SizedBox(width: responsive.w(3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small(context).copyWith(
                    color: AppColors.primaryGreen.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: responsive.h(0.3)),
                Text(
                  value,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small(
                    context,
                  ).copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
