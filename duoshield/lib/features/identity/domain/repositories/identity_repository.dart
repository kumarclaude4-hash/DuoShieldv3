import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/identity_entity.dart';

/// Repository interface for identity management operations.
/// Handles key generation, storage, retrieval, and Firebase integration.
abstract class IdentityRepository {
  /// Generate a new identity with BIP39 seed phrase and Ed25519 keypair.
  /// Returns the seed phrase (shown once) and stores keys securely.
  Future<Either<Failure, String>> generateIdentity();

  /// Restore identity from a BIP39 seed phrase.
  /// Validates the mnemonic and regenerates the keypair.
  Future<Either<Failure, IdentityEntity>> restoreIdentity(String mnemonic);

  /// Get the current identity from local storage.
  /// Returns null if no identity exists.
  Future<Either<Failure, IdentityEntity?>> getCurrentIdentity();

  /// Check if an identity exists locally.
  Future<bool> hasIdentity();

  /// Get the stored public key.
  Future<Either<Failure, String?>> getPublicKey();

  /// Get the private key from secure storage.
  /// Returns null if no private key is stored.
  Future<Either<Failure, String?>> getPrivateKey();

  /// Mark the seed phrase as confirmed.
  Future<Either<Failure, void>> confirmSeedPhrase();

  /// Store the Firebase UID locally.
  Future<Either<Failure, void>> storeUid(String uid);

  /// Publish public key and pre-key bundle to Firestore.
  Future<Either<Failure, void>> publishIdentityToFirestore();

  /// Delete all local identity data (logout).
  Future<Either<Failure, void>> deleteIdentity();
}
