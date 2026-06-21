import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';

/// Repository interface for messaging operations.
abstract class MessagingRepository {
  /// Send a message to a contact.
  /// Encrypts the plaintext using Signal Protocol and stores in Firestore.
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String recipientUid,
    required String recipientPublicKey,
    required String plaintext,
  });

  /// Get messages for a conversation (local cache).
  Future<Either<Failure, List<MessageEntity>>> getLocalMessages(
    String conversationId,
  );

  /// Decrypt messages and cache plaintext in memory.
  Future<Either<Failure, List<MessageEntity>>> decryptMessages(
    List<MessageEntity> messages,
    String contactPublicKey,
  );

  /// Listen to real-time message updates from Firestore.
  Stream<List<MessageEntity>> listenToMessages(String conversationId);

  /// Get or create a conversation.
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required String otherParticipantUid,
    String? otherPublicKey,
    String? contactName,
  });

  /// Get all conversations for the current user.
  Future<Either<Failure, List<ConversationEntity>>> getConversations();

  /// Listen to real-time conversation updates.
  Stream<List<ConversationEntity>> listenToConversations();

  /// Mark messages as read.
  Future<Either<Failure, void>> markAsRead(String conversationId);

  /// Delete a conversation and all its messages locally.
  Future<Either<Failure, void>> deleteConversation(String conversationId);
}
