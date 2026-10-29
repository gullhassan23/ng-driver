# ngtowncardriver

Flutter driver app for NG Town Car.

## Google Maps / routing setup

Driving routes use the **Routes API** (`computeRoutes`), not the legacy Directions API.

1. In [Google Cloud Console](https://console.cloud.google.com/), open the project for your Maps API key.
2. Enable **[Routes API](https://console.cloud.google.com/apis/library/routes.googleapis.com)** (billing must be active).
3. If the key is API-restricted, allow **Routes API** plus Maps SDK for Android / iOS.
4. Put the key in `.env` as `GOOGLE_MAPS_API_KEY` (and optional `GOOGLE_MAPS_API_KEY_ANDROID` / `GOOGLE_MAPS_API_KEY_IOS`).

Do **not** rely on enabling Directions API (Legacy) — new projects often cannot activate it, which caused the straight-line fallback and `LegacyApiNotActivatedMapError`.

## Getting Started

```bash
flutter pub get
flutter run
```
