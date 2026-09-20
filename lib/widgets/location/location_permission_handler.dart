import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/location_permission_controller.dart';
import 'location_permission_banner.dart';

/// Keeps [child] mounted and overlays a permission banner when location
/// cannot be used — never replaces the child (avoids GoogleMap remount flash).
class LocationPermissionHandler extends StatelessWidget {
  const LocationPermissionHandler({
    super.key,
    required this.child,
    this.bannerTop = 8,
    this.onEnabled,
  });

  final Widget child;
  final double bannerTop;
  final Future<void> Function()? onEnabled;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<LocationPermissionController>()) {
      return child;
    }

    final location = Get.find<LocationPermissionController>();

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Obx(() {
          if (location.canUseLocation.value) {
            return const SizedBox.shrink();
          }
          return LocationPermissionBanner(
            top: bannerTop,
            onEnabled: onEnabled,
          );
        }),
      ],
    );
  }
}
