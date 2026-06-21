import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../domain/entities/message_entity.dart';

/// Message bubble widget for displaying individual messages.
/// Shows sent messages on the right (accent color) and received on the left (dark).
class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.sentMessageBubble
              : AppColors.receivedMessageBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message text
            Text(
              message.displayText,
              style: TextStyle(
                color: isMe
                    ? AppColors.sentMessageText
                    : AppColors.receivedMessageText,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            // Timestamp and status row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: isMe
                        ? AppColors.sentMessageText.withOpacity(0.6)
                        : AppColors.textSecondary.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _StatusIcon(status: message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ==================== STATUS ICON ====================

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time,
          size: 12,
          color: AppColors.sentMessageText.withOpacity(0.5),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 12,
          color: AppColors.sentMessageText.withOpacity(0.7),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 12,
          color: AppColors.sentMessageText.withOpacity(0.7),
        );
      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 12,
          color: AppColors.background,
        );
    }
  }
}
