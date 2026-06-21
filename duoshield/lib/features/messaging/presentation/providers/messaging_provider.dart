import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/identity/domain/repositories/identity_repository.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/signal_session_manager.dart';
import '../../../../services/storage_service.dart';
import '../../../contacts/domain/entities/contact_entity.dart';
import '../../../contacts/presentation/providers/contacts_provider.dart';
import '../../../identity/presentation/providers/identity_provider.dart';
import '../../data/datasources/messaging_local_datasource.dart';
import '../../data/datasources/messaging_remote_datasource.dart';
import '../../data/repositories/messaging_repository_impl.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../../domain/usecases/receive_messages_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';

// ==================== SERVICE PROVIDERS ====================

final _firebaseServiceForMessagingProvider = Provider<FirebaseService>((ref) {
  return ref.watch(firebaseServiceProvider);
});

final _signalManagerForMessagingProvider = Provider<SignalSessionManager>((ref) {
  return ref.watch(signalSessionManagerProvider);
});

// ==================== DATASOURCE PROVIDERS ====================

final messagingLocalDatasourceProvider = Provider<MessagingLocalDatasource>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return MessagingLocalDatasource(storage: storage);
});

final messagingRemoteDatasourceProvider = Provider<MessagingRemoteDatasource>((ref) {
  final firebaseService = ref.watch(_firebaseServiceForMessagingProvider);
  return MessagingRemoteDatasource(firebaseService: firebaseService);
});

// ==================== REPOSITORY PROVIDER ====================

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final localDatasource = ref.watch(messagingLocalDatasourceProvider);
  final remoteDatasource = ref.watch(messagingRemoteDatasourceProvider);
  final identityRepository = ref.watch(identityRepositoryProvider);
  final signalManager = ref.watch(_signalManagerForMessagingProvider);
  final firebaseService = ref.watch(_firebaseServiceForMessagingProvider);
  return MessagingRepositoryImpl(
    localDatasource: localDatasource,
    remoteDatasource: remoteDatasource,
    identityRepository: identityRepository,
    signalManager: signalManager,
    firebaseService: firebaseService,
  );
});

// ==================== USE CASE PROVIDERS ====================

final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  final repository = ref.watch(messagingRepositoryProvider);
  return SendMessageUseCase(repository);
});

final receiveMessagesUseCaseProvider = Provider<ReceiveMessagesUseCase>((ref) {
  final repository = ref.watch(messagingRepositoryProvider);
  return ReceiveMessagesUseCase(repository);
});

// ==================== CONVERSATION LIST STATE ====================

class ConversationListState {
  final bool isLoading;
  final List<ConversationEntity> conversations;
  final Failure? failure;

  const ConversationListState({
    this.isLoading = false,
    this.conversations = const [],
    this.failure,
  });

  ConversationListState copyWith({
    bool? isLoading,
    List<ConversationEntity>? conversations,
    Failure? failure,
  }) {
    return ConversationListState(
      isLoading: isLoading ?? this.isLoading,
      conversations: conversations ?? this.conversations,
      failure: failure,
    );
  }

  bool get isEmpty => conversations.isEmpty && !isLoading;
}

class ConversationListNotifier extends StateNotifier<ConversationListState> {
  final ReceiveMessagesUseCase _receiveUseCase;
  StreamSubscription<List<ConversationEntity>>? _subscription;

  ConversationListNotifier({
    required ReceiveMessagesUseCase receiveUseCase,
  })  : _receiveUseCase = receiveUseCase,
        super(const ConversationListState()) {
    _listenToConversations();
  }

  void _listenToConversations() {
    try {
      state = state.copyWith(isLoading: true);

      _subscription = _receiveUseCase.listenToConversations().listen(
        (conversations) {
          state = state.copyWith(
            isLoading: false,
            conversations: conversations,
          );
        },
        onError: (e) {
          developer.log('Conversation stream error: $e');
          state = state.copyWith(isLoading: false);
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, ConversationListState>((ref) {
  final receiveUseCase = ref.watch(receiveMessagesUseCaseProvider);
  return ConversationListNotifier(receiveUseCase: receiveUseCase);
});

// ==================== CHAT STATE ====================

class ChatState {
  final bool isLoading;
  final bool isSending;
  final List<MessageEntity> messages;
  final Failure? failure;
  final ConversationEntity? conversation;

  const ChatState({
    this.isLoading = false,
    this.isSending = false,
    this.messages = const [],
    this.failure,
    this.conversation,
  });

  ChatState copyWith({
    bool? isLoading,
    bool? isSending,
    List<MessageEntity>? messages,
    Failure? failure,
    ConversationEntity? conversation,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      messages: messages ?? this.messages,
      failure: failure,
      conversation: conversation ?? this.conversation,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final SendMessageUseCase _sendUseCase;
  final ReceiveMessagesUseCase _receiveUseCase;
  final MessagingRepository _repository;
  StreamSubscription<List<MessageEntity>>? _messageSubscription;
  final String conversationId;

  ChatNotifier({
    required this.conversationId,
    required SendMessageUseCase sendUseCase,
    required ReceiveMessagesUseCase receiveUseCase,
    required MessagingRepository repository,
  })  : _sendUseCase = sendUseCase,
        _receiveUseCase = receiveUseCase,
        _repository = repository,
        super(const ChatState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadLocalMessages();
    _listenToRemoteMessages();
  }

  Future<void> _loadLocalMessages() async {
    state = state.copyWith(isLoading: true);

    final result = await _receiveUseCase.getLocalMessages(conversationId);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false);
      },
      (messages) {
        state = state.copyWith(
          isLoading: false,
          messages: messages,
        );
      },
    );
  }

  void _listenToRemoteMessages() {
    try {
      _messageSubscription =
          _receiveUseCase.listenToMessages(conversationId).listen(
        (messages) {
          // Merge with existing messages, keeping plaintext cache
          final mergedMessages = _mergeMessages(state.messages, messages);
          state = state.copyWith(messages: mergedMessages);
        },
        onError: (e) {
          developer.log('Message stream error: $e');
        },
      );
    } catch (e) {
      developer.log('Failed to listen to messages: $e');
    }
  }

  /// Merge remote messages with local, preserving plaintext cache
  List<MessageEntity> _mergeMessages(
    List<MessageEntity> local,
    List<MessageEntity> remote,
  ) {
    final merged = <String, MessageEntity>{};

    // Add local messages first (may have plaintext)
    for (final msg in local) {
      merged[msg.id] = msg;
    }

    // Add/overwrite with remote, but preserve plaintext
    for (final msg in remote) {
      final existing = merged[msg.id];
      if (existing != null && existing.hasPlaintext) {
        merged[msg.id] = msg.copyWith(plaintextCache: existing.plaintextCache);
      } else {
        merged[msg.id] = msg;
      }
    }

    // Sort by timestamp
    final result = merged.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return result;
  }

  /// Send a message
  Future<bool> sendMessage({
    required String recipientUid,
    required String recipientPublicKey,
    required String plaintext,
  }) async {
    if (plaintext.trim().isEmpty) return false;

    state = state.copyWith(isSending: true, failure: null);

    final result = await _sendUseCase.call(
      conversationId: conversationId,
      recipientUid: recipientUid,
      recipientPublicKey: recipientPublicKey,
      plaintext: plaintext,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isSending: false, failure: failure);
        return false;
      },
      (message) {
        final updated = [...state.messages, message];
        state = state.copyWith(isSending: false, messages: updated);
        return true;
      },
    );
  }

  /// Decrypt all messages in the conversation
  Future<void> decryptMessages(String contactPublicKey) async {
    if (state.messages.isEmpty) return;

    final result = await _receiveUseCase.decryptMessages(
      state.messages,
      contactPublicKey,
    );

    result.fold(
      (failure) {
        developer.log('Decryption failed: ${failure.message}');
      },
      (decrypted) {
        state = state.copyWith(messages: decrypted);
      },
    );
  }

  /// Mark conversation as read
  Future<void> markAsRead() async {
    await _receiveUseCase.markAsRead(conversationId);
  }

  void clearError() {
    state = state.copyWith(failure: null);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, conversationId) {
    final sendUseCase = ref.watch(sendMessageUseCaseProvider);
    final receiveUseCase = ref.watch(receiveMessagesUseCaseProvider);
    final repository = ref.watch(messagingRepositoryProvider);
    return ChatNotifier(
      conversationId: conversationId,
      sendUseCase: sendUseCase,
      receiveUseCase: receiveUseCase,
      repository: repository,
    );
  },
);
