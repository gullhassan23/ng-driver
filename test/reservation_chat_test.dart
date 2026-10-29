import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngtowncardriver/models/chat_message_model.dart';
import 'package:ngtowncardriver/utilis/chat_constants.dart';
import 'package:ngtowncardriver/utilis/firestore_paths.dart';

void main() {
  group('Reservation chat lifecycle gates', () {
    test('allows confirmed and live statuses', () {
      expect(ReservationStatus.isConfirmedOrActive('confirm'), isTrue);
      expect(ReservationStatus.isConfirmedOrActive('confirmed'), isTrue);
      expect(ReservationStatus.isConfirmedOrActive('upcoming'), isTrue);
      expect(ReservationStatus.isConfirmedOrActive('driver_arriving'), isTrue);
      expect(ReservationStatus.isConfirmedOrActive('driver_arrived'), isTrue);
      expect(ReservationStatus.isConfirmedOrActive('ride_started'), isTrue);
    });

    test('blocks pending, cancelled, and completed', () {
      expect(ReservationStatus.isConfirmedOrActive('pending'), isFalse);
      expect(ReservationStatus.isConfirmedOrActive('cancelled'), isFalse);
      expect(ReservationStatus.isConfirmedOrActive('canceled'), isFalse);
      expect(ReservationStatus.isConfirmedOrActive('completed'), isFalse);
      expect(ReservationStatus.isConfirmedOrActive('complete'), isFalse);
    });
  });

  group('Chat message schema', () {
    test('toCreateMap writes ride-parity fields for driver messages', () {
      final map = ChatMessageModel.toCreateMap(
        senderId: 'driver-uid',
        senderType: ChatMessageModel.senderTypeDriver,
        message: 'On my way',
      );

      expect(map.keys, unorderedEquals([
        ChatMessageFields.senderId,
        ChatMessageFields.senderType,
        ChatMessageFields.message,
        ChatMessageFields.createdAt,
        ChatMessageFields.read,
        ChatMessageFields.type,
      ]));
      expect(map[ChatMessageFields.senderId], 'driver-uid');
      expect(map[ChatMessageFields.senderType], 'driver');
      expect(map[ChatMessageFields.message], 'On my way');
      expect(map[ChatMessageFields.read], isFalse);
      expect(map[ChatMessageFields.type], ChatMessageModel.typeText);
      expect(map[ChatMessageFields.createdAt], isA<FieldValue>());
    });

    test('client max length matches hardened rules (500)', () {
      expect(ChatConstants.maxMessageLength, 500);
    });
  });

  group('Chat collection path selection', () {
    test('reservation chat uses reservations parent collection', () {
      expect(
        _messagesParentCollection(isReservation: true),
        FirestorePaths.reservations,
      );
    });

    test('ride chat uses rides parent collection', () {
      expect(
        _messagesParentCollection(isReservation: false),
        FirestorePaths.rides,
      );
    });

    test('messages subcollection name is shared', () {
      expect(FirestorePaths.messages, 'messages');
    });
  });
}

/// Mirrors [ChatService] parent-collection selection for unit testing.
String _messagesParentCollection({required bool isReservation}) {
  return isReservation ? FirestorePaths.reservations : FirestorePaths.rides;
}
