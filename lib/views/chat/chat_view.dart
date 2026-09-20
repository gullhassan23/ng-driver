import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_message_model.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/chat_constants.dart';
import '../../widgets/chat/chat_app_bar.dart';
import '../../widgets/chat/chat_date_separator.dart';
import '../../widgets/chat/chat_empty_state.dart';
import '../../widgets/chat/chat_input.dart';
import '../../widgets/chat/chat_message_bubble.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final ChatController _controller;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Worker? _messagesWorker;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ChatController>();
    final arg = Get.arguments;
    final rideId = arg is String ? arg.trim() : '';
    _controller.openChat(rideId);

    _messagesWorker = ever<List<ChatMessageModel>>(_controller.messages, (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
  }

  @override
  void dispose() {
    _messagesWorker?.dispose();
    _controller.closeChatSession();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _onSend() async {
    final text = _inputController.text;
    final sent = await _controller.sendMessage(text);
    if (sent && mounted) {
      _inputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = Get.find<AuthController>().uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 1),
        child: Obx(
          () => ChatAppBar(
            riderName: _controller.riderName.value ?? 'Passenger',
            onBack: () => Get.back(),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value &&
                  _controller.messages.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                );
              }

              final error = _controller.errorMessage.value;
              if (error != null &&
                  error.isNotEmpty &&
                  _controller.messages.isEmpty &&
                  !_controller.isLoading.value) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _controller.retryLoad,
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (_controller.messages.isEmpty) {
                return const ChatEmptyState();
              }

              final items = _buildListItems(_controller.messages);
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  if (item is _DateItem) {
                    return ChatDateSeparator(date: item.date);
                  }
                  final msg = (item as _MessageItem).message;
                  final isMine = myUid.isNotEmpty
                      ? msg.senderId == myUid
                      : msg.isFromDriver;
                  return ChatMessageBubble(
                    message: msg,
                    isMine: isMine,
                  );
                },
              );
            }),
          ),
          Obx(
            () {
              if (!_controller.canChat.value) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  color: AppColors.dashboardBackground,
                  child: const Text(
                    ChatConstants.sessionEnded,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              return ChatInput(
                controller: _inputController,
                enabled: _controller.canChat.value,
                isSending: _controller.isSending.value,
                onSend: _onSend,
              );
            },
          ),
        ],
      ),
    );
  }

  List<Object> _buildListItems(List<ChatMessageModel> messages) {
    final items = <Object>[];
    DateTime? lastDay;
    for (final message in messages) {
      final created = message.createdAt;
      if (created != null) {
        final day = DateTime(created.year, created.month, created.day);
        if (lastDay == null || day != lastDay) {
          items.add(_DateItem(day));
          lastDay = day;
        }
      }
      items.add(_MessageItem(message));
    }
    return items;
  }
}

class _DateItem {
  const _DateItem(this.date);
  final DateTime date;
}

class _MessageItem {
  const _MessageItem(this.message);
  final ChatMessageModel message;
}
