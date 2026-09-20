import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../controllers/active_ride_controller.dart';
import '../../controllers/location_permission_controller.dart';
import '../../models/ride_model.dart';
import '../../routes/app_routes.dart';
import '../../utilis/app_colors.dart';
import '../../widgets/location/location_permission_banner.dart';
import '../../widgets/reactive_app_map.dart';

String _stopRowText(RideModel ride, int index) {
  if (index < 0 || index >= ride.stops.length) return 'Stop';
  final address = ride.stops[index].location.trim();
  final label = address.isEmpty ? 'Stop ${index + 1}' : address;
  if (!ride.isTripInProgress) return 'Stop ${index + 1} · $label';
  if (index < ride.currentStopIndex) return 'Stop ${index + 1} ✓ · $label';
  if (index == ride.currentStopIndex) {
    return 'Stop ${index + 1} · Current · $label';
  }
  return 'Stop ${index + 1} · $label';
}

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
                                child: _RiderArrivedBanner(),
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
                                child: _RouteMetaChip(
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
                                  _RoundMapButton(
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
                                              child: _RoundMapButton(
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
                                    child: _SafetyBanner(
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
                                                _initials(ride.customerName),
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
                                            _AddressRow(
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
                                              _AddressRow(
                                                asset:
                                                    'assets/images/stop.png',
                                                text: _stopRowText(ride, i),
                                              ),
                                            ],
                                            const SizedBox(height: 10),
                                            _AddressRow(
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
                                          // _LimeActionButton(
                                          //   icon: Icons.phone_rounded,
                                          //   onTap:
                                          //       controller.onContactUnavailable,
                                          // ),
                                          Obx(
                                            () => _LimeActionButton(
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
                                          child: _PrimaryCtaButton(
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
                                      _CancelSquareButton(
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _RiderArrivedBanner extends StatelessWidget {
  const _RiderArrivedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF163A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passenger has arrived',
            style: GoogleFonts.inter(
              color: AppColors.primaryGreen,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your passenger has arrived at the pickup location.',
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMetaChip extends StatelessWidget {
  const _RouteMetaChip({required this.eta, required this.distance});

  final String eta;
  final String distance;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (eta.isNotEmpty) eta,
      if (distance.isNotEmpty) distance,
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          parts.join(' · '),
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2C2C2E),
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onTap: onTap,
        // borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Learn more how we protect you during rides',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      surfaceTintColor: Colors.transparent,
      shape: const CircleBorder(),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        // customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.asset, required this.text});

  final String asset;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(asset, width: 26, height: 26, fit: BoxFit.contain),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _LimeActionButton extends StatelessWidget {
  const _LimeActionButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount > 0;
    final label = badgeCount > 99 ? '99+' : '$badgeCount';

    return Material(
      color: AppColors.primaryGreen,
      shape: const CircleBorder(),
      child: GestureDetector(
        // customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, color: AppColors.black, size: 22),
              if (showBadge)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: AppColors.dashboardBackground,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryCtaButton extends StatelessWidget {
  const _PrimaryCtaButton({
    required this.label,
    required this.loading,
    required this.showProgressTint,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final bool showProgressTint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isStartRide = showProgressTint;
    final background = isStartRide
        ? AppColors.primaryGreen
        : const Color(0xFF2F6FED);
    final foreground = isStartRide ? AppColors.black : AppColors.white;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        onTap: loading ? null : onTap,
        // borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: foreground,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.inter(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CancelSquareButton extends StatelessWidget {
  const _CancelSquareButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2C2C2E),
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        onTap: onTap,
        // borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            Icons.close_rounded,
            color: AppColors.primaryRed,
            size: 26,
          ),
        ),
      ),
    );
  }
}
