import 'dart:developer' as developer;

import '../../../../core/errors/exceptions.dart';
import '../../../../services/storage_service.dart';
import '../../domain/entities/message_entity.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// Local data source for messaging storage in Hive.
class MessagingLocalDatasource {
  final StorageService _storage;

  MessagingLocalDatasource({required StorageService storage})
      : _storage = storage;

  // ==================== MESSAGES ====================

  /// Store a message locally (ciphertext only).
  Future<void> storeMessage(MessageModel message) async {
    try {
      await _storage.storeMessage(message.toJson());
      developer.log('Message stored locally: ${message.id}');
    } catch (e, stackTrace) {
      developer.log('Failed to store message locally: $e');
      throw LocalStorageException(
        'Failed to store message',
        code: 'STORE_MESSAGE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get messages for a conversation from local cache.
  Future<List<MessageModel>> getMessagesForConversation(
    String conversationId,
  ) async {
    try {
      final messagesData =
          await _storage.getMessagesForConversation(conversationId);
      return messagesData.map((data) => MessageModel.fromJson(data)).toList();
    } catch (e, stackTrace) {
      developer.log('Failed to get messages from local storage: $e');
      throw LocalStorageException(
        'Failed to retrieve messages',
        code: 'GET_MESSAGES_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Cache plaintext for a message (memory only).
  Future<void> cachePlaintext(String messageId, String plaintext) async {
    try {
      await _storage.cachePlaintext(messageId, plaintext);
    } catch (e) {
      // Non-critical
      developer.log('Plaintext cache failed (non-critical): $e');
    }
  }

  /// Get cached plaintext for a message.
  Future<String?> getCachedPlaintext(String messageId) async {
    try {
      return await _storage.getCachedPlaintext(messageId);
    } catch (e) {
      return null;
    }
  }

  // ==================== CONVERSATIONS ====================

  /// Store a conversation locally.
  Future<void> storeConversation(ConversationModel conversation) async {
    try {
      await _storage.storeConversation(conversation.toJson());
      developer.log('Conversation stored locally: ${conversation.id}');
    } catch (e, stackTrace) {
      developer.log('Failed to store conversation locally: $e');
      throw LocalStorageException(
        'Failed to store conversation',
        code: 'STORE_CONVERSATION_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get all conversations from local storage.
  Future<List<ConversationModel>> getAllConversations() async {
    try {
      final conversationsData = await _storage.getAllConversations();
      return conversationsData
          .map((data) => ConversationModel.fromJson(data))
          .toList();
    } catch (e, stackTrace) {
      developer.log('Failed to get conversations: $e');
      throw LocalStorageException(
        'Failed to retrieve conversations',
        code: 'GET_CONVERSATIONS_FAILED',
        stackTrace: stackTrace,
      );
    }
  }
}
