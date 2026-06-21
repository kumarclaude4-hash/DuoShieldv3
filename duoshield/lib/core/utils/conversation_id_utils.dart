import 'dart:developer' as developer;

import '../errors/exceptions.dart';

/// Utility class for generating and validating conversation IDs.
/// Conversation IDs are derived from sorted participant UIDs to ensure consistency.
class ConversationIdUtils {
  // Prevent instantiation
  const ConversationIdUtils._();

  /// Separator used between participant UIDs in conversation IDs
  static const String _separator = '_';

  /// Maximum length for a Firebase UID
  static const int _maxUidLength = 128;

  /// Generate a conversation ID from two participant UIDs.
  /// The UIDs are sorted alphabetically to ensure the same ID is generated
  /// regardless of which participant creates it.
  ///
  /// Throws [ValidationException] if UIDs are invalid.
  static String generateConversationId(String uid1, String uid2) {
    try {
      // Validate UIDs
      if (uid1.isEmpty || uid2.isEmpty) {
        throw ValidationException(
          'Participant UIDs cannot be empty',
          code: 'EMPTY_UID',
        );
      }

      if (uid1 == uid2) {
        throw ValidationException(
          'Cannot create conversation with self',
          code: 'SELF_CONVERSATION',
        );
      }

      if (uid1.length > _maxUidLength || uid2.length > _maxUidLength) {
        throw ValidationException(
          'UID exceeds maximum length of $_maxUidLength',
          code: 'UID_TOO_LONG',
        );
      }

      // Sort UIDs alphabetically to ensure consistent ID
      final uids = [uid1, uid2]..sort();
      final conversationId = uids.join(_separator);

      developer.log('Generated conversation ID for participants');
      return conversationId;
    } on ValidationException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to generate conversation ID: $e');
      throw ValidationException(
        'Failed to generate conversation ID',
        code: 'CONVERSATION_ID_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Parse a conversation ID into its participant UIDs.
  /// Returns a list of exactly two UIDs.
  ///
  /// Throws [ValidationException] if the conversation ID is invalid.
  static List<String> parseConversationId(String conversationId) {
    try {
      if (conversationId.isEmpty) {
        throw ValidationException(
          'Conversation ID cannot be empty',
          code: 'EMPTY_CONVERSATION_ID',
        );
      }

      final parts = conversationId.split(_separator);

      if (parts.length != 2) {
        throw ValidationException(
          'Invalid conversation ID format. Expected exactly 2 participants.',
          code: 'INVALID_CONVERSATION_FORMAT',
        );
      }

      if (parts[0].isEmpty || parts[1].isEmpty) {
        throw ValidationException(
          'Conversation ID contains empty participant UID',
          code: 'EMPTY_PARTICIPANT_UID',
        );
      }

      return parts;
    } on ValidationException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to parse conversation ID: $e');
      throw ValidationException(
        'Failed to parse conversation ID',
        code: 'PARSE_CONVERSATION_ID_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the other participant's UID from a conversation ID
  /// given your own UID.
  ///
  /// Throws [ValidationException] if you are not a participant.
  static String getOtherParticipantUid(String conversationId, String myUid) {
    try {
      final participants = parseConversationId(conversationId);

      if (!participants.contains(myUid)) {
        throw ValidationException(
          'You are not a participant in this conversation',
          code: 'NOT_A_PARTICIPANT',
        );
      }

      return participants.firstWhere((uid) => uid != myUid);
    } on ValidationException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to get other participant: $e');
      throw ValidationException(
        'Failed to identify other participant',
        code: 'GET_PARTICIPANT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Validate that a string is a valid conversation ID format.
  static bool isValidConversationId(String conversationId) {
    try {
      final parts = parseConversationId(conversationId);
      return parts.length == 2 &&
          parts[0].isNotEmpty &&
          parts[1].isNotEmpty &&
          parts[0] != parts[1];
    } catch (_) {
      return false;
    }
  }

  /// Extract the participant count from a conversation ID.
  /// Always returns 2 for valid DuoShield conversations.
  static int getParticipantCount(String conversationId) {
    try {
      final parts = parseConversationId(conversationId);
      return parts.length;
    } catch (_) {
      return 0;
    }
  }
}
