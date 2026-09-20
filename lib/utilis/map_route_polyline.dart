import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_colors.dart';

/// Visible driving-route stroke used on every driver map.
const int kRoutePolylineWidth = 6;

/// Primary-green road polyline. Copies [points] so GoogleMap always sees a
/// new list instance (Android hybrid views often skip same-identity updates).
Polyline buildMapRoutePolyline({
  required PolylineId id,
  required List<LatLng> points,
}) {
  return Polyline(
    polylineId: id,
    points: List<LatLng>.from(points),
    color: AppColors.primaryGreen,
    width: kRoutePolylineWidth,
    jointType: JointType.round,
    startCap: Cap.roundCap,
    endCap: Cap.roundCap,
    geodesic: false,
    visible: true,
    zIndex: 1,
  );
}

/// Straight fallback used only when Directions cannot return a road path.
List<LatLng> straightRoutePoints({
  required LatLng origin,
  required LatLng destination,
  List<LatLng> waypoints = const [],
}) {
  final points = <LatLng>[origin];
  void addIfNew(LatLng point) {
    final last = points.last;
    if (last.latitude == point.latitude && last.longitude == point.longitude) {
      return;
    }
    points.add(point);
  }

  for (final waypoint in waypoints) {
    addIfNew(waypoint);
  }
  addIfNew(destination);
  return points;
}
