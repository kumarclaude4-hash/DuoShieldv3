import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';

/// Repository interface for settings operations.
/// Handles PIN management, duress PIN, and data wipe.
abstract class SettingsRepository {
  /// Store a hashed PIN in secure storage.
  Future<Either<Failure, void>> storePinHash(String pinHash);

  /// Get the stored PIN hash.
  Future<Either<Failure, String?>> getPinHash();

  /// Store a hashed duress PIN in secure storage.
  Future<Either<Failure, void>> storeDuressPinHash(String pinHash);

  /// Get the stored duress PIN hash.
  Future<Either<Failure, String?>> getDuressPinHash();

  /// Verify a PIN against the stored hash.
  Future<Either<Failure, bool>> verifyPin(String pin);

  /// Verify a duress PIN against the stored hash.
  Future<Either<Failure, bool>> verifyDuressPin(String pin);

  /// Check if a normal PIN is set.
  Future<bool> isPinSet();

  /// Check if a duress PIN is set.
  Future<bool> isDuressPinSet();

  /// Get the number of failed attempts.
  Future<Either<Failure, int>> getFailedAttempts();

  /// Increment failed attempts.
  Future<Either<Failure, void>> incrementFailedAttempts();

  /// Reset failed attempts.
  Future<Either<Failure, void>> resetFailedAttempts();

  /// Get lock-until timestamp.
  Future<Either<Failure, DateTime?>> getLockUntil();

  /// Set lock-until timestamp.
  Future<Either<Failure, void>> setLockUntil(DateTime? lockUntil);

  /// Calculate lock duration based on failed attempts (exponential backoff).
  Duration calculateLockDuration(int failedAttempts);

  /// Wipe all local data (logout / duress PIN).
  Future<Either<Failure, void>> wipeLocalData();
}
