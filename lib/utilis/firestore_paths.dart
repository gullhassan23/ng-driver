/// Single source of truth for the Firestore layout that the driver app shares
/// with the NG Town Ride user app on project `ng-town-car-ride`.
///
/// The two apps only see each other's data when these names match the user
/// app exactly. If the user app writes to different collections or fields,
/// change them here and nowhere else.
class FirestorePaths {
  static const String drivers = 'drivers';
  static const String driverInformation = 'driver_information';
  static const String rideRequests = 'rideRequests';
  static const String rides = 'rides';
  static const String reservations = 'reservations';

  /// Subcollection under `rides/{rideId}` for multi-driver acceptance offers.
  static const String driverOffers = 'driverOffers';

  /// Subcollection under `rides/{rideId}` for in-ride rider↔driver chat.
  static const String messages = 'messages';
}

/// Field names on `rides/{rideId}/messages/{messageId}` documents.
class ChatMessageFields {
  static const String senderId = 'senderId';
  static const String senderType = 'senderType';
  static const String message = 'message';
  static const String createdAt = 'createdAt';
  static const String read = 'read';
  static const String type = 'type';
}

/// Field names on `rideRequests` and `rides` documents.
class RideFields {
  // --- rideRequests ---
  static const String riderId = 'riderId';
  static const String riderName = 'riderName';
  static const String riderRating = 'riderRating';
  static const String riderReviews = 'riderReviews';
  /// Optional written review from the rider app (`rides/{rideId}`).
  static const String riderReview = 'riderReview';
  /// Timestamp set by the rider app when they submit [riderRating].
  static const String ratedAt = 'ratedAt';

  static const String fare = 'fare';
  static const String currency = 'currency';
  static const String fareOffers = 'fareOffers';

  static const String distanceKm = 'distanceKm';
  static const String durationMinutes = 'durationMinutes';

  static const String pickupAddress = 'pickupAddress';
  static const String pickupLocation = 'pickupLocation';
  static const String dropoffAddress = 'dropoffAddress';
  static const String dropoffLocation = 'dropoffLocation';

  static const String status = 'status';
  static const String driverId = 'driverId';
  static const String createdAt = 'createdAt';
  static const String acceptedAt = 'acceptedAt';
  /// Set when status becomes `driver_arriving` (driver moving toward pickup).
  static const String arrivingAt = 'arrivingAt';

  // --- rides collection ---
  static const String rideId = 'rideId';
  static const String customerId = 'customerId';
  static const String customerName = 'customerName';
  static const String estimatedFare = 'estimatedFare';
  static const String totalMiles = 'totalMiles';
  static const String vehicleType = 'vehicleType';
  static const String pickupLatitude = 'pickupLatitude';
  static const String pickupLongitude = 'pickupLongitude';
  static const String dropoffLatitude = 'dropoffLatitude';
  static const String dropoffLongitude = 'dropoffLongitude';
  /// Optional intermediate stops between pickup and destination.
  /// Shape: `[{ location, latitude, longitude, order }]`.
  static const String stops = 'stops';
  /// Index into [stops] for the driver's next stop. When >= stops.length,
  /// the next target is the final destination. Missing on old rides → 0.
  static const String currentStopIndex = 'currentStopIndex';
  static const String updatedAt = 'updatedAt';
  static const String completedAt = 'completedAt';
  static const String startedAt = 'startedAt';
  static const String expiresAt = 'expiresAt';
  static const String bookingTime = 'bookingTime';
  /// Set by the rider app when the rider taps "I'm here" at pickup.
  static const String riderArrived = 'riderArrived';
  static const String riderArrivedAt = 'riderArrivedAt';

  static const String cancelledAt = 'cancelledAt';
  static const String cancelledBy = 'cancelledBy';
  /// Driver who declined/cancelled a pending ride (history attribution).
  static const String cancelledByDriverId = 'cancelledByDriverId';
  static const String cancellationReason = 'cancellationReason';

  /// Live driver GPS on the same ride document (written by the driver app).
  /// Shape: `{ latitude: number, longitude: number, heading?: number }`.
  static const String driverLocation = 'driverLocation';
  static const String driverLocationUpdatedAt = 'driverLocationUpdatedAt';
  static const String driverArrivedAt = 'driverArrivedAt';

  // Denormalized driver snapshot written on accept (for the rider app).
  static const String driverFirstName = 'driverFirstName';
  static const String driverLastName = 'driverLastName';
  static const String driverName = 'driverName';
  static const String driverPhone = 'driverPhone';
  static const String driverVehicleType = 'driverVehicleType';
  static const String driverVehicleMake = 'driverVehicleMake';
  static const String driverVehicleModel = 'driverVehicleModel';
  static const String driverVehicleColor = 'driverVehicleColor';
  static const String driverVehicleRegistration = 'driverVehicleRegistration';
  static const String driverVehicle = 'driverVehicle';
  static const String driverVehicleNumber = 'driverVehicleNumber';
  static const String driverRating = 'driverRating';
  static const String driverDistanceMiles = 'driverDistanceMiles';
  static const String driverEta = 'driverEta';

  /// Set when a ride is created from an accepted reservation.
  static const String reservationId = 'reservationId';
}

/// Field names on `rides/{rideId}/driverOffers/{driverId}` documents.
class DriverOfferFields {
  static const String driverId = 'driverId';
  static const String driverName = 'driverName';
  static const String driverFirstName = 'driverFirstName';
  static const String driverLastName = 'driverLastName';
  static const String driverPhone = 'driverPhone';
  static const String driverVehicleType = 'driverVehicleType';
  static const String driverVehicleMake = 'driverVehicleMake';
  static const String driverVehicleModel = 'driverVehicleModel';
  static const String driverVehicleColor = 'driverVehicleColor';
  static const String driverVehicleRegistration = 'driverVehicleRegistration';
  /// Driver GPS at the moment they accepted (offer submission).
  static const String driverLatitude = 'driverLatitude';
  static const String driverLongitude = 'driverLongitude';
  static const String driverAddress = 'driverAddress';
  static const String status = 'status';
  static const String acceptedAt = 'acceptedAt';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
}

/// Values used in the `status` field of a driver offer.
class DriverOfferStatus {
  static const String driverAccepted = 'driver_accepted';
  static const String riderSelected = 'rider_selected';
  static const String riderDeclined = 'rider_declined';
  static const String expired = 'expired';
  static const String cancelled = 'cancelled';

  static bool isWaiting(String status) => status == driverAccepted;

  static bool isTerminal(String status) =>
      status == riderSelected ||
      status == riderDeclined ||
      status == expired ||
      status == cancelled;
}

/// Field names on a `drivers` document.
class DriverFields {
  static const String uid = 'uid';
  static const String firstName = 'firstName';
  static const String lastName = 'lastName';
  static const String email = 'email';
  static const String phone = 'phone';

  static const String cnic = 'cnic';
  static const String licenseNumber = 'licenseNumber';

  static const String vehicleType = 'vehicleType';
  static const String vehicleMake = 'vehicleMake';
  static const String vehicleModel = 'vehicleModel';
  static const String vehicleColor = 'vehicleColor';
  static const String vehicleRegistration = 'vehicleRegistration';
  static const String rating = 'rating';

  static const String isOnline = 'isOnline';
  static const String isApproved = 'isApproved';
  static const String fcmToken = 'fcmToken';
  static const String profileComplete = 'profileComplete';
  static const String currentRideId = 'currentRideId';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
}

/// Field names on a `driver_information` document.
class DriverInformationFields {
  static const String uid = 'uid';
  static const String cnic = 'cnic';
  static const String licenseNumber = 'licenseNumber';
  static const String vehicleType = 'vehicleType';
  static const String vehicleMake = 'vehicleMake';
  static const String vehicleModel = 'vehicleModel';
  static const String vehicleColor = 'vehicleColor';
  static const String vehicleRegistration = 'vehicleRegistration';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
}

/// Field names on a `reservations` document.
class ReservationFields {
  static const String cancelReason = 'cancelReason';
  static const String cancelledAt = 'cancelledAt';
  static const String createdAt = 'createdAt';
  static const String distanceMiles = 'distanceMiles';
  static const String dropoffAddress = 'dropoffAddress';
  static const String dropoffLatitude = 'dropoffLatitude';
  static const String dropoffLongitude = 'dropoffLongitude';
  static const String driverId = 'driverId';
  static const String driverName = 'driverName';
  static const String driverPhone = 'driverPhone';
  static const String email = 'email';
  static const String fare = 'fare';
  static const String firstName = 'firstName';
  static const String lastName = 'lastName';
  static const String luggageCount = 'luggageCount';
  static const String passengerCount = 'passengerCount';
  static const String phone = 'phone';
  static const String pickupAddress = 'pickupAddress';
  static const String pickupDate = 'pickupDate';
  static const String pickupLatitude = 'pickupLatitude';
  static const String pickupLongitude = 'pickupLongitude';
  static const String pickupTime = 'pickupTime';
  static const String rideId = 'rideId';
  static const String serviceType = 'serviceType';
  static const String status = 'status';
  static const String updatedAt = 'updatedAt';
  static const String userId = 'userId';
  static const String vehicleName = 'vehicleName';
  static const String vehicleNumber = 'vehicleNumber';
  static const String vehicleType = 'vehicleType';
}

/// Values used in the `status` field of a reservation.
class ReservationStatus {
  static const String pending = 'pending';
  static const String confirm = 'confirm';
  /// Legacy confirmed value; dual-read only — new writes use [confirm].
  static const String upcoming = 'upcoming';
  /// Legacy read alias for confirmed.
  static const String confirmed = 'confirmed';
  /// Live ride mirror statuses (synced from linked `rides/{rideId}`).
  static const String driverArriving = 'driver_arriving';
  static const String driverArrived = 'driver_arrived';
  static const String rideStarted = 'ride_started';
  static const String completed = 'completed';
  /// Legacy completed alias; dual-read only.
  static const String complete = 'complete';
  static const String cancelled = 'cancelled';
  /// Legacy cancelled alias; dual-read only.
  static const String canceled = 'canceled';

  /// True when the reservation is confirmed (`confirm` or legacy aliases).
  static bool isConfirm(String status) {
    final value = status.toLowerCase();
    return value == confirm ||
        value == upcoming ||
        value == confirmed ||
        value == 'accepted';
  }

  /// Confirmed or in an active live-ride phase (history "Confirmed" filter).
  static bool isConfirmedOrActive(String status) {
    final value = status.toLowerCase();
    return isConfirm(value) ||
        value == driverArriving ||
        value == driverArrived ||
        value == rideStarted;
  }

  /// Active linked-ride phases where Continue Ride should recover the ride.
  static bool isLiveActive(String status) {
    final value = status.toLowerCase();
    return value == driverArriving ||
        value == driverArrived ||
        value == rideStarted;
  }

  static bool isCompleted(String status) {
    final value = status.toLowerCase().trim();
    return value == completed || value == complete;
  }

  static bool isCancelled(String status) {
    final value = status.toLowerCase().trim();
    return value == cancelled || value == canceled;
  }

  @Deprecated('Use ReservationStatus.isConfirm')
  static bool isUpcoming(String status) => isConfirm(status);
}

/// Values used in the `status` field of a ride request.
class RideStatus {
  static const String pending = 'pending';
  /// Legacy claim status; dual-read only — new writes use [driverArriving].
  static const String accepted = 'accepted';
  /// Legacy rider-selected assignment; dual-read only — new writes use [driverArriving].
  static const String driverSelected = 'driver_selected';
  static const String driverArriving = 'driver_arriving';
  static const String driverArrived = 'driver_arrived';
  /// Rider acknowledged they are coming to the pickup (unlocks Start Ride).
  static const String passengerArriving = 'passenger_arriving';
  static const String rideStarted = 'ride_started';
  /// Legacy optional status the rider app may set with [RideFields.riderArrived].
  /// Dual-read only — new writes use [passengerArriving].
  static const String riderArrived = 'riderArrived';
  /// Legacy trip-in-progress value; dual-read only — new writes use [rideStarted].
  @Deprecated('Use RideStatus.rideStarted')
  static const String inProgress = 'inProgress';
  /// Rider-app / rules snake_case alias; dual-read only — new writes use [rideStarted].
  static const String inProgressSnake = 'in_progress';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String expired = 'expired';

  /// Map Firestore / console aliases onto canonical driver-app statuses.
  static String normalize(String raw) {
    final status = raw.trim();
    switch (status) {
      case 'inProgress':
      case inProgressSnake:
        return rideStarted;
      case 'canceled':
        return cancelled;
      case accepted:
      case 'selected':
        return driverSelected;
      default:
        return status.isEmpty ? pending : status;
    }
  }

  /// True for the active trip phase (`ride_started` or legacy aliases).
  static bool isTripInProgressStatus(String status) =>
      normalize(status) == rideStarted;

  /// Assigned but not yet moving toward pickup (`driver_selected` or legacy `accepted`).
  static bool isPreArrivingAssignedStatus(String status) =>
      normalize(status) == driverSelected;

  /// Statuses that mean the driver still has an open active ride.
  static bool isActiveAssignedStatus(String status) {
    final value = normalize(status);
    return value == driverSelected ||
        value == driverArriving ||
        value == driverArrived ||
        value == passengerArriving ||
        value == rideStarted ||
        value == riderArrived;
  }

  /// Ride is finished and must not be cancelled.
  static bool isTerminalStatus(String status) {
    final value = normalize(status).toLowerCase();
    return value == completed || value == cancelled || value == expired;
  }
}
