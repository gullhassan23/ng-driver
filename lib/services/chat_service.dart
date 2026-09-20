import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message_model.dart';
import '../utilis/chat_constants.dart';
import '../utilis/firestore_paths.dart';

/// Firestore operations for in-ride chat under `rides/{rideId}/messages`.
class ChatService {
  ChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messages(String rideId) =>
      _firestore
          .collection(FirestorePaths.rides)
          .doc(rideId)
          .collection(FirestorePaths.messages);

  /// Real-time messages for a ride, oldest first.
  Stream<List<ChatMessageModel>> watchMessages(String rideId) {
    final id = rideId.trim();
    if (id.isEmpty) {
      return Stream.value(const <ChatMessageModel>[]);
    }

    return _messages(id)
        .orderBy(ChatMessageFields.createdAt, descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(ChatMessageModel.fromDoc)
              .where(
                (m) =>
                    m.message.trim().isNotEmpty || m.messageId.isNotEmpty,
              )
              .toList();
        })
        .handleError((Object error, StackTrace stackTrace) {
          if (error is FirebaseException) {
            throw ChatServiceException(_mapFirestoreError(error, isRead: true));
          }
          throw error;
        });
  }

  /// Unread messages from the rider (for Active Ride badge).
  Stream<int> watchUnreadFromRiderCount(String rideId) {
    final id = rideId.trim();
    if (id.isEmpty) {
      return Stream.value(0);
    }

    return _messages(id)
        .where(
          ChatMessageFields.senderType,
          isEqualTo: ChatMessageModel.senderTypeRider,
        )
        .where(ChatMessageFields.read, isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((Object error, StackTrace stackTrace) {
          if (error is FirebaseException) {
            throw ChatServiceException(_mapFirestoreError(error, isRead: true));
          }
          throw error;
        });
  }

  Future<void> sendDriverMessage({
    required String rideId,
    required String senderId,
    required String message,
  }) async {
    final id = rideId.trim();
    final uid = senderId.trim();
    final text = message.trim();
    if (id.isEmpty) {
      throw ChatServiceException(ChatConstants.rideNotFound);
    }
    if (uid.isEmpty) {
      throw ChatServiceException(ChatConstants.sendFailed);
    }
    if (text.isEmpty) {
      throw ChatServiceException(ChatConstants.emptyMessage);
    }
    if (text.length > ChatConstants.maxMessageLength) {
      throw ChatServiceException(ChatConstants.messageTooLong);
    }

    try {
      await _messages(id).add(
        ChatMessageModel.toCreateMap(
          senderId: uid,
          senderType: ChatMessageModel.senderTypeDriver,
          message: text,
        ),
      );
    } on FirebaseException catch (e) {
      throw ChatServiceException(_mapFirestoreError(e, isRead: false));
    }
  }

  /// Batch-mark rider messages as read. No-op if [messageIds] is empty.
  Future<void> markMessagesRead(
    String rideId,
    Iterable<String> messageIds,
  ) async {
    final id = rideId.trim();
    if (id.isEmpty) return;

    final ids = messageIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;

    try {
      for (var i = 0; i < ids.length; i += 450) {
        final end = i + 450 > ids.length ? ids.length : i + 450;
        final chunk = ids.sublist(i, end);
        final batch = _firestore.batch();
        for (final messageId in chunk) {
          batch.update(
            _messages(id).doc(messageId),
            {ChatMessageFields.read: true},
          );
        }
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      throw ChatServiceException(_mapFirestoreError(e, isRead: false));
    }
  }

  String _mapFirestoreError(FirebaseException e, {bool isRead = false}) {
    switch (e.code) {
      case 'permission-denied':
        return ChatConstants.permissionDenied;
      case 'unavailable':
        return ChatConstants.noInternet;
      default:
        return isRead ? ChatConstants.loadFailed : ChatConstants.sendFailed;
    }
  }
}

/// Typed failure from [ChatService] with a user-safe [message].
class ChatServiceException implements Exception {
  ChatServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
