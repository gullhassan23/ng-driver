import 'dart:async';

import 'package:get/get.dart';

import '../models/chat_message_model.dart';
import '../models/ride_model.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../utilis/chat_constants.dart';
import '../utilis/firestore_paths.dart';
import '../widgets/app_snackbar_widget.dart';
import 'auth_controller.dart';

/// Manages in-ride chat for the driver's current assigned ride session.
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
  final RxnString rideId = RxnString();
  final RxnString riderName = RxnString();
  final Rxn<RideModel> ride = Rxn<RideModel>();

  StreamSubscription<List<ChatMessageModel>>? _messagesSub;
  StreamSubscription<RideModel?>? _rideSub;
  bool _markingRead = false;
  bool _handlingInactive = false;
  String? _boundRideId;

  /// Opens (or rebinds) a chat session for [newRideId].
  void openChat(String newRideId) {
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

    if (_boundRideId == id && _messagesSub != null && _rideSub != null) {
      return;
    }

    _resetSession();
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

    _messagesSub = _chatService.watchMessages(id).listen(
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

    final id = rideId.value?.trim() ?? '';
    final uid = Get.find<AuthController>().uid?.trim() ?? '';
    final text = raw.trim();

    if (id.isEmpty) {
      AppSnackbar.error(
        title: ChatConstants.title,
        message: ChatConstants.rideNotFound,
      );
      return false;
    }
    if (!canChat.value) {
      AppSnackbar.info(
        title: ChatConstants.title,
        message: ChatConstants.chatUnavailable,
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
        rideId: id,
        senderId: uid,
        message: text,
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
    final id = rideId.value?.trim() ?? _boundRideId ?? '';
    if (id.isEmpty) return;
    openChat(id);
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
    final id = rideId.value?.trim() ?? '';
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
      await _chatService.markMessagesRead(id, unreadIds);
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
  }

  void _resetSession() {
    _cancelListeners();
    _boundRideId = null;
    rideId.value = null;
    ride.value = null;
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
