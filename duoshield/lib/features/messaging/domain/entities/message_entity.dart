import 'package:equatable/equatable.dart';

/// Message status enum
enum MessageStatus { sending, sent, delivered, read }

/// Message type enum
enum MessageType { text }

/// Message entity representing a single message in a conversation.
/// Only ciphertext is persisted; plaintext exists in memory only.
class MessageEntity extends Equatable {
  /// Unique message ID (UUID)
  final String id;

  /// Conversation this message belongs to
  final String conversationId;

  /// Sender's Firebase UID
  final String senderId;

  /// Encrypted message content (base64, stored in Firestore)
  final String ciphertext;

  /// Decrypted plaintext - MEMORY ONLY, NEVER persisted
  final String? plaintextCache;

  /// When the message was sent
  final DateTime timestamp;

  /// Delivery status
  final MessageStatus status;

  /// Message type
  final MessageType type;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.ciphertext,
    this.plaintextCache,
    required this.timestamp,
    this.status = MessageStatus.sending,
    this.type = MessageType.text,
  });

  /// Check if this message was sent by the current user
  bool isSentByMe(String myUid) => senderId == myUid;

  /// Get display text (decrypted if available)
  String get displayText => plaintextCache ?? '[Encrypted]';

  /// Check if plaintext is available in memory
  bool get hasPlaintext => plaintextCache != null && plaintextCache!.isNotEmpty;

  /// Get status string for UI
  String get statusLabel {
    switch (status) {
      case MessageStatus.sending:
        return 'Sending';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.read:
        return 'Read';
    }
  }

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? ciphertext,
    String? plaintextCache,
    DateTime? timestamp,
    MessageStatus? status,
    MessageType? type,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      ciphertext: ciphertext ?? this.ciphertext,
      plaintextCache: plaintextCache ?? this.plaintextCache,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        ciphertext,
        timestamp,
        status,
        type,
        // Note: plaintextCache is NOT in props because it's ephemeral
      ];

  @override
  String toString() =>
      'MessageEntity(id: $id, conv: $conversationId, status: $statusLabel)';
}
