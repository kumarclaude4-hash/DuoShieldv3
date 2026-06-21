// FIX: Added cloud_firestore import so we can check for Firestore Timestamp
// objects. Without this, `if (ts is DateTime)` always evaluates false for
// Firestore timestamps, causing lastMessageAt to be null for every conversation.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../domain/entities/conversation_entity.dart';

/// Data model for conversation storage.
/// Maps to [ConversationEntity] for domain layer usage.
class ConversationModel {
  final String id;
  final List<String> participants;
  final DateTime? lastMessageAt;

  const ConversationModel({
    required this.id,
    required this.participants,
    this.lastMessageAt,
  });

  /// Convert from Firestore document.
  /// FIX: Added Timestamp branch — Firestore returns cloud_firestore.Timestamp
  /// objects, not Dart DateTime. The original `if (ts is DateTime)` always
  /// fell through, leaving lastMessageAt null and breaking conversation sorting.
  factory ConversationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? lastMessageAt;
    final ts = data['lastMessageAt'];
    if (ts is Timestamp) {
      lastMessageAt = ts.toDate();
    } else if (ts is DateTime) {
      lastMessageAt = ts;
    } else if (ts != null) {
      lastMessageAt = DateTime.tryParse(ts.toString());
    }

    final participants = (data['participants'] as List<dynamic>?)
            ?.map((p) => p as String)
            .toList() ??
        [];

    return ConversationModel(
      id: id,
      participants: participants,
      lastMessageAt: lastMessageAt,
    );
  }

  /// Convert from JSON/Hive map
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList() ??
          [],
      lastMessageAt:
          DateTime.tryParse(json['lastMessageAt'] as String? ?? ''),
    );
  }

  /// Convert to JSON/Hive map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
    };
  }

  /// Convert to domain entity
  ConversationEntity toEntity({
    String? contactName,
    String? contactPublicKey,
    String? lastMessagePreview,
    int unreadCount = 0,
  }) {
    return ConversationEntity(
      id: id,
      participants: participants,
      lastMessageAt: lastMessageAt,
      contactName: contactName,
      contactPublicKey: contactPublicKey,
      lastMessagePreview: lastMessagePreview,
      unreadCount: unreadCount,
    );
  }

  ConversationModel copyWith({
    String? id,
    List<String>? participants,
    DateTime? lastMessageAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }
}
