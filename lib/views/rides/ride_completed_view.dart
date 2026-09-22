import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/widgets/header/header.dart';

import '../../controllers/ride_completed_controller.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text.dart';
import '../../utilis/app_text_styles.dart';

import '../../widgets/buttons/app_button_widget.dart';

class RideCompletedView extends GetView<RideCompletedController> {
  const RideCompletedView({super.key});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.missingRide.value) {
        controller.queueCloseIfMissing();
        return const Scaffold(
          backgroundColor: AppColors.dashboardBackground,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          ),
        );
      }

      final ride = controller.ride.value;
      if (ride == null) {
        return const Scaffold(
          backgroundColor: AppColors.dashboardBackground,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          ),
        );
      }

      final responsive = ResponsiveRepo(context);
      final when = ride.completedAt ?? ride.updatedAt ?? ride.createdAt;
      final passenger = ride.customerName.trim().isEmpty
          ? 'Passenger'
          : ride.customerName.trim();
      final pickup = ride.pickupLocation.trim().isEmpty
          ? 'Pickup'
          : ride.pickupLocation.trim();
      final dropoff = ride.dropoffLocation.trim().isEmpty
          ? 'Drop-off'
          : ride.dropoffLocation.trim();
      final fare = ride.formattedFare.isEmpty ? '—' : ride.formattedFare;
      final distance = ride.formattedDistance.isEmpty
          ? '—'
          : ride.formattedDistance;
      final duration = ride.formattedDuration.isEmpty
          ? '—'
          : ride.formattedDuration;
      final vehicle = ride.vehicleType.trim().isEmpty
          ? '—'
          : ride.vehicleType.trim();
      final returnToDashboard = controller.returnToDashboard.value;

      return PopScope(
        canPop: !returnToDashboard,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.close();
        },
        child: Scaffold(
          backgroundColor: AppColors.dashboardBackground,
          body: SafeArea(
            child: Column(
              children: [
                AppHeader(
                  responsive: responsive,
                  title: AppText.ride,
                  subtitle: AppText.completed,
                  canPop: true,
                  showDescription: true,
                  description: "Trip summary",
                ),
                SizedBox(height: responsive.h(2)),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.w(4),
                      vertical: responsive.h(1),
                    ),
                    child: Column(
                      children: [
                        _SuccessBanner(
                          fare: fare,
                          passenger: passenger,
                          responsive: responsive,
                        ),
                        SizedBox(height: responsive.h(2)),
                        _TripCard(
                          pickup: pickup,
                          dropoff: dropoff,
                          date: when == null ? '—' : _formatDate(when),
                          time: when == null ? '—' : _formatTime(when),
                          fare: fare,
                          responsive: responsive,
                        ),
                        SizedBox(height: responsive.h(2)),
                        _DetailsCard(
                          distance: distance,
                          duration: duration,
                          vehicle: vehicle,
                          passenger: passenger,
                          rating: ride.riderRating,
                          review: ride.riderReview,
                          responsive: responsive,
                        ),
                        SizedBox(height: responsive.h(2)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    responsive.w(4),
                    responsive.h(1),
                    responsive.w(4),
                    responsive.h(1.5),
                  ),
                  child: AppButtonWidget(
                    text: returnToDashboard ? 'Back to dashboard' : 'Done',
                    onPressed: controller.close,
                    backgroundColor: AppColors.dashboardAccent,
                    foregroundColor: AppColors.black,
                    borderRadius: responsive.w(3),
                    showTrailingArrow: false,
                    child: Center(
                      child: Text(
                        returnToDashboard ? 'Back to dashboard' : 'Done',
                        style: AppTextStyles.small(context).copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // Widget _buildHeader(BuildContext context, ResponsiveRepo responsive) {
  //   return Padding(
  //     padding: EdgeInsets.only(
  //       left: responsive.w(4),
  //       right: responsive.w(4),
  //       top: responsive.h(1),
  //       bottom: responsive.h(1),
  //     ),
  //     child: Row(
  //       children: [
  //         AppIconButtonWidget(
  //           icon: Icons.arrow_back,
  //           onPressed: controller.close,
  //           backgroundColor: AppColors.primaryGreen,
  //           iconColor: AppColors.black,
  //           width: responsive.w(10),
  //           height: responsive.h(5),
  //           top: responsive.h(2),
  //           left: responsive.w(4),
  //           borderRadius: responsive.w(3),
  //         ),
  //         SizedBox(width: responsive.w(2.5)),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               FittedBox(
  //                 fit: BoxFit.scaleDown,
  //                 alignment: Alignment.centerLeft,
  //                 child: RichText(
  //                   maxLines: 1,
  //                   text: TextSpan(
  //                     children: [
  //                       TextSpan(
  //                         text: 'Ride ',
  //                         style: AppTextStyles.whiteMedium(context).copyWith(
  //                           color: AppColors.white,
  //                           fontSize: responsive.h(2.4),
  //                           fontWeight: FontWeight.w700,
  //                         ),
  //                       ),
  //                       TextSpan(
  //                         text: AppText.completed,
  //                         style: AppTextStyles.whiteMedium(context).copyWith(
  //                           color: AppColors.primaryGreen,
  //                           fontSize: responsive.h(2.4),
  //                           fontWeight: FontWeight.w700,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //               Text(
  //                 'Trip summary',
  //                 style: AppTextStyles.small(context).copyWith(
  //                   color: AppColors.primaryGreen,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({
    required this.fare,
    required this.passenger,
    required this.responsive,
  });

  final String fare;
  final String passenger;
  final ResponsiveRepo responsive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.w(4),
        vertical: responsive.h(2.4),
      ),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(responsive.w(4)),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: responsive.w(16),
            height: responsive.w(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryGreen.withValues(alpha: 0.16),
            ),
            child: Icon(
              Icons.check_rounded,
              color: AppColors.primaryGreen,
              size: responsive.w(9),
            ),
          ),
          SizedBox(height: responsive.h(1.4)),
          Text(
            'Ride completed',
            style: AppTextStyles.whiteMedium(context).copyWith(
              fontSize: responsive.h(2.2),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: responsive.h(0.4)),
          Text(
            'You dropped off $passenger',
            textAlign: TextAlign.center,
            style: AppTextStyles.small(context).copyWith(
              fontSize: responsive.h(1.45),
              color: AppColors.white.withValues(alpha: 0.65),
            ),
          ),
          SizedBox(height: responsive.h(1.6)),
          Text(
            fare,
            style: AppTextStyles.whiteMedium(context).copyWith(
              fontSize: responsive.h(3.4),
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
          Text(
            'Cash',
            style: AppTextStyles.small(context).copyWith(
              fontSize: responsive.h(1.35),
              color: AppColors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.pickup,
    required this.dropoff,
    required this.date,
    required this.time,
    required this.fare,
    required this.responsive,
  });

  final String pickup;
  final String dropoff;
  final String date;
  final String time;
  final String fare;
  final ResponsiveRepo responsive;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(responsive.w(4));
    final accentWidth = responsive.w(0.8);

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
                  _AddressRow(
                    iconColor: AppColors.primaryGreen,
                    label: AppText.pickup,
                    value: pickup,
                    responsive: responsive,
                  ),
                  SizedBox(height: responsive.h(2.2)),
                  _AddressRow(
                    iconColor: Colors.redAccent,
                    label: AppText.dropOff,
                    value: dropoff,
                    responsive: responsive,
                  ),
                  SizedBox(height: responsive.h(2.2)),
                  Divider(color: AppColors.white.withValues(alpha: 0.10)),
                  SizedBox(height: responsive.h(2)),
                  Row(
                    children: [
                      Expanded(
                        child: _MetaItem(
                          icon: Icons.calendar_month,
                          title: 'Date',
                          value: date,
                          responsive: responsive,
                        ),
                      ),
                      _MetaDivider(responsive: responsive),
                      Expanded(
                        child: _MetaItem(
                          icon: Icons.access_time,
                          title: 'Time',
                          value: time,
                          responsive: responsive,
                        ),
                      ),
                      _MetaDivider(responsive: responsive),
                      Expanded(
                        child: _MetaItem(
                          icon: Icons.payments_outlined,
                          title: AppText.fare,
                          value: fare,
                          responsive: responsive,
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

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.iconColor,
    required this.label,
    required this.value,
    required this.responsive,
  });

  final Color iconColor;
  final String label;
  final String value;
  final ResponsiveRepo responsive;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on, color: iconColor, size: responsive.w(7)),
        SizedBox(width: responsive.w(3)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.small(
                  context,
                ).copyWith(color: iconColor, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: responsive.h(0.4)),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.whiteMedium(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.responsive,
  });

  final IconData icon;
  final String title;
  final String value;
  final ResponsiveRepo responsive;

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
            color: AppColors.white,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _MetaDivider extends StatelessWidget {
  const _MetaDivider({required this.responsive});

  final ResponsiveRepo responsive;

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

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.distance,
    required this.duration,
    required this.vehicle,
    required this.passenger,
    required this.rating,
    required this.review,
    required this.responsive,
  });

  final String distance;
  final String duration;
  final String vehicle;
  final String passenger;
  final int? rating;
  final String review;
  final ResponsiveRepo responsive;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(responsive.w(4));
    final accentWidth = responsive.w(0.8);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.08),
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
                    children: [
                      Container(
                        width: responsive.w(10),
                        height: responsive.w(10),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen,
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.black,
                          size: responsive.w(5),
                        ),
                      ),
                      SizedBox(width: responsive.w(3)),
                      Expanded(
                        child: Text(
                          'Trip details',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.whiteMedium(context).copyWith(
                            fontSize: responsive.h(2.1),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.h(2)),
                  Divider(color: AppColors.white.withValues(alpha: 0.10)),
                  SizedBox(height: responsive.h(2)),
                  _DetailRow(
                    icon: Icons.person_outline,
                    title: 'Passenger',
                    value: passenger,
                    responsive: responsive,
                  ),
                  _RatingRow(
                    rating: rating,
                    review: review,
                    responsive: responsive,
                  ),
                  _DetailRow(
                    icon: Icons.route_outlined,
                    title: 'Distance',
                    value: distance,
                    responsive: responsive,
                  ),
                  // _DetailRow(
                  //   icon: Icons.timer_outlined,
                  //   title: 'Duration',
                  //   value: duration,
                  //   responsive: responsive,
                  // ),
                  _DetailRow(
                    icon: Icons.directions_car_outlined,
                    title: 'Vehicle',
                    value: vehicle,
                    responsive: responsive,
                    isLast: true,
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

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.rating,
    required this.review,
    required this.responsive,
  });

  final int? rating;
  final String review;
  final ResponsiveRepo responsive;

  @override
  Widget build(BuildContext context) {
    final hasRating = rating != null && rating! >= 1 && rating! <= 5;

    return Padding(
      padding: EdgeInsets.only(bottom: responsive.h(2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.star_outline_rounded,
            color: AppColors.primaryGreen,
            size: responsive.w(6),
          ),
          SizedBox(width: responsive.w(3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rating',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small(context).copyWith(
                    color: AppColors.primaryGreen.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: responsive.h(0.4)),
                if (hasRating)
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        final filled = index < rating!;
                        return Padding(
                          padding: EdgeInsets.only(right: responsive.w(0.6)),
                          child: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: filled
                                ? AppColors.primaryGreen
                                : AppColors.white.withValues(alpha: 0.28),
                            size: responsive.w(5),
                          ),
                        );
                      }),
                      SizedBox(width: responsive.w(1.5)),
                      Text(
                        '$rating / 5',
                        style: AppTextStyles.small(context).copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Waiting for passenger',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.small(
                      context,
                    ).copyWith(color: AppColors.white.withValues(alpha: 0.70)),
                  ),
                if (review.trim().isNotEmpty) ...[
                  SizedBox(height: responsive.h(0.6)),
                  Text(
                    review.trim(),
                    style: AppTextStyles.small(context).copyWith(
                      color: AppColors.white.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.responsive,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final ResponsiveRepo responsive;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : responsive.h(2)),
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
                  maxLines: 2,
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
