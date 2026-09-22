import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ngtowncardriver/constants/global.dart';
import 'package:ngtowncardriver/views/rides/distance_time_card.dart';
import 'package:ngtowncardriver/views/rides/map_button.dart';
import 'package:ngtowncardriver/views/rides/ride_arrived_banner.dart';
import 'package:ngtowncardriver/views/rides/safery_banner.dart';
import 'package:ngtowncardriver/widgets/address/address_row.dart';
import 'package:ngtowncardriver/widgets/ride/cancel_button.dart';
import 'package:ngtowncardriver/widgets/ride/chat_button.dart';
import 'package:ngtowncardriver/widgets/ride/primary_button.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../controllers/active_ride_controller.dart';
import '../../controllers/location_permission_controller.dart';
import '../../routes/app_routes.dart';
import '../../utilis/app_colors.dart';
import '../../widgets/location/location_permission_banner.dart';
import '../../widgets/reactive_app_map.dart';



class ActiveRideView extends GetView<ActiveRideController> {
  const ActiveRideView({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.55;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.black,
        // Gate only on loading/error. Nested builders must not run inside this
        // Obx or ride/GPS snapshots remount GoogleMap (black screen).
        body: Obx(() {
          final loading = controller.isLoading.value;
          final error = controller.errorMessage.value;
          if (loading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }
          if (error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.white),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Get.offAllNamed(AppRoutes.dashboard),
                      child: const Text('Back to dashboard'),
                    ),
                  ],
                ),
              ),
            );
          }
          // Stable key so loading-gate Obx rebuilds do not remount the map.
          return _ActiveRideStack(
            key: const ValueKey('active_ride_stack'),
            bottomInset: bottomInset,
            maxSheetHeight: maxSheetHeight,
          );
        }),
      ),
    );
  }
}

/// Stable map + overlays. Owns its own Obx scopes so status/GPS updates never
/// remount [GoogleMap] via the parent loading gate.
class _ActiveRideStack extends GetView<ActiveRideController> {
  const _ActiveRideStack({
    super.key,
    required this.bottomInset,
    required this.maxSheetHeight,
  });

  final double bottomInset;
  final double maxSheetHeight;

  @override
  Widget build(BuildContext context) {
    // Capture outside Obx — getter does not read .obs fields.
    final initialPosition = controller.initialCameraTarget;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: ReactiveAppMap(
              key: const ValueKey('active_ride_map'),
              initialPosition: initialPosition,
              markers: controller.markers,
              polylines: controller.polylines,
              // Custom driver marker replaces the native blue dot.
              myLocationEnabled: false,
              onMapCreated: controller.onMapCreated,
              onCameraMoveStarted: controller.onCameraMoveStartedByUser,
              onTap: (_) => controller.onCameraMoveStartedByUser(),
            ),
          ),
        ),
        // Overlays must live in a Material layer above the GoogleMap platform
        // view. Without this, Android hybrid composition hides the sheet and
        // paints Start Ride / close at the top-left after driver_arrived.
        // Keep this ancestor transparent so map gestures pass through; the
        // bottom sheet uses a 1-alpha color so buttons composite on Android.
        Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Obx(() {
                if (!Get.isRegistered<LocationPermissionController>()) {
                  return const SizedBox.shrink();
                }
                final location = Get.find<LocationPermissionController>();
                if (location.canUseLocation.value) {
                  return const SizedBox.shrink();
                }
                return const LocationPermissionBanner();
              }),
              Align(
                alignment: Alignment.bottomCenter,
                child: Obx(() {
                  final ride = controller.ride.value;
                  if (ride == null) return const SizedBox.shrink();

                  return Material(
                    color: const Color(0x01000000),
                    child: SafeArea(
                      top: false,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxSheetHeight),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (controller.showRiderArrivedBanner)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: RiderArrivedBanner(),
                              ),
                            if (controller.routeEtaText.value.isNotEmpty ||
                                controller.routeDistanceText.value.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
                                child: RouteMetaChip(
                                  eta: controller.routeEtaText.value,
                                  distance: controller.routeDistanceText.value,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  RoundMapButton(
                                    icon: Icons.near_me_rounded,
                                    background: AppColors.white,
                                    iconColor: AppColors.black,
                                    onTap: controller.openExternalNavigation,
                                  ),
                                  const SizedBox(width: 10),
                                  Obx(() {
                                    final showRecenter =
                                        !controller.isFollowingDriver.value;
                                    return IgnorePointer(
                                      ignoring: !showRecenter,
                                      child: Opacity(
                                        opacity: showRecenter ? 1 : 0,
                                        child: ClipRect(
                                          child: SizedBox(
                                            width: showRecenter ? 54 : 0,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 10,
                                              ),
                                              child: RoundMapButton(
                                                icon: Icons.my_location_rounded,
                                                background:
                                                    AppColors.primaryGreen,
                                                iconColor: AppColors.black,
                                                onTap:
                                                    controller.recenterOnDriver,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  Expanded(
                                    child: SafetyBanner(
                                      onTap: () async {
                                        final trimmed =
                                            AppConfig.driverPoliciesUrl.trim();
                                        if (trimmed.isEmpty) return;

                                        final uri = Uri.tryParse(trimmed);
                                        if (uri == null || !uri.hasScheme) {
                                          return;
                                        }

                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // _RoundMapButton(
                                  //   icon: Icons.reply_rounded,
                                  //   background: AppColors.black,
                                  //   iconColor: AppColors.white,
                                  //   onTap: controller.openExternalNavigation,
                                  // ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              padding: EdgeInsets.fromLTRB(
                                16,
                                18,
                                16,
                                16 + bottomInset,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 72,
                                        child: Column(
                                          children: [
                                            CircleAvatar(
                                              radius: 28,
                                              backgroundColor: const Color(
                                                0xFF3A3A3C,
                                              ),
                                              child: Text(
                                                initials(ride.customerName),
                                                style: GoogleFonts.inter(
                                                  color: AppColors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              ride.customerName.isEmpty
                                                  ? 'Passenger'
                                                  : ride.customerName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                color: AppColors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            AddressRow(
                                              asset:
                                                  'assets/images/location.webp',
                                              text: ride.pickupLocation.isEmpty
                                                  ? 'Pickup'
                                                  : ride.pickupLocation,
                                            ),
                                            for (var i = 0;
                                                i < ride.stops.length;
                                                i++) ...[
                                              const SizedBox(height: 10),
                                              AddressRow(
                                                asset:
                                                    'assets/images/stop.png',
                                                text: stopRowText(ride, i),
                                              ),
                                            ],
                                            const SizedBox(height: 10),
                                            AddressRow(
                                              asset: 'assets/images/flag.webp',
                                              text: ride.dropoffLocation.isEmpty
                                                  ? 'Dropoff'
                                                  : ride.dropoffLocation,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        children: [
                                      
                                          Obx(
                                            () => LimeActionButton(
                                              icon: Icons.chat_bubble_rounded,
                                              onTap: controller.openChat,
                                              badgeCount: controller
                                                  .chatUnreadCount
                                                  .value,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.payments_outlined,
                                        color: AppColors.primaryGreen,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        ride.formattedFarePkr,
                                        style: GoogleFonts.inter(
                                          color: AppColors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      if (controller.showPrimaryCta) ...[
                                        Expanded(
                                          child: PrimaryCtaButton(
                                            label: controller.primaryCtaLabel,
                                            loading:
                                                controller.isUpdating.value,
                                            showProgressTint:
                                                !controller.isRideStarted,
                                            onTap: controller.onPrimaryCta,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ] else if (controller.isRideStarted) ...[
                                        Expanded(
                                          child: Container(
                                            height: 52,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2C2C2E),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              controller.statusLabel,
                                              style: GoogleFonts.inter(
                                                color: AppColors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ] else if (controller
                                          .showWaitingForPassenger) ...[
                                        Expanded(
                                          child: Container(
                                            height: 52,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2C2C2E),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Waiting for passenger…',
                                              style: GoogleFonts.inter(
                                                color: AppColors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ] else if (controller
                                          .isDriverArriving) ...[
                                        Expanded(
                                          child: Container(
                                            height: 52,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2C2C2E),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Heading to pickup…',
                                              style: GoogleFonts.inter(
                                                color: AppColors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      CancelSquareButton(
                                        onTap: controller.isUpdating.value
                                            ? null
                                            : controller.onCancelRide,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

















}
