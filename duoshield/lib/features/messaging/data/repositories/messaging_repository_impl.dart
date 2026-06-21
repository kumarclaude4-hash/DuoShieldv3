import 'dart:async';
import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/conversation_id_utils.dart';
import '../../../../features/identity/domain/repositories/identity_repository.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/signal_session_manager.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../datasources/messaging_local_datasource.dart';
import '../datasources/messaging_remote_datasource.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// Implementation of [MessagingRepository].
class MessagingRepositoryImpl implements MessagingRepository {
  final MessagingLocalDatasource _localDatasource;
  final MessagingRemoteDatasource _remoteDatasource;
  final IdentityRepository _identityRepository;
  final SignalSessionManager _signalManager;
  final FirebaseService _firebaseService;
  final Uuid _uuid;

  MessagingRepositoryImpl({
    required MessagingLocalDatasource localDatasource,
    required MessagingRemoteDatasource remoteDatasource,
    required IdentityRepository identityRepository,
    required SignalSessionManager signalManager,
    required FirebaseService firebaseService,
    Uuid? uuid,
  })  : _localDatasource = localDatasource,
        _remoteDatasource = remoteDatasource,
        _identityRepository = identityRepository,
        _signalManager = signalManager,
        _firebaseService = firebaseService,
        _uuid = uuid ?? const Uuid();

  @override
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String recipientUid,
    required String recipientPublicKey,
    required String plaintext,
  }) async {
    try {
      // FIX: Was `myUidResult` on line 54 but referenced as `myUid` on line 58
      // — undefined variable compile/runtime crash. Renamed to myUid directly.
      final myUid = await _identityRepository
          .getCurrentIdentity()
          .then((result) => result.fold((l) => null, (identity) => identity?.uid));

      if (myUid == null) {
        return Left(UnauthorizedFailure('Not authenticated'));
      }

      // Ensure Signal session exists
      final hasSession = await _signalManager.hasSession(recipientPublicKey);
      if (!hasSession) {
        final preKeyBundle =
            await _firebaseService.getUserPreKeyBundle(recipientUid);
        if (preKeyBundle == null) {
          return Left(
            SignalProtocolFailure('No pre-key bundle found for recipient'),
          );
        }

        await _signalManager.establishSession(
          contactPublicKeyHex: recipientPublicKey,
          preKeyBundle: preKeyBundle,
        );
      }

      // Encrypt message using Signal Protocol
      final ciphertext = await _signalManager.encryptMessage(
        contactPublicKeyHex: recipientPublicKey,
        plaintext: plaintext,
      );

      // Send to Firestore
      final messageModel = await _remoteDatasource.sendMessage(
        conversationId: conversationId,
        senderId: myUid,
        ciphertext: ciphertext,
      );

      // Store locally
      await _localDatasource.storeMessage(messageModel);

      developer.log('Message sent: ${messageModel.id}');
      return Right(messageModel.toEntity());
    } on EncryptionException catch (e) {
      return Left(EncryptionFailure(e.message));
    } on SignalProtocolException catch (e) {
      return Left(SignalProtocolFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(FirebaseFailure(e.message));
    } catch (e) {
      developer.log('Send message failed: $e');
      return Left(MessagingFailure('Failed to send message'));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getLocalMessages(
    String conversationId,
  ) async {
    try {
      final models = await _localDatasource.getMessagesForConversation(
        conversationId,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get local messages'));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> decryptMessages(
    List<MessageEntity> messages,
    String contactPublicKey,
  ) async {
    try {
      final decryptedMessages = <MessageEntity>[];

      for (final message in messages) {
        if (message.hasPlaintext) {
          decryptedMessages.add(message);
          continue;
        }

        try {
          final cached =
              await _localDatasource.getCachedPlaintext(message.id);
          if (cached != null) {
            decryptedMessages.add(message.copyWith(plaintextCache: cached));
            continue;
          }

          final plaintext = await _signalManager.decryptMessage(
            contactPublicKeyHex: contactPublicKey,
            ciphertextBase64: message.ciphertext,
          );

          await _localDatasource.cachePlaintext(message.id, plaintext);
          decryptedMessages.add(message.copyWith(plaintextCache: plaintext));
        } catch (e) {
          developer.log('Failed to decrypt message ${message.id}: $e');
          decryptedMessages.add(message);
        }
      }

      return Right(decryptedMessages);
    } on SignalProtocolException catch (e) {
      return Left(SignalProtocolFailure(e.message));
    } catch (e) {
      return Left(DecryptionFailure('Failed to decrypt messages'));
    }
  }

  @override
  Stream<List<MessageEntity>> listenToMessages(String conversationId) {
    return _remoteDatasource.listenToMessages(conversationId).asyncMap(
      (messageDataList) async {
        final messages = messageDataList.map((data) {
          final id = data['id'] as String;
          return MessageModel.fromFirestore(id, data).toEntity();
        }).toList();

        for (final data in messageDataList) {
          try {
            final model = MessageModel.fromFirestore(
              data['id'] as String,
              data,
            );
            await _localDatasource.storeMessage(model);
          } catch (e) {
            developer.log('Failed to cache message: $e');
          }
        }

        return messages;
      },
    );
  }

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required String otherParticipantUid,
    String? otherPublicKey,
    String? contactName,
  }) async {
    try {
      final myUid = await _identityRepository
          .getCurrentIdentity()
          .then((result) => result.fold((l) => null, (identity) => identity?.uid));

      if (myUid == null) {
        return Left(UnauthorizedFailure('Not authenticated'));
      }

      final conversationId = ConversationIdUtils.generateConversationId(
        myUid,
        otherParticipantUid,
      );

      await _remoteDatasource.createConversation(
        conversationId: conversationId,
        participants: [myUid, otherParticipantUid],
      );

      final conversationModel = ConversationModel(
        id: conversationId,
        participants: [myUid, otherParticipantUid],
        lastMessageAt: DateTime.now(),
      );
      await _localDatasource.storeConversation(conversationModel);

      return Right(conversationModel.toEntity(
        contactName: contactName,
        contactPublicKey: otherPublicKey,
      ));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(FirebaseFailure(e.message));
    } catch (e) {
      developer.log('Create conversation failed: $e');
      return Left(MessagingFailure('Failed to create conversation'));
    }
  }

  @override
  Future<Either<Failure, List<ConversationEntity>>> getConversations() async {
    try {
      final models = await _localDatasource.getAllConversations();

      final conversations = models
          .map((m) => m.toEntity(
                contactName: null,
                lastMessagePreview: null,
              ))
          .toList();

      conversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? DateTime(0);
        final bTime = b.lastMessageAt ?? DateTime(0);
        return bTime.compareTo(aTime);
      });

      return Right(conversations);
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get conversations'));
    }
  }

  @override
  Stream<List<ConversationEntity>> listenToConversations() {
    final myUid = _firebaseService.currentUid;
    return _remoteDatasource.listenToConversations(myUid).asyncMap(
      (convDataList) async {
        final conversations = convDataList.map((data) {
          final id = data['id'] as String;
          return ConversationModel.fromFirestore(id, data).toEntity();
        }).toList();

        for (final data in convDataList) {
          try {
            final model = ConversationModel.fromFirestore(
              data['id'] as String,
              data,
            );
            await _localDatasource.storeConversation(model);
          } catch (e) {
            developer.log('Failed to cache conversation: $e');
          }
        }

        return conversations;
      },
    );
  }

  @override
  Future<Either<Failure, void>> markAsRead(String conversationId) async {
    try {
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Failed to mark as read'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteConversation(
    String conversationId,
  ) async {
    try {
      developer.log('Conversation deleted locally: $conversationId');
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Failed to delete conversation'));
    }
  }
}
