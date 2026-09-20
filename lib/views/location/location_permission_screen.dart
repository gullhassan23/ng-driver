import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/location_permission_controller.dart';
import '../../routes/app_routes.dart';
import '../../services/map_warmup_service.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text.dart';
import '../../utilis/app_text_styles.dart';
import '../../widgets/buttons/app_button_widget.dart';

/// Full-screen prompt when location permission / service is unavailable.
class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with WidgetsBindingObserver {
  final LocationPermissionController _location =
      Get.find<LocationPermissionController>();

  Worker? _grantedWorker;
  bool _leaving = false;

  String get _nextRoute {
    final args = Get.arguments;
    if (args is String && args.isNotEmpty) return args;
    return AppRoutes.dashboard;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _grantedWorker = ever(_location.permission, (_) {
      _continueIfGranted();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _grantedWorker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResumed());
    }
  }

  Future<void> _bootstrap() async {
    await _location.ensureStatus();
    if (!mounted) return;
    if (_continueIfGranted()) return;

    if (!_location.isPermanentlyDenied) {
      final granted = await _location.enableLocation(openSettings: false);
      if (granted && mounted) {
        _continueIfGranted();
      }
    }
  }

  bool _continueIfGranted() {
    if (_leaving || !mounted || !_location.isGranted) return false;
    _leaving = true;
    if (Get.isRegistered<MapWarmupService>()) {
      Get.find<MapWarmupService>().warmInBackground(requestPermission: false);
    }
    Get.offAllNamed(_nextRoute);
    return true;
  }

  Future<void> _onResumed() async {
    await _location.onAppResumed();
    if (mounted) _continueIfGranted();
  }

  Future<void> _onEnable() async {
    final granted = await _location.enableLocation();
    if (granted && mounted) {
      _continueIfGranted();
    }
  }

  void _onSkip() {
    Get.offAllNamed(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Image.asset(
                      'assets/images/map_icon.webp',
                      height: MediaQuery.sizeOf(context).height * 0.32,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(flex: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppText.turnLocationOn,
                        style: AppTextStyles.medium(context).copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppText.locationPermissionBody,
                        style: AppTextStyles.small(context).copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
              ),
              Obx(() {
                final busy = _location.isRequesting.value;
                return AppButtonWidget(
                  text: AppText.enableLocationServices,
                  onPressed: busy ? null : _onEnable,
                  showTrailingArrow: false,
                  borderRadius: 14,
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.black,
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _onSkip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A2A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    AppText.skip,
                    style: AppTextStyles.medium(context).copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: bottom > 0 ? 8 : 16),
            ],
          ),
        ),
      ),
    );
  }
}
