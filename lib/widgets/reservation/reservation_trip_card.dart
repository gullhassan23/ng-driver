import 'package:flutter/material.dart';
import 'package:ngtowncardriver/models/reservation_model.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

class AppReservationTripCardWidget extends StatelessWidget {
  final ReservationModel reservation;

  const AppReservationTripCardWidget({super.key, required this.reservation});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
    final BorderRadius radius = BorderRadius.circular(responsive.w(4));
    final double accentWidth = responsive.w(0.8);
    final double iconSize = responsive.w(6);
    final String pickup = reservation.pickupAddress.trim().isNotEmpty
        ? reservation.pickupAddress
        : '—';
    final String dropOff = reservation.dropOffAddress.trim().isNotEmpty
        ? reservation.dropOffAddress
        : '—';
    final String date = reservation.displayPickupDate;
    final String time = reservation.displayPickupTime;
    final String fare = reservation.displayFare;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.10),
        ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/images/location.webp',
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: responsive.w(3)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pickup',
                              style: AppTextStyles.small(context).copyWith(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: responsive.h(0.5)),
                            Text(
                              pickup,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.whiteMedium(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.h(2.5)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/images/flag.webp',
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: responsive.w(3)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Drop-off',
                              style: AppTextStyles.small(context).copyWith(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: responsive.h(0.5)),
                            Text(
                              dropOff,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.whiteMedium(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.h(2.5)),
                  Divider(color: AppColors.white.withValues(alpha: 0.10)),
                  SizedBox(height: responsive.h(2)),
                  Row(
                    children: [
                      Expanded(
                        child: _TripInfo(
                          icon: Icons.calendar_month,
                          title: 'Date',
                          value: date,
                          responsive: responsive,
                        ),
                      ),
                      _VerticalDivider(responsive: responsive),
                      Expanded(
                        child: _TripInfo(
                          icon: Icons.access_time,
                          title: 'Time',
                          value: time,
                          responsive: responsive,
                        ),
                      ),
                      _VerticalDivider(responsive: responsive),
                      Expanded(
                        child: _TripInfo(
                          icon: Icons.monetization_on,
                          title: 'Fare',
                          value: fare,
                          responsive: responsive,
                          valueColor: AppColors.white,
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
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripInfo extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final ResponsiveRepo responsive;
  final Color? valueColor;

  const _TripInfo({
    required this.icon,
    required this.title,
    required this.value,
    required this.responsive,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryGreen, size: responsive.w(5)),
        SizedBox(height: responsive.h(0.5)),
        Text(
          title,
          maxLines: 1,
          style: AppTextStyles.small(context).copyWith(
            fontSize: responsive.h(1.35),
            color: AppColors.primaryGreen.withValues(alpha: 0.75),
          ),
        ),
        SizedBox(height: responsive.h(0.3)),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.small(context).copyWith(
            fontSize: responsive.h(1.45),
            color: valueColor ?? AppColors.white,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  final ResponsiveRepo responsive;

  const _VerticalDivider({required this.responsive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: responsive.h(7.5),
      margin: EdgeInsets.symmetric(horizontal: responsive.w(1.5)),
      color: AppColors.white.withValues(alpha: 0.12),
    );
  }
}
