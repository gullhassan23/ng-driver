import 'package:cloud_firestore/cloud_firestore.dart';

import '../utilis/firestore_paths.dart';

/// A single chat message under `rides/{rideId}/messages/{messageId}`.
class ChatMessageModel {
  static const String senderTypeRider = 'rider';
  static const String senderTypeDriver = 'driver';
  static const String typeText = 'text';

  final String messageId;
  final String senderId;
  final String senderType;
  final String message;
  final DateTime? createdAt;
  final bool read;
  final String type;

  const ChatMessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderType,
    required this.message,
    this.createdAt,
    this.read = false,
    this.type = typeText,
  });

  bool get isFromRider => senderType == senderTypeRider;
  bool get isFromDriver => senderType == senderTypeDriver;

  factory ChatMessageModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ChatMessageModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory ChatMessageModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return ChatMessageModel(
      messageId: id,
      senderId: _parseString(map[ChatMessageFields.senderId]),
      senderType: _parseString(map[ChatMessageFields.senderType]),
      message: _parseString(map[ChatMessageFields.message]),
      createdAt: _parseNullableDate(map[ChatMessageFields.createdAt]),
      read: map[ChatMessageFields.read] == true,
      type: _parseString(
        map[ChatMessageFields.type],
        fallback: typeText,
      ),
    );
  }

  /// Payload for creating a new text message (rider or driver).
  static Map<String, dynamic> toCreateMap({
    required String senderId,
    required String senderType,
    required String message,
    String type = typeText,
  }) {
    return {
      ChatMessageFields.senderId: senderId,
      ChatMessageFields.senderType: senderType,
      ChatMessageFields.message: message,
      ChatMessageFields.createdAt: FieldValue.serverTimestamp(),
      ChatMessageFields.read: false,
      ChatMessageFields.type: type,
    };
  }

  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value is! String) return fallback;
    return value;
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
