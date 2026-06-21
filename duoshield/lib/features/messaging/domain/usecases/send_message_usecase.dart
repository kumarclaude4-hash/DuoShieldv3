import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/message_entity.dart';
import '../repositories/messaging_repository.dart';

/// Use case for sending a message.
/// Handles encryption via Signal Protocol and Firestore delivery.
class SendMessageUseCase {
  final MessagingRepository _repository;

  const SendMessageUseCase(this._repository);

  /// Send a message.
  /// [conversationId] - The conversation to send to.
  /// [recipientUid] - Recipient's Firebase UID.
  /// [recipientPublicKey] - Recipient's public key for encryption.
  /// [plaintext] - The message text to encrypt and send.
  Future<Either<Failure, MessageEntity>> call({
    required String conversationId,
    required String recipientUid,
    required String recipientPublicKey,
    required String plaintext,
  }) async {
    return await _repository.sendMessage(
      conversationId: conversationId,
      recipientUid: recipientUid,
      recipientPublicKey: recipientPublicKey,
      plaintext: plaintext,
    );
  }
}
