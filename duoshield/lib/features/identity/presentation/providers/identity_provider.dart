import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/signal_session_manager.dart';
import '../../../../services/storage_service.dart';
import '../../data/datasources/identity_local_datasource.dart';
import '../../data/datasources/identity_remote_datasource.dart';
import '../../data/repositories/identity_repository_impl.dart';
import '../../domain/entities/identity_entity.dart';
import '../../domain/repositories/identity_repository.dart';
import '../../domain/usecases/generate_identity_usecase.dart';
import '../../domain/usecases/restore_identity_usecase.dart';

// ==================== SERVICE PROVIDERS ====================

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final signalSessionManagerProvider = Provider<SignalSessionManager>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SignalSessionManager(storage: storage);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return NotificationService(firebaseService: firebaseService);
});

// ==================== DATASOURCE PROVIDERS ====================

final identityLocalDatasourceProvider = Provider<IdentityLocalDatasource>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return IdentityLocalDatasource(storage: storage);
});

final identityRemoteDatasourceProvider = Provider<IdentityRemoteDatasource>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final signalManager = ref.watch(signalSessionManagerProvider);
  return IdentityRemoteDatasource(
    firebaseService: firebaseService,
    notificationService: notificationService,
    signalManager: signalManager,
  );
});

// ==================== REPOSITORY PROVIDER ====================

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  final localDatasource = ref.watch(identityLocalDatasourceProvider);
  final remoteDatasource = ref.watch(identityRemoteDatasourceProvider);
  return IdentityRepositoryImpl(
    localDatasource: localDatasource,
    remoteDatasource: remoteDatasource,
  );
});

// ==================== USE CASE PROVIDERS ====================

final generateIdentityUseCaseProvider = Provider<GenerateIdentityUseCase>((ref) {
  final repository = ref.watch(identityRepositoryProvider);
  return GenerateIdentityUseCase(repository);
});

final restoreIdentityUseCaseProvider = Provider<RestoreIdentityUseCase>((ref) {
  final repository = ref.watch(identityRepositoryProvider);
  return RestoreIdentityUseCase(repository);
});

// ==================== STATE ====================

/// Identity state for UI consumption
class IdentityState {
  final bool isLoading;
  final IdentityEntity? identity;
  final String? seedPhrase;
  final Failure? failure;
  final bool seedConfirmed;
  final bool isPublished;

  const IdentityState({
    this.isLoading = false,
    this.identity,
    this.seedPhrase,
    this.failure,
    this.seedConfirmed = false,
    this.isPublished = false,
  });

  IdentityState copyWith({
    bool? isLoading,
    IdentityEntity? identity,
    String? seedPhrase,
    Failure? failure,
    bool? seedConfirmed,
    bool? isPublished,
  }) {
    return IdentityState(
      isLoading: isLoading ?? this.isLoading,
      identity: identity ?? this.identity,
      seedPhrase: seedPhrase ?? this.seedPhrase,
      failure: failure,
      seedConfirmed: seedConfirmed ?? this.seedConfirmed,
      isPublished: isPublished ?? this.isPublished,
    );
  }

  bool get hasError => failure != null;
  bool get hasIdentity => identity != null && identity!.publicKey.isNotEmpty;
}

// ==================== STATE NOTIFIER ====================

class IdentityNotifier extends StateNotifier<IdentityState> {
  final GenerateIdentityUseCase _generateUseCase;
  final RestoreIdentityUseCase _restoreUseCase;
  final IdentityRepository _repository;

  IdentityNotifier({
    required GenerateIdentityUseCase generateUseCase,
    required RestoreIdentityUseCase restoreUseCase,
    required IdentityRepository repository,
  })  : _generateUseCase = generateUseCase,
        _restoreUseCase = restoreUseCase,
        _repository = repository,
        super(const IdentityState());

  /// Generate a new identity
  Future<void> generateIdentity() async {
    state = state.copyWith(isLoading: true, failure: null);

    final result = await _generateUseCase.call();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          failure: failure,
        );
      },
      (seedPhrase) {
        state = state.copyWith(
          isLoading: false,
          seedPhrase: seedPhrase,
        );
      },
    );
  }

  /// Confirm the seed phrase
  Future<void> confirmSeedPhrase() async {
    state = state.copyWith(isLoading: true, failure: null);

    final result = await _generateUseCase.confirmSeed();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          failure: failure,
        );
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          seedConfirmed: true,
        );
      },
    );
  }

  /// Publish identity to Firestore
  Future<void> publishIdentity() async {
    state = state.copyWith(isLoading: true, failure: null);

    final result = await _generateUseCase.publishToFirestore();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          failure: failure,
        );
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          isPublished: true,
        );
      },
    );
  }

  /// Restore identity from seed phrase
  Future<void> restoreIdentity(String mnemonic) async {
    state = state.copyWith(isLoading: true, failure: null);

    final result = await _restoreUseCase.call(mnemonic);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          failure: failure,
        );
      },
      (identity) {
        state = state.copyWith(
          isLoading: false,
          identity: identity,
          seedConfirmed: true,
        );
      },
    );
  }

  /// Check if identity exists
  Future<bool> checkExistingIdentity() async {
    try {
      final result = await _repository.getCurrentIdentity();
      return result.fold(
        (failure) => false,
        (identity) => identity != null && identity.publicKey.isNotEmpty,
      );
    } catch (e) {
      developer.log('Error checking identity: $e');
      return false;
    }
  }

  /// Get the current public key
  Future<String?> getPublicKey() async {
    final result = await _repository.getPublicKey();
    return result.fold(
      (failure) => null,
      (publicKey) => publicKey,
    );
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(failure: null);
  }
}

// ==================== STATE NOTIFIER PROVIDER ====================

final identityProvider =
    StateNotifierProvider<IdentityNotifier, IdentityState>((ref) {
  final generateUseCase = ref.watch(generateIdentityUseCaseProvider);
  final restoreUseCase = ref.watch(restoreIdentityUseCaseProvider);
  final repository = ref.watch(identityRepositoryProvider);
  return IdentityNotifier(
    generateUseCase: generateUseCase,
    restoreUseCase: restoreUseCase,
    repository: repository,
  );
});
