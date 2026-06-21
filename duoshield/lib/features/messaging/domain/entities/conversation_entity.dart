import 'package:equatable/equatable.dart';

import 'message_entity.dart';

/// Conversation entity representing a chat between two users.
class ConversationEntity extends Equatable {
  /// Conversation ID (format: sortedUID1_sortedUID2)
  final String id;

  /// List of participant Firebase UIDs
  final List<String> participants;

  /// Last message timestamp
  final DateTime? lastMessageAt;

  /// Last message preview (decrypted if available)
  final String? lastMessagePreview;

  /// Cached contact name for display
  final String? contactName;

  /// Cached contact public key
  final String? contactPublicKey;

  /// Number of unread messages
  final int unreadCount;

  const ConversationEntity({
    required this.id,
    required this.participants,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.contactName,
    this.contactPublicKey,
    this.unreadCount = 0,
  });

  /// Get the other participant's UID
  String getOtherParticipantUid(String myUid) {
    return participants.firstWhere(
      (uid) => uid != myUid,
      orElse: () => '',
    );
  }

  /// Check if this conversation has valid participants
  bool get isValid => participants.length == 2;

  /// Get display name
  String get displayName => contactName ?? 'Unknown';

  /// Get time ago string for last message
  String get lastMessageTimeAgo {
    if (lastMessageAt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(lastMessageAt!);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${lastMessageAt!.month}/${lastMessageAt!.day}';
  }

  ConversationEntity copyWith({
    String? id,
    List<String>? participants,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    String? contactName,
    String? contactPublicKey,
    int? unreadCount,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview,
      contactName: contactName ?? this.contactName,
      contactPublicKey: contactPublicKey ?? this.contactPublicKey,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        participants,
        lastMessageAt,
        contactName,
        contactPublicKey,
        unreadCount,
      ];

  @override
  String toString() => 'ConversationEntity(id: $id, contact: $displayName)';
}
