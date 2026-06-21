import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../services/storage_service.dart';
import '../../../identity/presentation/providers/identity_provider.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/wipe_local_data_usecase.dart';

// ==================== REPOSITORY PROVIDER ====================

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsRepositoryImpl(storage: storage);
});

final wipeLocalDataUseCaseProvider = Provider<WipeLocalDataUseCase>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return WipeLocalDataUseCase(repository);
});

// ==================== APP LOCK STATE ====================

class AppLockState {
  final bool isLocked;
  final int failedAttempts;
  final DateTime? lockUntil;
  final bool isDuressActivated;
  final Failure? failure;

  const AppLockState({
    this.isLocked = true,
    this.failedAttempts = 0,
    this.lockUntil,
    this.isDuressActivated = false,
    this.failure,
  });

  AppLockState copyWith({
    bool? isLocked,
    int? failedAttempts,
    DateTime? lockUntil,
    bool? isDuressActivated,
    Failure? failure,
  }) {
    return AppLockState(
      isLocked: isLocked ?? this.isLocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockUntil: lockUntil ?? this.lockUntil,
      isDuressActivated: isDuressActivated ?? this.isDuressActivated,
      failure: failure,
    );
  }

  /// Check if the app is currently time-locked
  bool get isTimeLocked {
    if (lockUntil == null) return false;
    return DateTime.now().isBefore(lockUntil!);
  }

  /// Get remaining lock duration
  Duration? get remainingLockDuration {
    if (lockUntil == null) return null;
    final remaining = lockUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }
}

// ==================== APP LOCK NOTIFIER ====================

class AppLockNotifier extends StateNotifier<AppLockState> {
  final SettingsRepository _repository;
  final WipeLocalDataUseCase _wipeUseCase;

  // Lock timeout when app goes to background
  final Duration lockTimeout = const Duration(seconds: 30);

  AppLockNotifier({
    required SettingsRepository repository,
    required WipeLocalDataUseCase wipeUseCase,
  })  : _repository = repository,
        _wipeUseCase = wipeUseCase,
        super(const AppLockState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if PIN is set
    final isPinSet = await _repository.isPinSet();
    if (!isPinSet) {
      // No PIN set, don't lock
      state = state.copyWith(isLocked: false);
      return;
    }

    // Check if time-locked
    final lockUntilResult = await _repository.getLockUntil();
    lockUntilResult.fold(
      (failure) {},
      (lockUntil) {
        if (lockUntil != null && DateTime.now().isBefore(lockUntil)) {
          state = state.copyWith(
            isLocked: true,
            lockUntil: lockUntil,
          );
        } else {
          state = state.copyWith(isLocked: true);
        }
      },
    );

    // Load failed attempts
    final attemptsResult = await _repository.getFailedAttempts();
    attemptsResult.fold(
      (failure) {},
      (attempts) {
        state = state.copyWith(failedAttempts: attempts);
      },
    );
  }

  /// Check if PIN is set
  Future<bool> isPinSet() async {
    return await _repository.isPinSet();
  }

  /// Lock the app
  void lockApp() {
    state = state.copyWith(isLocked: true);
  }

  /// Unlock with PIN
  Future<bool> unlockWithPin(String pin) async {
    // Check time lock
    if (state.isTimeLocked) {
      state = state.copyWith(
        failure: PinFailure('App is locked. Please wait.'),
      );
      return false;
    }

    // Verify normal PIN
    final verifyResult = await _repository.verifyPin(pin);
    final isValid = verifyResult.fold(
      (failure) => false,
      (valid) => valid,
    );

    if (isValid) {
      // Success - reset attempts and unlock
      await _repository.resetFailedAttempts();
      await _repository.setLockUntil(null);
      state = state.copyWith(
        isLocked: false,
        failedAttempts: 0,
        lockUntil: null,
        failure: null,
      );
      return true;
    }

    // Failed - check if it's a duress PIN
    final duressResult = await _repository.verifyDuressPin(pin);
    final isDuress = duressResult.fold(
      (failure) => false,
      (valid) => valid,
    );

    if (isDuress) {
      // DURESS PIN ACTIVATED
      developer.log('DURESS PIN ACTIVATED - Wiping all data');
      await _activateDuress();
      return true; // Return true so UI navigates away
    }

    // Normal failed attempt
    // FIX #8: attemptsResult was unused (Either<Failure, void>) — result discarded
    await _repository.incrementFailedAttempts();
    final attempts = state.failedAttempts + 1;

    // Check if should time-lock
    final lockDuration = _repository.calculateLockDuration(attempts);
    if (lockDuration > Duration.zero) {
      final lockUntil = DateTime.now().add(lockDuration);
      await _repository.setLockUntil(lockUntil);
      state = state.copyWith(
        failedAttempts: attempts,
        lockUntil: lockUntil,
        failure: PinFailure('Too many failed attempts. App locked.'),
      );
    } else {
      state = state.copyWith(
        failedAttempts: attempts,
        failure: PinFailure(
          'Incorrect PIN. ${5 - attempts} attempts remaining.',
        ),
      );
    }

    return false;
  }

  /// Activate duress PIN - wipe all data silently
  Future<void> _activateDuress() async {
    try {
      state = state.copyWith(isDuressActivated: true);

      // Wipe all local data
      await _wipeUseCase.call();

      developer.log('Duress PIN: All local data wiped');
    } catch (e) {
      developer.log('Duress PIN wipe failed: $e');
    }
  }

  /// Set a new normal PIN
  Future<bool> setPin(String pin) async {
    try {
      if (pin.length != 6) {
        state = state.copyWith(
          failure: PinFailure('PIN must be 6 digits'),
        );
        return false;
      }

      final repository = _repository as SettingsRepositoryImpl;
      final hash = repository.hashPin(pin);
      final result = await _repository.storePinHash(hash);

      return result.fold(
        (failure) {
          state = state.copyWith(failure: failure);
          return false;
        },
        (_) {
          state = state.copyWith(failure: null);
          return true;
        },
      );
    } catch (e) {
      state = state.copyWith(
        failure: PinFailure('Failed to set PIN'),
      );
      return false;
    }
  }

  /// Set a new duress PIN
  Future<bool> setDuressPin(String pin, String normalPin) async {
    try {
      if (pin.length != 6) {
        state = state.copyWith(
          failure: PinFailure('Duress PIN must be 6 digits'),
        );
        return false;
      }

      // Duress PIN must differ from normal PIN
      if (pin == normalPin) {
        state = state.copyWith(
          failure: PinFailure('Duress PIN cannot match normal PIN'),
        );
        return false;
      }

      final repository = _repository as SettingsRepositoryImpl;
      final hash = repository.hashPin(pin);
      final result = await _repository.storeDuressPinHash(hash);

      return result.fold(
        (failure) {
          state = state.copyWith(failure: failure);
          return false;
        },
        (_) {
          state = state.copyWith(failure: null);
          return true;
        },
      );
    } catch (e) {
      state = state.copyWith(
        failure: PinFailure('Failed to set duress PIN'),
      );
      return false;
    }
  }

  /// Clear stored PINs (for testing or reset)
  Future<void> clearPins() async {
    final wipeResult = await _repository.wipeLocalData();
    wipeResult.fold(
      (failure) {},
      (_) {
        state = const AppLockState(isLocked: false);
      },
    );
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(failure: null);
  }
}

// ==================== STATE NOTIFIER PROVIDER ====================

final appLockProvider =
    StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  final wipeUseCase = ref.watch(wipeLocalDataUseCaseProvider);
  return AppLockNotifier(
    repository: repository,
    wipeUseCase: wipeUseCase,
  );
});
