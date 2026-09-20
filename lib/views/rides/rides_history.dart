import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/controllers/rides_history_controller.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';
import 'package:ngtowncardriver/utilis/firestore_paths.dart';
import 'package:ngtowncardriver/widgets/app_icon_button_widget.dart';
import 'package:ngtowncardriver/widgets/app_ride_history_widget.dart';

class RidesHistory extends GetView<RidesHistoryController> {
  const RidesHistory({super.key});

  static const _filters = ['All', 'Completed', 'Cancelled'];

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
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, responsive),
            SizedBox(height: responsive.h(2)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: responsive.w(3)),
              child: Obx(
                () => _RideHistoryFilter(
                  labels: _filters,
                  selectedIndex: controller.selectedFilter.value,
                  onChanged: controller.selectFilter,
                ),
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

                final rides = controller.filteredRides;

                if (rides.isEmpty) {
                  return Center(
                    child: Text(
                      'No rides found',
                      style: AppTextStyles.whiteSmall(context),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: responsive.w(3)),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final ride = rides[index];
                    final when =
                        ride.completedAt ?? ride.updatedAt ?? ride.createdAt;
                    final isCancelled =
                        RideStatus.normalize(ride.status) ==
                        RideStatus.cancelled;

                    return AppRideHistoryCardWidget(
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
                      onTap: () => controller.openDetail(ride),
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

  Widget _buildHeader(BuildContext context, ResponsiveRepo responsive) {
    return Padding(
      padding: EdgeInsets.only(
        left: responsive.w(3),
        right: responsive.w(3),
        top: responsive.h(1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconButtonWidget(
            icon: Icons.arrow_back,
            onPressed: () => Get.back(),
            backgroundColor: AppColors.primaryGreen,
            iconColor: AppColors.black,
            width: responsive.w(10),
            height: responsive.w(10),
            borderRadius: responsive.w(3),
          ),
          SizedBox(width: responsive.w(3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: AppText.ride,
                        style: AppTextStyles.large(context).copyWith(
                          color: AppColors.white,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: AppText.history,
                        style: AppTextStyles.large(context).copyWith(
                          color: AppColors.primaryGreen,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: responsive.h(0.2)),
                Text(
                  AppText.rideHistorySubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.whiteSmall(context).copyWith(
                    fontSize: responsive.h(1.45),
                    color: AppColors.progressInactive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RideHistoryFilter extends StatelessWidget {
  const _RideHistoryFilter({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Row(
      children: List.generate(labels.length, (index) {
        final selected = index == selectedIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == labels.length - 1 ? 0 : responsive.w(2),
            ),
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: Container(
                height: responsive.h(4.6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryGreen
                      : AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[index],
                  style: AppTextStyles.whiteSmall(context).copyWith(
                    color: selected ? AppColors.black : AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
