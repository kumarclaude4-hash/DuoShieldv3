import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/identity_entity.dart';
import '../repositories/identity_repository.dart';

/// Use case for generating a new cryptographic identity.
/// Generates a 24-word BIP39 seed phrase and derives an Ed25519 keypair.
class GenerateIdentityUseCase {
  final IdentityRepository _repository;

  const GenerateIdentityUseCase(this._repository);

  /// Execute the use case.
  /// Returns the seed phrase string on success, or a Failure on error.
  Future<Either<Failure, String>> call() async {
    return await _repository.generateIdentity();
  }

  /// Confirm the seed phrase after user verification.
  Future<Either<Failure, void>> confirmSeed() async {
    return await _repository.confirmSeedPhrase();
  }

  /// Publish the identity to Firestore after generation.
  Future<Either<Failure, void>> publishToFirestore() async {
    return await _repository.publishIdentityToFirestore();
  }
}
