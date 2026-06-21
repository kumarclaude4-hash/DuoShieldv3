import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/identity_entity.dart';
import '../repositories/identity_repository.dart';

/// Use case for restoring identity from a BIP39 seed phrase.
/// Validates the mnemonic, regenerates the keypair, and verifies against stored public key.
class RestoreIdentityUseCase {
  final IdentityRepository _repository;

  const RestoreIdentityUseCase(this._repository);

  /// Execute the use case.
  /// [mnemonic] - The 24-word BIP39 seed phrase.
  /// Returns the restored IdentityEntity on success, or a Failure on error.
  Future<Either<Failure, IdentityEntity>> call(String mnemonic) async {
    return await _repository.restoreIdentity(mnemonic);
  }

  /// Quick check if an identity already exists locally.
  Future<bool> hasExistingIdentity() async {
    return await _repository.hasIdentity();
  }
}
