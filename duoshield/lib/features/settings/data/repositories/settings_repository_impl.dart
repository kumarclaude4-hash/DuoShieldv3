import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:bcrypt/bcrypt.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../services/storage_service.dart';
import '../../domain/repositories/settings_repository.dart';

/// Implementation of [SettingsRepository].
/// Uses bcrypt for PIN hashing and flutter_secure_storage for persistence.
class SettingsRepositoryImpl implements SettingsRepository {
  final StorageService _storage;

  // bcrypt work factor (higher = more secure but slower)
  static const int _bcryptRounds = 12;

  // Maximum failed attempts before lock
  static const int _maxFailedAttempts = 5;

  // Base lock duration in seconds
  static const int _baseLockSeconds = 30;

  SettingsRepositoryImpl({required StorageService storage})
      : _storage = storage;

  @override
  Future<Either<Failure, void>> storePinHash(String pinHash) async {
    try {
      await _storage.storePinHash(pinHash);
      return const Right(null);
    } on SecureStorageException catch (e) {
      return Left(SecureStorageFailure(e.message));
    } catch (e) {
      return Left(SecureStorageFailure('Failed to store PIN hash'));
    }
  }

  @override
  Future<Either<Failure, String?>> getPinHash() async {
    try {
      final hash = await _storage.getPinHash();
      return Right(hash);
    } on SecureStorageException catch (e) {
      return Left(SecureStorageFailure(e.message));
    } catch (e) {
      return Left(SecureStorageFailure('Failed to get PIN hash'));
    }
  }

  @override
  Future<Either<Failure, void>> storeDuressPinHash(String pinHash) async {
    try {
      await _storage.storeDuressPinHash(pinHash);
      return const Right(null);
    } on SecureStorageException catch (e) {
      return Left(SecureStorageFailure(e.message));
    } catch (e) {
      return Left(SecureStorageFailure('Failed to store duress PIN hash'));
    }
  }

  @override
  Future<Either<Failure, String?>> getDuressPinHash() async {
    try {
      final hash = await _storage.getDuressPinHash();
      return Right(hash);
    } on SecureStorageException catch (e) {
      return Left(SecureStorageFailure(e.message));
    } catch (e) {
      return Left(SecureStorageFailure('Failed to get duress PIN hash'));
    }
  }

  @override
  Future<Either<Failure, bool>> verifyPin(String pin) async {
    try {
      final storedHash = await _storage.getPinHash();
      if (storedHash == null || storedHash.isEmpty) {
        return const Right(false);
      }
      final isValid = BCrypt.checkpw(pin, storedHash);
      return Right(isValid);
    } catch (e) {
      return Left(SecureStorageFailure('Failed to verify PIN'));
    }
  }

  @override
  Future<Either<Failure, bool>> verifyDuressPin(String pin) async {
    try {
      final storedHash = await _storage.getDuressPinHash();
      if (storedHash == null || storedHash.isEmpty) {
        return const Right(false);
      }
      final isValid = BCrypt.checkpw(pin, storedHash);
      return Right(isValid);
    } catch (e) {
      return Left(SecureStorageFailure('Failed to verify duress PIN'));
    }
  }

  @override
  Future<bool> isPinSet() async {
    try {
      final hash = await _storage.getPinHash();
      return hash != null && hash.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isDuressPinSet() async {
    try {
      final hash = await _storage.getDuressPinHash();
      return hash != null && hash.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Either<Failure, int>> getFailedAttempts() async {
    try {
      final count = await _storage.getFailedAttempts();
      return Right(count);
    } catch (e) {
      return Left(SecureStorageFailure('Failed to get failed attempts'));
    }
  }

  @override
  Future<Either<Failure, void>> incrementFailedAttempts() async {
    try {
      final current = await _storage.getFailedAttempts();
      await _storage.storeFailedAttempts(current + 1);
      return const Right(null);
    } catch (e) {
      return Left(SecureStorageFailure('Failed to increment attempts'));
    }
  }

  @override
  Future<Either<Failure, void>> resetFailedAttempts() async {
    try {
      await _storage.storeFailedAttempts(0);
      return const Right(null);
    } catch (e) {
      return Left(SecureStorageFailure('Failed to reset attempts'));
    }
  }

  @override
  Future<Either<Failure, DateTime?>> getLockUntil() async {
    try {
      final lockUntil = await _storage.getLockUntil();
      return Right(lockUntil);
    } catch (e) {
      return Left(SecureStorageFailure('Failed to get lock until'));
    }
  }

  @override
  Future<Either<Failure, void>> setLockUntil(DateTime? lockUntil) async {
    try {
      await _storage.storeLockUntil(lockUntil);
      return const Right(null);
    } catch (e) {
      return Left(SecureStorageFailure('Failed to set lock until'));
    }
  }

  /// Calculate lock duration using exponential backoff.
  /// Formula: baseSeconds * 2^(failedAttempts - maxAttempts)
  /// For attempts >= 5: 30s, 60s, 120s, 240s, etc.
  @override
  Duration calculateLockDuration(int failedAttempts) {
    if (failedAttempts < _maxFailedAttempts) {
      return Duration.zero;
    }
    final multiplier = math.pow(2, failedAttempts - _maxFailedAttempts);
    final seconds = _baseLockSeconds * multiplier;
    return Duration(seconds: seconds.toInt());
  }

  @override
  Future<Either<Failure, void>> wipeLocalData() async {
    try {
      developer.log('WIPING ALL LOCAL DATA');

      // Clear secure storage
      await _storage.clearAllSecureStorage();

      // Wipe all Hive data
      await _storage.wipeAllLocalData();

      developer.log('All local data wiped successfully');
      return const Right(null);
    } on SecureStorageException catch (e) {
      return Left(SecureStorageFailure(e.message));
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      developer.log('Data wipe failed: $e');
      return Left(UnknownFailure('Failed to wipe local data'));
    }
  }

  /// Hash a PIN using bcrypt.
  String hashPin(String pin) {
    return BCrypt.hashpw(pin, BCrypt.gensalt(rounds: _bcryptRounds));
  }
}
