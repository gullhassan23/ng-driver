import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../controllers/dashboard_controller.dart';
import '../../models/ride_model.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text_styles.dart';
import '../../widgets/location/location_permission_handler.dart';
import '../../widgets/online_status_toggle.dart';
import 'ride_request_preview_sheet.dart';

class RidePending extends StatefulWidget {
  const RidePending({super.key});

  @override
  State<RidePending> createState() => _RidePendingState();
}

class _RidePendingState extends State<RidePending> with WidgetsBindingObserver {
  DashboardController get controller => Get.find<DashboardController>();

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
      controller.onAppResumed(forMode: DriverOnlineMode.ride);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      appBar: AppBar(
        backgroundColor: AppColors.dashboardBackground,
        elevation: 0,
        centerTitle: true,
        title: Obx(
          () => OnlineStatusToggle(
            isOnline: controller.isRideOnline,
            isBusy: controller.isTogglingOnline.value,
            onTap: controller.toggleRideOnline,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: LocationPermissionHandler(
        onEnabled: () => controller.onAppResumed(forMode: DriverOnlineMode.ride),
        child: Obx(() {
        final online = controller.isRideOnline;
        if (!online) {
          return Center(
            child: Text(
              'You are offline',
              style: AppTextStyles.medium(
                context,
              ).copyWith(color: AppColors.white, fontWeight: FontWeight.w600),
            ),
          );
        }

        final loading = controller.isLoading.value;
        if (loading) {
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
                    'Could not load rides',
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

        // List body reacts only to rides / accept state — not the whole scaffold.
        return const _PendingRidesBody();
      }),
      ),
    );
  }
}

class _PendingRidesBody extends GetView<DashboardController> {
  const _PendingRidesBody();

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Obx(() {
      final rides = controller.rides.toList();

      if (rides.isEmpty) {
        return SizedBox.expand(
          child: Lottie.asset(
            'assets/lottie/map_lottie.json',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            repeat: true,
          ),
        );
      }

      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          responsive.w(4),
          responsive.h(1),
          responsive.w(4),
          responsive.h(3),
        ),
        itemCount: rides.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.white.withValues(alpha: 0.12),
        ),
        itemBuilder: (context, index) {
          final ride = rides[index];
          return _PendingRideCard(
            key: ValueKey(ride.id),
            ride: ride,
            controller: controller,
          );
        },
      );
    });
  }
}

class _PendingRideCard extends StatelessWidget {
  const _PendingRideCard({
    super.key,
    required this.ride,
    required this.controller,
  });

  final RideModel ride;
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
    final name = ride.customerName.isEmpty ? 'Customer' : ride.customerName;
    final distance = ride.formattedDistance;
    final pickup = ride.pickupLocation;
    final dropoff = ride.dropoffLocation;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsive.h(1.6)),
      child: Obx(() {
        final busy = controller.isAccepting.value;
        final acceptingThis =
            busy && controller.acceptingRideId.value == ride.id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Swipe targets info only — buttons stay outside Dismissible
            // so Accept/Dismiss taps are never stolen by the drag arena.
            // While any accept is in flight, block swipe on all cards.
            IgnorePointer(
              ignoring: busy,
              child: Dismissible(
                key: ValueKey('dismiss_${ride.id}'),
                direction: DismissDirection.horizontal,
                dismissThresholds: const {
                  DismissDirection.startToEnd: 0.30,
                  DismissDirection.endToStart: 0.30,
                },
                confirmDismiss: (direction) async {
                  if (controller.isAccepting.value) return false;
                  if (direction == DismissDirection.startToEnd) {
                    return controller.dismissRide(ride);
                  }
                  if (direction == DismissDirection.endToStart) {
                    return controller.acceptRide(ride);
                  }
                  return false;
                },
                background: Container(
                  color: AppColors.secondaryRed,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.only(left: responsive.w(5)),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.white,
                    size: responsive.w(6),
                  ),
                ),
                secondaryBackground: Container(
                  color: AppColors.primaryGreen,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: responsive.w(5)),
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.black,
                    size: responsive.w(6),
                  ),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: busy ? null : () => openRideRequestPreview(ride),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: responsive.w(18),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: responsive.w(5.5),
                              backgroundColor: AppColors.inputBackground,
                              child: Icon(
                                Icons.person_rounded,
                                color: AppColors.white.withValues(alpha: 0.55),
                                size: responsive.w(6),
                              ),
                            ),
                            SizedBox(height: responsive.h(0.6)),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.small(context).copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: responsive.h(0.4)),
                            Text(
                              _relativeTime(ride.createdAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.small(context).copyWith(
                                color: AppColors.white.withValues(alpha: 0.45),
                                fontSize: responsive.h(1.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: responsive.w(3)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (distance.isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  distance,
                                  style: AppTextStyles.small(context).copyWith(
                                    color: AppColors.white.withValues(
                                      alpha: 0.5,
                                    ),
                                    fontSize: responsive.h(1.3),
                                  ),
                                ),
                              ),
                            Text(
                              ride.formattedFare,
                              style: AppTextStyles.large(context).copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (pickup.isNotEmpty) ...[
                              SizedBox(height: responsive.h(0.5)),
                              Text(
                                pickup,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.small(context).copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (ride.hasStops) ...[
                              SizedBox(height: responsive.h(0.3)),
                              Text(
                                ride.stops.length == 1
                                    ? '1 stop'
                                    : '${ride.stops.length} stops',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.small(context).copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: responsive.h(1.3),
                                ),
                              ),
                            ],
                            if (dropoff.isNotEmpty) ...[
                              SizedBox(height: responsive.h(0.3)),
                              Text(
                                dropoff,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.small(context).copyWith(
                                  color: AppColors.white.withValues(
                                    alpha: 0.75,
                                  ),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: responsive.h(1.2)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => controller.dismissRide(ride),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      disabledForegroundColor: AppColors.white.withValues(
                        alpha: 0.35,
                      ),
                      side: BorderSide(
                        color: AppColors.white.withValues(
                          alpha: busy ? 0.15 : 0.35,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.h(1.2),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                SizedBox(width: responsive.w(3)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : () => controller.acceptRide(ride),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      disabledBackgroundColor: AppColors.primaryGreen
                          .withValues(alpha: 0.45),
                      foregroundColor: AppColors.black,
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.h(1.2),
                      ),
                    ),
                    child: acceptingThis
                        ? SizedBox(
                            height: responsive.h(2),
                            width: responsive.h(2),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.black,
                            ),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

String _relativeTime(DateTime? createdAt) {
  if (createdAt == null) return '';

  final diff = DateTime.now().difference(createdAt);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
}
