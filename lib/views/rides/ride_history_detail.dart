import 'package:flutter/material.dart';

import 'package:ngtowncardriver/models/ride_model.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';

import 'package:ngtowncardriver/utilis/firestore_paths.dart';

import 'package:ngtowncardriver/widgets/app_ride_history_widget.dart';
import 'package:ngtowncardriver/widgets/header/header.dart';

class RideHistoryDetailView extends StatelessWidget {
  const RideHistoryDetailView({super.key, required this.ride});

  final RideModel ride;

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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
    final when = ride.completedAt ?? ride.updatedAt ?? ride.createdAt;
    final isCancelled =
        RideStatus.normalize(ride.status) == RideStatus.cancelled;

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,

      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: responsive.w(3)),
          children: [
            AppHeader(
              responsive: responsive,
              title: AppText.ride,
              subtitle: AppText.details,
              canPop: true,
            ),
            SizedBox(height: responsive.h(1)),
            AppRideHistoryCardWidget(
              pickupLocation: ride.pickupLocation.isEmpty
                  ? 'Pickup'
                  : ride.pickupLocation,
              dropOffLocation: ride.dropoffLocation.isEmpty
                  ? 'Drop-off'
                  : ride.dropoffLocation,
              stopLocations: ride.stops
                  .map(
                    (stop) => stop.location.trim().isEmpty
                        ? 'Stop ${stop.order}'
                        : stop.location,
                  )
                  .toList(),
              date: when == null ? '—' : _formatDate(when),
              time: when == null ? '' : _formatTime(when),
              fare: ride.formattedFare,
              distance: ride.formattedDistance,
              duration: ride.formattedDuration,
              status: isCancelled ? 'Cancelled' : 'Completed',
              isCancelled: isCancelled,
            ),
          ],
        ),
      ),
    );
  }
}
