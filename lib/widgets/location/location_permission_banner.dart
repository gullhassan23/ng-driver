import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/location_permission_controller.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text.dart';
import '../../utilis/app_text_styles.dart';

/// Sticky top snackbar: tap to turn on location.
class LocationPermissionBanner extends StatelessWidget {
  const LocationPermissionBanner({
    super.key,
    this.top,
    this.onEnabled,
  });

  /// When null, sits just below the status bar.
  final double? top;
  final Future<void> Function()? onEnabled;

  Future<void> _onTap() async {
    if (!Get.isRegistered<LocationPermissionController>()) return;
    final location = Get.find<LocationPermissionController>();
    final granted = await location.enableLocation();
    if (!granted && !location.canUseLocation.value) return;
    await onEnabled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final offset = top ?? MediaQuery.paddingOf(context).top + 8;

    return Positioned(
      top: offset,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Colors.black87,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppText.tapToTurnOnLocation,
                      style: AppTextStyles.small(context).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
