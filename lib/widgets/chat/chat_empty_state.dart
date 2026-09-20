import 'package:flutter/material.dart';

import '../../utilis/app_colors.dart';
import '../../utilis/chat_constants.dart';

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

  static const Color _muted = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppColors.primaryGreen.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              ChatConstants.emptyState,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
