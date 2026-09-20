import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide configuration values loaded from environment / dart-define.
class AppConfig {
  AppConfig._();

  static const String _mapsKeyEnv = 'GOOGLE_MAPS_API_KEY';
  static const String _privacyPolicyUrlEnv = 'PRIVACY_POLICY_URL';
  static const String _termsAndConditionsUrlEnv = 'TERMS_AND_CONDITIONS_URL';
  static const String _driverPoliciesUrlEnv = 'DRIVER_POLICIES';

  /// Google Maps / Places API key.
  /// Prefers `.env` via flutter_dotenv; falls back to `--dart-define`.
  static String get googleMapsApiKey {
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
