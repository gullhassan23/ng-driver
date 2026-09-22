import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:ngtowncardriver/controllers/auth_controller.dart';
import 'package:ngtowncardriver/controllers/connectivity_controller.dart';
import 'package:ngtowncardriver/controllers/location_permission_controller.dart';
import 'package:ngtowncardriver/config/app_config.dart';
import 'package:ngtowncardriver/firebase_options.dart';
import 'package:ngtowncardriver/routes/app_pages.dart';
import 'package:ngtowncardriver/routes/app_routes.dart';
import 'package:ngtowncardriver/services/directions_service.dart';
import 'package:ngtowncardriver/services/location_service.dart';
import 'package:ngtowncardriver/services/map_warmup_service.dart';
import 'package:ngtowncardriver/services/notification_service.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_theme.dart';
import 'package:ngtowncardriver/widgets/connectivity/no_internet_overlay.dart';

Future<void> _configureGoogleMaps() async {
  if (kIsWeb) return;
  final platform = GoogleMapsFlutterPlatform.instance;
  if (platform is GoogleMapsFlutterAndroid) {
    // Hybrid composition keeps Flutter overlays (sheet, Start Ride) on top of
    // the map instead of letting the platform view swallow / misplace them.
    platform.useAndroidViewSurface = true;
    try {
      await platform.initializeWithRenderer(AndroidMapRenderer.latest);
    } catch (error) {
      debugPrint('Google Maps renderer init failed: $error');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureGoogleMaps();

  await dotenv.load(fileName: '.env', isOptional: true);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    debugPrint(
      'Firebase connected to project: ${Firebase.app().options.projectId}',
    );
    debugPrint('Google Maps API key loaded: ${AppConfig.hasGoogleMapsApiKey}');
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.dashboardBackground,
      systemNavigationBarDividerColor: AppColors.dashboardBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const NgTownDriverApp());
}

class NgTownDriverApp extends StatelessWidget {
  const NgTownDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'NG Town Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.sessionRestore,
      getPages: AppPages.pages,
      initialBinding: BindingsBuilder(() {
        Get.put<AuthController>(AuthController(), permanent: true);
        Get.put<ConnectivityController>(
          ConnectivityController(),
          permanent: true,
        );
        Get.put<LocationPermissionController>(
          LocationPermissionController(),
          permanent: true,
        );
        Get.put<LocationService>(LocationService(), permanent: true);
        Get.put<DirectionsService>(DirectionsService(), permanent: true);
        final mapWarmup = Get.put<MapWarmupService>(
          MapWarmupService(),
          permanent: true,
        );
        // Non-blocking: icons + last-known GPS (no streams / Directions).
        mapWarmup.warmInBackground(requestPermission: false);
      }),
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            Obx(() {
              final connectivity = Get.find<ConnectivityController>();
              if (connectivity.hasInternet.value) {
                return const SizedBox.shrink();
              }
              // Active Ride keeps CTAs usable — soft banner instead of block.
              final onActiveRide = Get.currentRoute == AppRoutes.activeRide;
              if (onActiveRide) {
                return const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(bottom: false, child: OfflineBanner()),
                );
              }
              return const Positioned.fill(child: NoInternetOverlay());
            }),
          ],
        );
      },
    );
  }
}
