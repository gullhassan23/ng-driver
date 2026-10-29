import 'package:flutter_test/flutter_test.dart';
import 'package:ngtowncardriver/constants/notification_constants.dart';
import 'package:ngtowncardriver/models/reservation_model.dart';
import 'package:ngtowncardriver/models/ride_model.dart';
import 'package:ngtowncardriver/utilis/firestore_paths.dart';

void main() {
  group('Decline vs cancel (offers)', () {
    test('pending reservation is not a confirmed booking', () {
      const reservation = ReservationModel(
        id: 'r1',
        status: ReservationStatus.pending,
      );
      expect(ReservationStatus.isConfirm(reservation.status), isFalse);
      expect(ReservationStatus.isCancelled(reservation.status), isFalse);
      expect(ReservationStatus.isConfirmedOrActive(reservation.status), isFalse);
    });

    test('confirm status is cancellable as an accepted booking', () {
      expect(ReservationStatus.isConfirm(ReservationStatus.confirm), isTrue);
      expect(ReservationStatus.isConfirm('confirmed'), isTrue);
      expect(ReservationStatus.isConfirm('upcoming'), isTrue);
      expect(
        ReservationStatus.isConfirmedOrActive(ReservationStatus.confirm),
        isTrue,
      );
    });
  });

  group('Ride cancel permissions by phase', () {
    RideModel rideWithStatus(String status) {
      return RideModel(
        id: 'ride1',
        status: status,
        customerId: 'cust1',
        driverId: 'drv1',
      );
    }

    test('can cancel while traveling to pickup', () {
      final ride = rideWithStatus(RideStatus.driverArriving);
      expect(ride.canCancel, isTrue);
      expect(ride.isActiveAssigned, isTrue);
      expect(ride.isWaitingAtPickup, isFalse);
      expect(ride.isTripInProgress, isFalse);
    });

    test('can cancel after arrival (distinct from no-show)', () {
      final arrived = rideWithStatus(RideStatus.driverArrived);
      expect(arrived.canCancel, isTrue);
      expect(arrived.isWaitingAtPickup, isTrue);
      expect(arrived.isTripInProgress, isFalse);

      final passengerComing = rideWithStatus(RideStatus.passengerArriving);
      expect(passengerComing.canCancel, isTrue);
      expect(passengerComing.isWaitingAtPickup, isTrue);
    });

    test('can cancel during trip in progress (v1 policy)', () {
      final ride = rideWithStatus(RideStatus.rideStarted);
      expect(ride.canCancel, isTrue);
      expect(ride.isTripInProgress, isTrue);
    });

    test('cannot cancel completed ride', () {
      final ride = rideWithStatus(RideStatus.completed);
      expect(ride.canCancel, isFalse);
      expect(RideStatus.isTerminalStatus(ride.status), isTrue);
    });

    test('pending canCancel is true for model but decline must stay local', () {
      // Model allows cancel on pending for legacy paths; UI decline must not
      // write Firestore cancelled for offers (covered by feed dismissLocally).
      final ride = rideWithStatus(RideStatus.pending);
      expect(ride.canCancel, isTrue);
      expect(RideStatus.isActiveAssignedStatus(ride.status), isFalse);
    });
  });

  group('Driver vs customer vs no-show attribution', () {
    test('ride wasCancelledByRider only for rider/user', () {
      expect(
        const RideModel(
          id: '1',
          status: RideStatus.cancelled,
          cancelledBy: 'rider',
        ).wasCancelledByRider,
        isTrue,
      );
      expect(
        const RideModel(
          id: '1',
          status: RideStatus.cancelled,
          cancelledBy: 'user',
        ).wasCancelledByRider,
        isTrue,
      );
      expect(
        const RideModel(
          id: '1',
          status: RideStatus.cancelled,
          cancelledBy: 'driver',
        ).wasCancelledByRider,
        isFalse,
      );
    });

    test('reservation cancelledBy distinguishes driver and rider', () {
      const byDriver = ReservationModel(
        id: 'r1',
        status: ReservationStatus.cancelled,
        cancelledBy: 'driver',
      );
      const byRider = ReservationModel(
        id: 'r2',
        status: ReservationStatus.cancelled,
        cancelledBy: 'rider',
      );
      const byUser = ReservationModel(
        id: 'r3',
        status: ReservationStatus.cancelled,
        cancelledBy: 'user',
      );

      expect(byDriver.wasCancelledByDriver, isTrue);
      expect(byDriver.wasCancelledByRider, isFalse);
      expect(byRider.wasCancelledByRider, isTrue);
      expect(byRider.wasCancelledByDriver, isFalse);
      expect(byUser.wasCancelledByRider, isTrue);

      expect(
        byDriver.statusMessage,
        'This reservation was cancelled by the driver.',
      );
      expect(
        byRider.statusMessage,
        'This reservation was cancelled by the customer.',
      );
    });

    test('no-show is not modelled as a cancel status (placeholder)', () {
      // Customer no-show must remain a separate future policy — never reuse
      // driver cancellation fields for it.
      expect(ReservationStatus.cancelled, isNot(equals('no_show')));
      expect(RideStatus.cancelled, isNot(equals('no_show')));
    });
  });

  group('Future confirmed reservation cancel eligibility', () {
    test('confirm without rideId is a future booking', () {
      const reservation = ReservationModel(
        id: 'r1',
        status: ReservationStatus.confirm,
        driverId: 'drv1',
      );
      expect(ReservationStatus.isConfirm(reservation.status), isTrue);
      expect(reservation.rideId, isNull);
    });

    test('live reservation phases are not future-only cancel UI', () {
      expect(
        ReservationStatus.isLiveActive(ReservationStatus.driverArriving),
        isTrue,
      );
      expect(
        ReservationStatus.isLiveActive(ReservationStatus.confirm),
        isFalse,
      );
    });
  });

  group('Notification cancelledBy contract', () {
    test('data key is stable for Rider / Driver apps', () {
      expect(NotificationDataKeys.cancelledBy, 'cancelledBy');
      expect(NotificationTypes.rideCancelled, 'ride_cancelled');
      expect(NotificationTypes.reservationCancelled, 'reservation_cancelled');
    });
  });

  group('Reservation field schema for cancel attribution', () {
    test('reservation cancel fields are defined', () {
      expect(ReservationFields.cancelledBy, 'cancelledBy');
      expect(ReservationFields.cancelledAt, 'cancelledAt');
      expect(ReservationFields.cancellationReason, 'cancellationReason');
      expect(ReservationFields.cancelReason, 'cancelReason');
    });

    test('ride cancel fields remain separate from payment', () {
      expect(RideFields.cancelledBy, 'cancelledBy');
      expect(RideFields.cancellationReason, 'cancellationReason');
      expect(RideFields.paymentStatus, isNot(equals(RideFields.cancelledBy)));
      expect(RideFields.paymentAmount, isNot(equals(RideFields.cancelledBy)));
    });
  });

  group('Status transition helpers (regression)', () {
    test('accept path statuses remain valid', () {
      expect(RideStatus.isActiveAssignedStatus(RideStatus.driverArriving), isTrue);
      expect(
        RideStatus.isActiveAssignedStatus(RideStatus.passengerArriving),
        isTrue,
      );
      expect(RideStatus.isTripInProgressStatus(RideStatus.rideStarted), isTrue);
      expect(RideStatus.isTerminalStatus(RideStatus.completed), isTrue);
      expect(RideStatus.isTerminalStatus(RideStatus.cancelled), isTrue);
    });

    test('reservation history cancelled filter matches aliases', () {
      expect(ReservationStatus.isCancelled('cancelled'), isTrue);
      expect(ReservationStatus.isCancelled('canceled'), isTrue);
      expect(ReservationStatus.isCompleted('completed'), isTrue);
      expect(ReservationStatus.isCompleted('complete'), isTrue);
    });
  });
}
