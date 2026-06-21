import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';
import '../repositories/messaging_repository.dart';

/// Use case for receiving and managing messages.
class ReceiveMessagesUseCase {
  final MessagingRepository _repository;

  const ReceiveMessagesUseCase(this._repository);

  /// Get cached messages for a conversation.
  Future<Either<Failure, List<MessageEntity>>> getLocalMessages(
    String conversationId,
  ) async {
    return await _repository.getLocalMessages(conversationId);
  }

  /// Decrypt messages using the Signal session.
  Future<Either<Failure, List<MessageEntity>>> decryptMessages(
    List<MessageEntity> messages,
    String contactPublicKey,
  ) async {
    return await _repository.decryptMessages(messages, contactPublicKey);
  }

  /// Listen to real-time messages from Firestore.
  Stream<List<MessageEntity>> listenToMessages(String conversationId) {
    return _repository.listenToMessages(conversationId);
  }

  /// Get all conversations.
  Future<Either<Failure, List<ConversationEntity>>> getConversations() async {
    return await _repository.getConversations();
  }

  /// Listen to real-time conversation updates.
  Stream<List<ConversationEntity>> listenToConversations() {
    return _repository.listenToConversations();
  }

  /// Get or create a conversation.
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required String otherParticipantUid,
    String? otherPublicKey,
    String? contactName,
  }) async {
    return await _repository.getOrCreateConversation(
      otherParticipantUid: otherParticipantUid,
      otherPublicKey: otherPublicKey,
      contactName: contactName,
    );
  }

  /// Mark messages in a conversation as read.
  Future<Either<Failure, void>> markAsRead(String conversationId) async {
    return await _repository.markAsRead(conversationId);
  }
}
