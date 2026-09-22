import 'package:ngtowncardriver/models/ride_model.dart';

String stopRowText(RideModel ride, int index) {
  if (index < 0 || index >= ride.stops.length) return 'Stop';
  final address = ride.stops[index].location.trim();
  final label = address.isEmpty ? 'Stop ${index + 1}' : address;
  if (!ride.isTripInProgress) return 'Stop ${index + 1} · $label';
  if (index < ride.currentStopIndex) return 'Stop ${index + 1} ✓ · $label';
  if (index == ride.currentStopIndex) {
    return 'Stop ${index + 1} · Current · $label';
  }
  return 'Stop ${index + 1} · $label';
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
