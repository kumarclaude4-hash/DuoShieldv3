import 'dart:developer' as developer;

import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../services/firebase_service.dart';
import '../models/message_model.dart';

/// Remote data source for messaging Firebase operations.
class MessagingRemoteDatasource {
  final FirebaseService _firebaseService;
  final Uuid _uuid;

  MessagingRemoteDatasource({
    required FirebaseService firebaseService,
    Uuid? uuid,
  })  : _firebaseService = firebaseService,
        _uuid = uuid ?? const Uuid();

  /// Send an encrypted message to Firestore.
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String ciphertext,
  }) async {
    try {
      final messageId = _uuid.v4();

      await _firebaseService.sendMessage(
        conversationId: conversationId,
        messageId: messageId,
        senderId: senderId,
        ciphertext: ciphertext,
        messageType: 'text',
      );

      final message = MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: senderId,
        ciphertext: ciphertext,
        timestamp: DateTime.now(),
        status: 'sent',
        messageType: 'text',
      );

      developer.log('Message sent to Firestore: $messageId');
      return message;
    } on FirebaseException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to send message: $e');
      throw FirebaseException(
        'Failed to send message',
        code: 'SEND_MESSAGE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Create or get a conversation document.
  Future<void> createConversation({
    required String conversationId,
    required List<String> participants,
  }) async {
    try {
      await _firebaseService.setConversationDocument(
        conversationId: conversationId,
        participants: participants,
      );
      developer.log('Conversation document created: $conversationId');
    } catch (e, stackTrace) {
      developer.log('Failed to create conversation: $e');
      throw FirebaseException(
        'Failed to create conversation',
        code: 'CREATE_CONVERSATION_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Update message status.
  Future<void> updateMessageStatus({
    required String conversationId,
    required String messageId,
    required String status,
  }) async {
    try {
      await _firebaseService.updateMessageStatus(
        conversationId: conversationId,
        messageId: messageId,
        status: status,
      );
      developer.log('Message status updated: $messageId -> $status');
    } catch (e) {
      developer.log('Failed to update message status: $e');
    }
  }

  /// Listen to messages in a conversation.
  Stream<List<Map<String, dynamic>>> listenToMessages(
    String conversationId,
  ) {
    return _firebaseService.listenToMessages(conversationId);
  }

  /// Listen to user's conversations.
  Stream<List<Map<String, dynamic>>> listenToConversations(String uid) {
    return _firebaseService.listenToConversations(uid);
  }
}
