import 'dart:async';

import 'package:get/get.dart';

import '../models/chat_message_model.dart';
import '../models/reservation_model.dart';
import '../models/ride_model.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../utilis/chat_constants.dart';
import '../utilis/firestore_paths.dart';
import '../widgets/app_snackbar_widget.dart';
import 'auth_controller.dart';

/// Manages chat for the driver's current assigned ride or reservation session.
class ChatController extends GetxController {
  ChatController({
    ChatService? chatService,
    FirestoreService? firestore,
  }) : _chatService = chatService ?? ChatService(),
       _firestore = firestore ?? FirestoreService();

  final ChatService _chatService;
  final FirestoreService _firestore;

  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSending = false.obs;
  final RxBool canChat = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool isReservation = false.obs;
  final RxnString rideId = RxnString();
  final RxnString reservationId = RxnString();
  final RxnString riderName = RxnString();
  final Rxn<RideModel> ride = Rxn<RideModel>();
  final Rxn<ReservationModel> reservation = Rxn<ReservationModel>();

  StreamSubscription<List<ChatMessageModel>>? _messagesSub;
  StreamSubscription<RideModel?>? _rideSub;
  StreamSubscription<ReservationModel?>? _reservationSub;
  bool _markingRead = false;
  bool _handlingInactive = false;
  String? _boundRideId;
  String? _boundReservationId;

  String get currentSessionId =>
      isReservation.value
          ? (reservationId.value?.trim() ?? _boundReservationId ?? '')
          : (rideId.value?.trim() ?? _boundRideId ?? '');

  /// True when the driver is actively viewing [sessionId] chat.
  /// Used to suppress redundant foreground chat push snackbars.
  static bool isViewingSession({
    required String sessionId,
    required bool isReservationSession,
  }) {
    final id = sessionId.trim();
    if (id.isEmpty || !Get.isRegistered<ChatController>()) return false;
    final controller = Get.find<ChatController>();
    if (controller.isReservation.value != isReservationSession) return false;
    return controller.currentSessionId == id;
  }

  /// Entry point for opening ride chat.
  void openChat(String newRideId) {
    openRideChat(newRideId);
  }

  /// Opens (or rebinds) a chat session for live ride [newRideId].
  void openRideChat(String newRideId) {
    final id = newRideId.trim();
    if (id.isEmpty) {
      _resetSession();
      isLoading.value = false;
      canChat.value = false;
      errorMessage.value = ChatConstants.rideNotFound;
      AppSnackbar.error(
        title: ChatConstants.title,
        message: ChatConstants.rideNotFound,
      );
      return;
    }

    if (!isReservation.value &&
        _boundRideId == id &&
        _messagesSub != null &&
        _rideSub != null) {
      return;
    }

    _resetSession();
    isReservation.value = false;
    _boundRideId = id;
    rideId.value = id;
    isLoading.value = true;
    _handlingInactive = false;

    _rideSub = _firestore.watchRide(id).listen(
      _onRideSnapshot,
      onError: (Object error) {
        isLoading.value = false;
        canChat.value = false;
        final message = error is ChatServiceException
            ? error.message
            : ChatConstants.loadFailed;
        errorMessage.value = message;
        AppSnackbar.error(
          title: ChatConstants.loadFailedTitle,
          message: message,
        );
      },
    );

    _messagesSub = _chatService.watchMessages(id, isReservation: false).listen(
      _onMessagesSnapshot,
      onError: (Object error) {
        isLoading.value = false;
        final message = error is ChatServiceException
            ? error.message
            : ChatConstants.loadFailed;
        errorMessage.value = message;
        AppSnackbar.error(
          title: ChatConstants.loadFailedTitle,
          message: message,
        );
      },
    );
  }

  /// Opens (or rebinds) a chat session for reservation [newReservationId].
  void openReservationChat(
    String newReservationId, {
    ReservationModel? initialReservation,
    String? linkedRideId,
  }) {
    final id = newReservationId.trim();
    if (id.isEmpty) {
      _resetSession();
      isLoading.value = false;
      canChat.value = false;
      errorMessage.value = ChatConstants.reservationNotFound;
      AppSnackbar.error(
        title: ChatConstants.title,
        message: ChatConstants.reservationNotFound,
      );
      return;
    }

    if (isReservation.value &&
        _boundReservationId == id &&
        _messagesSub != null &&
        _reservationSub != null) {
      return;
    }

    _resetSession();
    isReservation.value = true;
    _boundReservationId = id;
    reservationId.value = id;
    if (linkedRideId != null && linkedRideId.trim().isNotEmpty) {
      rideId.value = linkedRideId.trim();
    }
    if (initialReservation != null) {
      reservation.value = initialReservation;
      final name = initialReservation.fullName.trim();
      riderName.value = name.isEmpty ? 'Passenger' : name;
      if (initialReservation.rideId != null &&
          initialReservation.rideId!.trim().isNotEmpty) {
        rideId.value = initialReservation.rideId!.trim();
      }
    }
    isLoading.value = true;
    _handlingInactive = false;

    _reservationSub = _firestore.watchReservation(id).listen(
      _onReservationSnapshot,
      onError: (Object error) {
        isLoading.value = false;
        canChat.value = false;
        final message = error is ChatServiceException
            ? error.message
            : ChatConstants.loadFailed;
        errorMessage.value = message;
        AppSnackbar.error(
          title: ChatConstants.loadFailedTitle,
          message: message,
        );
      },
    );

    _messagesSub = _chatService.watchMessages(id, isReservation: true).listen(
      _onMessagesSnapshot,
      onError: (Object error) {
        isLoading.value = false;
        final message = error is ChatServiceException
            ? error.message
            : ChatConstants.loadFailed;
        errorMessage.value = message;
        AppSnackbar.error(
          title: ChatConstants.loadFailedTitle,
          message: message,
        );
      },
    );
  }

  /// Stops listeners and clears session state (call when leaving ChatView).
  void closeChatSession() {
    _cancelListeners();
    _resetSession();
  }

  Future<bool> sendMessage(String raw) async {
    if (isSending.value) return false;

    final id = currentSessionId;
    final uid = Get.find<AuthController>().uid?.trim() ?? '';
    final text = raw.trim();

    if (id.isEmpty) {
      AppSnackbar.error(
        title: ChatConstants.title,
        message: isReservation.value
            ? ChatConstants.reservationNotFound
            : ChatConstants.rideNotFound,
      );
      return false;
    }
    if (!canChat.value) {
      AppSnackbar.info(
        title: ChatConstants.title,
        message: isReservation.value
            ? ChatConstants.reservationChatUnavailable
            : ChatConstants.chatUnavailable,
      );
      return false;
    }
    if (text.isEmpty) {
      AppSnackbar.info(
        title: ChatConstants.title,
        message: ChatConstants.emptyMessage,
      );
      return false;
    }
    if (text.length > ChatConstants.maxMessageLength) {
      AppSnackbar.info(
        title: ChatConstants.title,
        message: ChatConstants.messageTooLong,
      );
      return false;
    }
    if (uid.isEmpty) {
      AppSnackbar.error(
        title: ChatConstants.sendFailedTitle,
        message: ChatConstants.sendFailed,
      );
      return false;
    }

    isSending.value = true;
    errorMessage.value = null;
    try {
      await _chatService.sendDriverMessage(
        sessionId: id,
        senderId: uid,
        message: text,
        isReservation: isReservation.value,
      );
      return true;
    } on ChatServiceException catch (e) {
      AppSnackbar.error(
        title: ChatConstants.sendFailedTitle,
        message: e.message,
      );
      return false;
    } catch (_) {
      AppSnackbar.error(
        title: ChatConstants.sendFailedTitle,
        message: ChatConstants.sendFailed,
      );
      return false;
    } finally {
      isSending.value = false;
    }
  }

  Future<void> retryLoad() async {
    final id = currentSessionId;
    if (id.isEmpty) return;
    if (isReservation.value) {
      openReservationChat(id, initialReservation: reservation.value);
    } else {
      openRideChat(id);
    }
  }

  void _onRideSnapshot(RideModel? snapshot) {
    if (snapshot == null) {
      _handleInactiveRide(ChatConstants.rideNotFound);
      return;
    }

    ride.value = snapshot;
    final name = snapshot.customerName.trim();
    riderName.value = name.isEmpty ? 'Passenger' : name;

    final uid = Get.find<AuthController>().uid?.trim() ?? '';
    final assignedDriverId = snapshot.driverId?.trim() ?? '';
    final allowed = RideStatus.isActiveAssignedStatus(snapshot.status) &&
        assignedDriverId.isNotEmpty &&
        uid.isNotEmpty &&
        assignedDriverId == uid;

    canChat.value = allowed;
    isLoading.value = false;

    if (!allowed) {
      _handleInactiveRide(ChatConstants.sessionEnded);
    } else {
      unawaited(_markUnreadRiderMessagesRead(List.from(messages)));
    }
  }

  void _onReservationSnapshot(ReservationModel? snapshot) {
    if (snapshot == null) {
      _handleInactiveRide(ChatConstants.reservationNotFound);
      return;
    }

    reservation.value = snapshot;
    final name = snapshot.fullName.trim();
    riderName.value = name.isEmpty ? 'Passenger' : name;
    if (snapshot.rideId != null && snapshot.rideId!.trim().isNotEmpty) {
      rideId.value = snapshot.rideId!.trim();
    }

    final uid = Get.find<AuthController>().uid?.trim() ?? '';
    final assignedDriverId = snapshot.driverId?.trim() ?? '';

    final allowed = assignedDriverId.isNotEmpty &&
        uid.isNotEmpty &&
        assignedDriverId == uid &&
        ReservationStatus.isConfirmedOrActive(snapshot.status);

    canChat.value = allowed;
    isLoading.value = false;

    if (!allowed) {
      _handleInactiveRide(ChatConstants.reservationSessionEnded);
    } else {
      unawaited(_markUnreadRiderMessagesRead(List.from(messages)));
    }
  }

  void _onMessagesSnapshot(List<ChatMessageModel> list) {
    messages.assignAll(list);
    isLoading.value = false;
    errorMessage.value = null;
    unawaited(_markUnreadRiderMessagesRead(list));
  }

  Future<void> _markUnreadRiderMessagesRead(
    List<ChatMessageModel> list,
  ) async {
    if (_markingRead || !canChat.value) return;
    final id = currentSessionId;
    if (id.isEmpty) return;

    final uid = Get.find<AuthController>().uid?.trim() ?? '';
    final unreadIds = list
        .where(
          (m) =>
              m.isFromRider &&
              !m.read &&
              m.messageId.isNotEmpty &&
              m.senderId != uid,
        )
        .map((m) => m.messageId)
        .toList();
    if (unreadIds.isEmpty) return;

    _markingRead = true;
    try {
      await _chatService.markMessagesRead(
        id,
        unreadIds,
        isReservation: isReservation.value,
      );
    } on ChatServiceException {
      // Best-effort; next snapshot can retry.
    } catch (_) {
      // Ignore transient mark-read failures.
    } finally {
      _markingRead = false;
    }
  }

  void _handleInactiveRide(String message) {
    if (_handlingInactive) return;
    _handlingInactive = true;
    canChat.value = false;
    isLoading.value = false;
    _cancelListeners();
    messages.clear();
    AppSnackbar.info(
      title: ChatConstants.sessionEndedTitle,
      message: message,
    );
    if (Get.key.currentState?.canPop() == true) {
      Get.back();
    }
  }

  void _cancelListeners() {
    _messagesSub?.cancel();
    _messagesSub = null;
    _rideSub?.cancel();
    _rideSub = null;
    _reservationSub?.cancel();
    _reservationSub = null;
  }

  void _resetSession() {
    _cancelListeners();
    _boundRideId = null;
    _boundReservationId = null;
    isReservation.value = false;
    rideId.value = null;
    reservationId.value = null;
    ride.value = null;
    reservation.value = null;
    riderName.value = null;
    messages.clear();
    canChat.value = false;
    isSending.value = false;
    isLoading.value = false;
    errorMessage.value = null;
    _markingRead = false;
  }

  @override
  void onClose() {
    closeChatSession();
    super.onClose();
  }
}
