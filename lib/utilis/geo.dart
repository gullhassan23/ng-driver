import 'dart:math' as math;

/// Straight-line miles between two WGS84 points.
double milesBetween(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusMiles = 3958.7613;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = _sin2(dLat / 2) +
      math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * _sin2(dLng / 2);
  return 2 * earthRadiusMiles * math.asin(math.min(1, math.sqrt(a)));
}

/// City-speed ETA label matching Google-style strings (`5 mins`).
String formatDriverEta(double miles) {
  const avgCitySpeedMph = 20;
  final minutes = ((miles / avgCitySpeedMph) * 60).round().clamp(1, 24 * 60);
  if (minutes < 60) {
    return minutes == 1 ? '1 min' : '$minutes mins';
  }
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  final hourLabel = hours == 1 ? '1 hour' : '$hours hours';
  if (remainder == 0) return hourLabel;
  final minLabel = remainder == 1 ? '1 min' : '$remainder mins';
  return '$hourLabel $minLabel';
}

double _toRad(double deg) => deg * math.pi / 180;

double _sin2(double x) {
  final s = math.sin(x);
  return s * s;
}
