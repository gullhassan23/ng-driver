import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Intermediate stop on a multi-stop live ride (Firestore `rides.stops[]`).
class RideStop {
  const RideStop({
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.order,
  });

  final String location;
  final double latitude;
  final double longitude;
  final int order;

  Map<String, dynamic> toMap() {
    return {
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'order': order,
    };
  }

  factory RideStop.fromMap(Map<String, dynamic> map) {
    return RideStop(
      location: (map['location'] as String?)?.trim().isNotEmpty == true
          ? (map['location'] as String).trim()
          : (map['address'] as String?)?.trim() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasValidCoordinates => latitude != 0 && longitude != 0;

  LatLng? get latLng {
    if (!hasValidCoordinates) return null;
    return LatLng(latitude, longitude);
  }

  /// Parses a Firestore list; null/malformed entries are skipped.
  ///
  /// Sorted by [order]; equal orders keep original list index (stable).
  static List<RideStop> listFrom(dynamic value) {
    if (value is! List) return const [];
    final indexed = <({RideStop stop, int index})>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is! Map) continue;
      try {
        final stop = RideStop.fromMap(Map<String, dynamic>.from(item));
        if (stop.location.isEmpty &&
            stop.latitude == 0 &&
            stop.longitude == 0) {
          continue;
        }
        indexed.add((stop: stop, index: i));
      } catch (_) {
        // Skip malformed stop entries.
      }
    }
    indexed.sort((a, b) {
      final byOrder = a.stop.order.compareTo(b.stop.order);
      if (byOrder != 0) return byOrder;
      return a.index.compareTo(b.index);
    });
    return indexed.map((e) => e.stop).toList(growable: false);
  }
}
