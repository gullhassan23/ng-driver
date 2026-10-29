import 'package:flutter_test/flutter_test.dart';
import 'package:ngtowncardriver/constants/notification_constants.dart';

void main() {
  group('NotificationTypes', () {
    test('payload type strings match Cloud Functions contract', () {
      expect(NotificationTypes.newRide, 'new_ride');
      expect(NotificationTypes.newReservation, 'new_reservation');
      expect(NotificationTypes.chatMessage, 'chat_message');
      expect(NotificationTypes.rideCancelled, 'ride_cancelled');
      expect(NotificationTypes.reservationCancelled, 'reservation_cancelled');
      expect(NotificationTypes.passengerArriving, 'passenger_arriving');
      expect(NotificationTypes.driverApproved, 'driver_approved');
      expect(NotificationTypes.reservationReminder, 'reservation_reminder');
    });

    test('data keys are stable', () {
      expect(NotificationDataKeys.type, 'type');
      expect(NotificationDataKeys.rideId, 'rideId');
      expect(NotificationDataKeys.reservationId, 'reservationId');
      expect(NotificationDataKeys.sessionId, 'sessionId');
      expect(NotificationDataKeys.isReservation, 'isReservation');
      expect(NotificationDataKeys.cancelledBy, 'cancelledBy');
    });
  });
}
