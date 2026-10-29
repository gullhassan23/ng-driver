import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide configuration values loaded from environment / dart-define.
class AppConfig {
  AppConfig._();

  static const String _mapsKeyEnv = 'GOOGLE_MAPS_API_KEY';
  static const String _mapsKeyAndroidEnv = 'GOOGLE_MAPS_API_KEY_ANDROID';
  static const String _mapsKeyIosEnv = 'GOOGLE_MAPS_API_KEY_IOS';
  static const String _privacyPolicyUrlEnv = 'PRIVACY_POLICY_URL';
  static const String _termsAndConditionsUrlEnv = 'TERMS_AND_CONDITIONS_URL';
  static const String _driverPoliciesUrlEnv = 'DRIVER_POLICIES';

  /// Google Maps API key (Maps SDK + Routes API `computeRoutes`).
  /// Prefers platform-specific keys (`GOOGLE_MAPS_API_KEY_ANDROID` / `GOOGLE_MAPS_API_KEY_IOS`),
  /// falling back to generic `GOOGLE_MAPS_API_KEY` from `.env` or `--dart-define`.
  /// Enable **Routes API** on the Cloud project for this key (not Directions API Legacy).
  static String get googleMapsApiKey {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (dotenv.isInitialized) {
        final fromPlatform = dotenv.env[_mapsKeyAndroidEnv]?.trim();
        if (fromPlatform != null && fromPlatform.isNotEmpty) return fromPlatform;
      }
      const fromDefine = String.fromEnvironment(_mapsKeyAndroidEnv);
      if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (dotenv.isInitialized) {
        final fromPlatform = dotenv.env[_mapsKeyIosEnv]?.trim();
        if (fromPlatform != null && fromPlatform.isNotEmpty) return fromPlatform;
      }
      const fromDefine = String.fromEnvironment(_mapsKeyIosEnv);
      if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    }

    if (dotenv.isInitialized) {
      final fromDotenv = dotenv.env[_mapsKeyEnv]?.trim() ?? '';
      if (fromDotenv.isNotEmpty) return fromDotenv;
    }

    const fromDefine = String.fromEnvironment(_mapsKeyEnv);
    return fromDefine.trim();
  }

  static bool get hasGoogleMapsApiKey => googleMapsApiKey.isNotEmpty;

  static String get privacyPolicyUrl {
    final fromDotenv = dotenv.env[_privacyPolicyUrlEnv]?.trim() ?? '';
    if (fromDotenv.isNotEmpty) return fromDotenv;

    const fromDefine = String.fromEnvironment(_privacyPolicyUrlEnv);
    return fromDefine.trim();
  }

  static String get termsAndConditionsUrl {
    final fromDotenv = dotenv.env[_termsAndConditionsUrlEnv]?.trim() ?? '';
    if (fromDotenv.isNotEmpty) return fromDotenv;

    const fromDefine = String.fromEnvironment(_termsAndConditionsUrlEnv);
    return fromDefine.trim();
  }

  static String get driverPoliciesUrl {
    final fromDotenv = dotenv.env[_driverPoliciesUrlEnv]?.trim() ?? '';
    if (fromDotenv.isNotEmpty) return fromDotenv;

    const fromDefine = String.fromEnvironment(_driverPoliciesUrlEnv);
    return fromDefine.trim();
  }
}
