/// FCM `data.type` values — must match Cloud Functions `FcmNotificationType`.
class NotificationTypes {
  NotificationTypes._();

  static const String newRide = 'new_ride';
  static const String newReservation = 'new_reservation';
  static const String chatMessage = 'chat_message';
  static const String rideCancelled = 'ride_cancelled';
  static const String reservationCancelled = 'reservation_cancelled';
  static const String passengerArriving = 'passenger_arriving';
  static const String driverApproved = 'driver_approved';
  static const String reservationReminder = 'reservation_reminder';
}

/// Keys inside FCM `data` maps (all string values).
class NotificationDataKeys {
  NotificationDataKeys._();

  static const String type = 'type';
  static const String rideId = 'rideId';
  static const String reservationId = 'reservationId';
  static const String sessionId = 'sessionId';
  static const String isReservation = 'isReservation';
  static const String messageId = 'messageId';
  static const String driverId = 'driverId';
  static const String cancelledBy = 'cancelledBy';
}
