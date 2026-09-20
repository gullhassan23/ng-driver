import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/dashboard_controller.dart';
import '../../controllers/location_permission_controller.dart';
import '../../controllers/ride_request_preview_controller.dart';
import '../../models/ride_model.dart';
import '../../services/directions_service.dart';
import '../../services/location_service.dart';
import '../../utilis/app_colors.dart';
import '../../widgets/location/location_permission_banner.dart';
import '../../widgets/reactive_app_map.dart';

/// Opens the ride-request map bottom sheet for [ride].
Future<void> openRideRequestPreview(RideModel ride) async {
  if (Get.isRegistered<RideRequestPreviewController>()) {
    Get.delete<RideRequestPreviewController>(force: true);
  }

  Get.put(
    RideRequestPreviewController(
      ride: ride,
      location: Get.isRegistered<LocationService>()
          ? Get.find<LocationService>()
          : null,
      directions: Get.isRegistered<DirectionsService>()
          ? Get.find<DirectionsService>()
          : null,
    ),
    permanent: false,
  );

  await Get.bottomSheet(
    const RideRequestPreviewSheet(),
    isScrollControlled: true,
    enableDrag: false,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
  );

  if (Get.isRegistered<RideRequestPreviewController>()) {
    Get.delete<RideRequestPreviewController>(force: true);
  }
}

class RideRequestPreviewSheet extends GetView<RideRequestPreviewController> {
  const RideRequestPreviewSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height;
    final maxSheetHeight = height * 0.55;
    // Capture outside Obx so marker/polyline updates never re-read camera seed.
    final initialPosition = controller.initialCameraTarget;

    return SizedBox(
      height: height * 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Scaffold(
          backgroundColor: AppColors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: ReactiveAppMap(
                    key: const ValueKey('ride_request_preview_map'),
                    initialPosition: initialPosition,
                    markers: controller.markers,
                    polylines: controller.polylines,
                    zoomControlsEnabled: true,
                    myLocationEnabled: false,
                    onMapCreated: controller.onMapCreated,
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Get.back(),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.white,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Ride request',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: AppColors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
                    Obx(() {
                      if (!Get.isRegistered<LocationPermissionController>()) {
                        return const SizedBox.shrink();
                      }
                      final location =
                          Get.find<LocationPermissionController>();
                      if (location.canUseLocation.value) {
                        return const SizedBox.shrink();
                      }
                      return LocationPermissionBanner(
                        top: MediaQuery.paddingOf(context).top + 56,
                      );
                    }),
                    Obx(() {
                      if (!controller.isRouteLoading.value) {
                        return const SizedBox.shrink();
                      }
                      return const Align(
                        alignment: Alignment(0, -0.15),
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                          strokeWidth: 2.5,
                        ),
                      );
                    }),
                    Obx(() {
                      final distance = controller.routeDistanceText.value;
                      final duration = controller.routeDurationText.value;
                      if (distance.isEmpty && duration.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: const Alignment(0, -0.05),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            [
                              if (duration.isNotEmpty) duration,
                              if (distance.isNotEmpty) distance,
                            ].join(' · '),
                            style: GoogleFonts.inter(
                              color: AppColors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxSheetHeight),
                        child: _PreviewDetailPanel(
                          ride: controller.ride,
                          bottomInset: bottomInset,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewDetailPanel extends StatelessWidget {
  const _PreviewDetailPanel({
    required this.ride,
    required this.bottomInset,
  });

  final RideModel ride;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final dashboard = Get.find<DashboardController>();
    final preview = Get.find<RideRequestPreviewController>();
    final name = ride.customerName.isEmpty ? 'Customer' : ride.customerName;
    final distance = ride.formattedDistance;
    final fare = ride.formattedFare.isEmpty ? 'Cash' : ride.formattedFare;
    final acceptLabel =
        ride.formattedFare.isEmpty ? 'Accept' : 'Accept for $fare';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF3A3A3C),
                        child: Icon(
                          Icons.person_rounded,
                          color: AppColors.white.withValues(alpha: 0.55),
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (ride.hasRiderRating) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFBBF24),
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              ride.formattedRating,
                              style: GoogleFonts.inter(
                                color: AppColors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _relativeTime(ride.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (distance.isNotEmpty)
                              Text(
                                distance,
                                style: GoogleFonts.inter(
                                  color: AppColors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            Text(
                              fare,
                              style: GoogleFonts.inter(
                                color: AppColors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _AddressRow(
                        asset: 'assets/images/location.webp',
                        text: ride.pickupLocation.isEmpty
                            ? 'Pickup'
                            : ride.pickupLocation,
                      ),
                      for (var i = 0; i < ride.stops.length; i++) ...[
                        const SizedBox(height: 10),
                        _AddressRow(
                          asset: 'assets/images/stop.png',
                          text: ride.stops[i].location.trim().isEmpty
                              ? 'Stop ${i + 1}'
                              : 'Stop ${i + 1} · ${ride.stops[i].location}',
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
              ],
            ),
            const SizedBox(height: 18),
            Obx(() {
              final busy = dashboard.isAccepting.value;
              final acceptingThis =
                  busy && dashboard.acceptingRideId.value == ride.id;
              final claimable = preview.isClaimable.value;

              return SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (!claimable || busy)
                      ? null
                      : () => dashboard.acceptRide(preview.ride),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    disabledBackgroundColor:
                        AppColors.primaryGreen.withValues(alpha: 0.45),
                    foregroundColor: AppColors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: acceptingThis
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.black,
                          ),
                        )
                      : Text(
                          acceptLabel,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              );
            }),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: TextButton(
                onPressed: () => Get.back(),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF2C2C2E),
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    required this.asset,
    required this.text,
  });

  final String asset;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          asset,
          width: 26,
          height: 26,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

String _relativeTime(DateTime? createdAt) {
  if (createdAt == null) return '';

  final diff = DateTime.now().difference(createdAt);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min.';
  if (diff.inHours < 24) return '${diff.inHours} hr.';
  return '${diff.inDays}d';
}
