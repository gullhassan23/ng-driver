import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utilis/firestore_paths.dart';

/// Document from the shared `reservations` collection.
class ReservationModel {
  final String id;
  final String userId;

  final String firstName;
  final String lastName;
  final String phone;
  final String email;

  final String pickupAddress;
  final String dropOffAddress;

  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;

  final DateTime? pickupDate;
  final String pickupTime;

  final double fare;
  final double distanceMiles;

  final int passengerCount;
  final int luggageCount;

  final String serviceType;
  final String vehicleType;
  final String status;
  final String? driverId;
  final String? rideId;
  final String? cancelReason;
  final DateTime? createdAt;

  const ReservationModel({
    required this.id,
    this.userId = '',
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.email = '',
    this.pickupAddress = '',
    this.dropOffAddress = '',
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.pickupDate,
    this.pickupTime = '',
    this.fare = 0,
    this.distanceMiles = 0,
    this.passengerCount = 0,
    this.luggageCount = 0,
    this.serviceType = '',
    this.vehicleType = '',
    this.status = ReservationStatus.pending,
    this.driverId,
    this.rideId,
    this.cancelReason,
    this.createdAt,
  });

  String get fullName {
    final first = firstName.trim();
    final last = lastName.trim();
    return '$first $last'.trim();
  }

  String get displayStatus {
    final lower = status.toLowerCase();
    if (lower == ReservationStatus.pending) return 'Pending';
    if (ReservationStatus.isConfirm(status)) return 'Confirmed';
    if (lower == ReservationStatus.driverArriving) return 'Driver Arriving';
    if (lower == ReservationStatus.driverArrived) return 'Driver Arrived';
    if (lower == ReservationStatus.rideStarted) return 'Ride Started';
    if (ReservationStatus.isCompleted(status)) return 'Completed';
    if (ReservationStatus.isCancelled(status)) return 'Cancelled';
    if (status.isEmpty) return '—';
    return status[0].toUpperCase() + status.substring(1);
  }

  String get statusMessage {
    final lower = status.toLowerCase();
    if (ReservationStatus.isCompleted(status)) {
      return 'This reservation has been completed successfully.';
    }
    if (ReservationStatus.isCancelled(status)) {
      return 'This reservation was cancelled.';
    }
    if (lower == ReservationStatus.driverArriving) {
      return 'Driver is heading to the pickup location.';
    }
    if (lower == ReservationStatus.driverArrived) {
      return 'Driver has arrived at the pickup location.';
    }
    if (lower == ReservationStatus.rideStarted) {
      return 'The ride is in progress.';
    }
    if (ReservationStatus.isConfirm(status)) {
      return 'This reservation is confirmed. '
          'Start the ride when you are ready for pickup.';
    }
    return 'Your reservation is currently pending. '
        'You will be notified once it is confirmed.';
  }

  String get displayFare => '\$${fare.toStringAsFixed(2)}';

  String get displayDistance => '${distanceMiles.toStringAsFixed(2)} mi';

  String get displayPickupDate => _formatDate(pickupDate);

  String get displayPickupTime {
    final raw = pickupTime.trim();
    if (raw.isEmpty) return '—';

    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (match == null) return raw;

    final hour24 = int.tryParse(match.group(1)!) ?? 0;
    final minute = match.group(2)!;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minute $period';
  }

  String get displayCreatedAt => _formatDate(createdAt);

  String get displayCreatedAtTime => _formatTime(createdAt);

  String get displayCreatedAtFull {
    if (createdAt == null) return '—';
    return '$displayCreatedAt at $displayCreatedAtTime';
  }

  bool get isPending => status.toLowerCase() == ReservationStatus.pending;

  bool get isConfirmed => ReservationStatus.isConfirm(status);

  bool get isLiveActive => ReservationStatus.isLiveActive(status);

  bool get isCompleted => ReservationStatus.isCompleted(status);

  bool get isCancelled => ReservationStatus.isCancelled(status);

  /// True when both pickup and drop-off coordinates are available for ActiveRide.
  bool get hasPickupAndDropoffCoords =>
      pickupLatitude != null &&
      pickupLongitude != null &&
      dropoffLatitude != null &&
      dropoffLongitude != null;

  LatLng? get pickupLatLng {
    final lat = pickupLatitude;
    final lng = pickupLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? get dropoffLatLng {
    final lat = dropoffLatitude;
    final lng = dropoffLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  factory ReservationModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = doc.data() ?? const <String, dynamic>{};

    double number(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is num) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return 0;
    }

    double? optionalNumber(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is num) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    int integer(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is int) return value;
        if (value is num) return value.round();
        if (value is String) {
          final parsed = int.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return 0;
    }

    String text(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) return value;
        if (value != null && value is! String && value is! GeoPoint) {
          return value.toString();
        }
      }
      return '';
    }

    DateTime? timestamp(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        if (value is String) {
          final parsed = DateTime.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
        if (value is int) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
      }
      return null;
    }

    LatLng? latLngFromKeys(List<String> keys) {
      for (final key in keys) {
        final parsed = _latLngFromDynamic(map[key]);
        if (parsed != null) return parsed;
      }
      return null;
    }

    final statusRaw = text([
      ReservationFields.status,
      'reservationStatus',
    ]);

    var firstName = text([
      ReservationFields.firstName,
      'first_name',
      'passengerFirstName',
    ]);
    var lastName = text([
      ReservationFields.lastName,
      'last_name',
      'passengerLastName',
    ]);

    if (firstName.isEmpty && lastName.isEmpty) {
      final full = text(['fullName', 'name', 'passengerName', 'customerName']);
      if (full.isNotEmpty) {
        final parts = full.trim().split(RegExp(r'\s+'));
        firstName = parts.first;
        lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    }

    var pickupLat = optionalNumber([
      ReservationFields.pickupLatitude,
      'pickupLat',
    ]);
    var pickupLng = optionalNumber([
      ReservationFields.pickupLongitude,
      'pickupLng',
    ]);
    final pickupGeo = latLngFromKeys([
      'pickupGeo',
      'pickupCoordinates',
      'pickupLocation',
    ]);
    if ((pickupLat == null || pickupLng == null) && pickupGeo != null) {
      pickupLat = pickupGeo.latitude;
      pickupLng = pickupGeo.longitude;
    }

    var dropoffLat = optionalNumber([
      ReservationFields.dropoffLatitude,
      'dropOffLatitude',
      'dropoffLat',
    ]);
    var dropoffLng = optionalNumber([
      ReservationFields.dropoffLongitude,
      'dropOffLongitude',
      'dropoffLng',
    ]);
    final dropoffGeo = latLngFromKeys([
      'dropoffGeo',
      'dropOffGeo',
      'dropoffCoordinates',
      'dropoffLocation',
    ]);
    if ((dropoffLat == null || dropoffLng == null) && dropoffGeo != null) {
      dropoffLat = dropoffGeo.latitude;
      dropoffLng = dropoffGeo.longitude;
    }

    final driverIdRaw = text([ReservationFields.driverId, 'assignedDriverId']);
    final rideIdRaw = text([ReservationFields.rideId, 'activeRideId']);

    return ReservationModel(
      id: doc.id,
      userId: text([ReservationFields.userId, 'uid', 'customerId']),
      firstName: firstName,
      lastName: lastName,
      phone: text([
        ReservationFields.phone,
        'phoneNumber',
        'mobile',
        'contactNumber',
      ]),
      email: text([ReservationFields.email, 'userEmail']),
      pickupAddress: text([
        ReservationFields.pickupAddress,
        'pickup',
        'pickupLocation',
        'fromAddress',
      ]),
      dropOffAddress: text([
        ReservationFields.dropoffAddress,
        'dropOffAddress',
        'dropoff',
        'dropOff',
        'dropoffLocation',
        'toAddress',
      ]),
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
      dropoffLatitude: dropoffLat,
      dropoffLongitude: dropoffLng,
      pickupDate: timestamp([
        ReservationFields.pickupDate,
        'date',
        'reservationDate',
      ]),
      pickupTime: text([
        ReservationFields.pickupTime,
        'time',
        'reservationTime',
      ]),
      fare: number([
        ReservationFields.fare,
        'estimatedFare',
        'totalFare',
        'price',
      ]),
      distanceMiles: number([
        ReservationFields.distanceMiles,
        'distance',
        'totalMiles',
        'distanceMi',
      ]),
      passengerCount: integer([
        ReservationFields.passengerCount,
        'passengers',
        'passenger',
      ]),
      luggageCount: integer([
        ReservationFields.luggageCount,
        'luggage',
        'bags',
      ]),
      serviceType: text([
        ReservationFields.serviceType,
        'service',
        'rideType',
      ]),
      vehicleType: text([
        ReservationFields.vehicleType,
        'vehicle',
        'carType',
      ]),
      status: statusRaw.isEmpty ? ReservationStatus.pending : statusRaw,
      driverId: driverIdRaw.isEmpty ? null : driverIdRaw,
      rideId: rideIdRaw.isEmpty ? null : rideIdRaw,
      cancelReason: () {
        final reason = text([
          ReservationFields.cancelReason,
          'cancellationReason',
          'cancel_reason',
        ]);
        return reason.isEmpty ? null : reason;
      }(),
      createdAt: timestamp([
        ReservationFields.createdAt,
        'created_at',
        'timestamp',
      ]),
    );
  }

  static LatLng? _latLngFromDynamic(dynamic value) {
    if (value is GeoPoint) {
      return LatLng(value.latitude, value.longitude);
    }
    if (value is Map) {
      final lat = value['latitude'] ?? value['lat'];
      final lng = value['longitude'] ?? value['lng'];
      final latN = lat is num ? lat.toDouble() : double.tryParse('$lat');
      final lngN = lng is num ? lng.toDouble() : double.tryParse('$lng');
      if (latN != null && lngN != null) return LatLng(latN, lngN);
    }
    return null;
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${_months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _formatTime(DateTime? date) {
    if (date == null) return '—';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
