// FIX: Added cloud_firestore import so we can check for Firestore Timestamp
// objects. Without this, `if (ts is DateTime)` always evaluates false for
// Firestore timestamps, causing every message to fall back to DateTime.now().
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../domain/entities/message_entity.dart';

/// Data model for message storage in Hive and Firestore.
/// Maps to [MessageEntity] for domain layer usage.
///
/// IMPORTANT: plaintextCache is NEVER stored - it's memory-only.
class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String ciphertext;
  final DateTime timestamp;
  final String status;
  final String messageType;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.ciphertext,
    required this.timestamp,
    this.status = 'sending',
    this.messageType = 'text',
  });

  /// Convert from Firestore document.
  /// FIX: Added Timestamp branch — Firestore returns cloud_firestore.Timestamp
  /// objects, not Dart DateTime. The original `if (ts is DateTime)` branch
  /// always fell through, making every message appear to arrive at DateTime.now().
  factory MessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? timestamp;
    final ts = data['timestamp'];
    if (ts is Timestamp) {
      timestamp = ts.toDate();
    } else if (ts is DateTime) {
      timestamp = ts;
    } else if (ts != null) {
      timestamp = DateTime.tryParse(ts.toString());
    }

    return MessageModel(
      id: id,
      conversationId: data['conversationId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      ciphertext: data['ciphertext'] as String? ?? '',
      timestamp: timestamp ?? DateTime.now(),
      status: data['status'] as String? ?? 'sent',
      messageType: data['messageType'] as String? ?? 'text',
    );
  }

  /// Convert from JSON/Hive map
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      ciphertext: json['ciphertext'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'sending',
      messageType: json['messageType'] as String? ?? 'text',
    );
  }

  /// Convert to JSON/Hive map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'ciphertext': ciphertext,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'messageType': messageType,
    };
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'ciphertext': ciphertext,
      'status': status,
      'messageType': messageType,
    };
  }

  /// Convert to domain entity (without plaintext)
  MessageEntity toEntity() {
    return MessageEntity(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      ciphertext: ciphertext,
      timestamp: timestamp,
      status: _parseStatus(status),
      type: _parseType(messageType),
    );
  }

  /// Create from domain entity (strips plaintext)
  factory MessageModel.fromEntity(MessageEntity entity) {
    return MessageModel(
      id: entity.id,
      conversationId: entity.conversationId,
      senderId: entity.senderId,
      ciphertext: entity.ciphertext,
      timestamp: entity.timestamp,
      status: entity.status.name,
      messageType: entity.type.name,
    );
  }

  static MessageStatus _parseStatus(String status) {
    switch (status) {
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      default:
        return MessageStatus.sending;
    }
  }

  static MessageType _parseType(String type) {
    switch (type) {
      case 'text':
      default:
        return MessageType.text;
    }
  }
}
