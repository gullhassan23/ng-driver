/// User-facing copy and limits for in-ride driver↔rider chat.
class ChatConstants {
  ChatConstants._();

  static const int maxMessageLength = 500;

  static const String title = 'Chat';
  static const String sessionEndedTitle = 'Chat ended';
  static const String sendFailedTitle = 'Send Failed';
  static const String loadFailedTitle = 'Chat';

  static const String emptyState =
      'No messages yet.\nSay hello to your passenger.';
  static const String inputHint = 'Type a message…';
  static const String sessionEnded =
      'This ride has ended. Chat is no longer available.';
  static const String rideNotFound = 'Ride not found.';
  static const String chatUnavailable =
      'Chat is only available during an active ride.';
  static const String emptyMessage = 'Please enter a message.';
  static const String messageTooLong =
      'Message is too long (max $maxMessageLength characters).';
  static const String sendFailed =
      'Unable to send your message. Please try again.';
  static const String loadFailed =
      'Unable to load messages. Please try again.';
  static const String noInternet =
      'Check your internet connection and try again.';
  static const String permissionDenied =
      'You do not have permission to access this chat.';
}
