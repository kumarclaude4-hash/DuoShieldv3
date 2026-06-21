import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/settings_repository.dart';

/// Use case for wiping all local data.
/// Used for both logout and duress PIN scenarios.
class WipeLocalDataUseCase {
  final SettingsRepository _repository;

  const WipeLocalDataUseCase(this._repository);

  /// Execute the wipe operation.
  /// Returns void on success.
  Future<Either<Failure, void>> call() async {
    return await _repository.wipeLocalData();
  }

  /// Check if PIN is set.
  Future<bool> isPinSet() async {
    return await _repository.isPinSet();
  }

  /// Verify PIN.
  Future<Either<Failure, bool>> verifyPin(String pin) async {
    return await _repository.verifyPin(pin);
  }

  /// Verify duress PIN.
  Future<Either<Failure, bool>> verifyDuressPin(String pin) async {
    return await _repository.verifyDuressPin(pin);
  }
}
