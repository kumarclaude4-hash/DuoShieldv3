import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/identity_entity.dart';
import '../../domain/repositories/identity_repository.dart';
import '../datasources/identity_local_datasource.dart';
import '../datasources/identity_remote_datasource.dart';

/// Implementation of [IdentityRepository].
/// Coordinates between local storage and Firebase for identity operations.
class IdentityRepositoryImpl implements IdentityRepository {
  final IdentityLocalDatasource _localDatasource;
  final IdentityRemoteDatasource _remoteDatasource;

  IdentityRepositoryImpl({
    required IdentityLocalDatasource localDatasource,
    required IdentityRemoteDatasource remoteDatasource,
  })  : _localDatasource = localDatasource,
        _remoteDatasource = remoteDatasource;

  @override
  Future<Either<Failure, String>> generateIdentity() async {
    try {
      final seedPhrase = await _localDatasource.generateAndStoreKeys();
      developer.log('Identity generated successfully');
      return Right(seedPhrase);
    } on IdentityException catch (e) {
      return Left(IdentityFailure(e.message));
    } on SecureStorageException catch (e) {
      return Left(SecureStorageFailure(e.message));
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e, stackTrace) {
      developer.log('Unexpected error generating identity: $e');
      return Left(IdentityFailure('Failed to generate identity'));
    }
  }

  @override
  Future<Either<Failure, IdentityEntity>> restoreIdentity(String mnemonic) async {
    try {
      final model = await _localDatasource.restoreFromSeedPhrase(mnemonic);
      developer.log('Identity restored successfully');
      return Right(model.toEntity());
    } on SeedPhraseException catch (e) {
      return Left(SeedPhraseFailure(e.message));
    } on IdentityException catch (e) {
      return Left(IdentityFailure(e.message));
    } on SecureStorageException catch (e) {
      return Left(SecureStorageFailure(e.message));
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e, stackTrace) {
      developer.log('Unexpected error restoring identity: $e');
      return Left(IdentityFailure('Failed to restore identity'));
    }
  }

  @override
  Future<Either<Failure, IdentityEntity?>> getCurrentIdentity() async {
    try {
      final model = await _localDatasource.getStoredIdentity();
      if (model == null) {
        return const Right(null);
      }
      return Right(model.toEntity());
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e, stackTrace) {
      developer.log('Unexpected error getting current identity: $e');
      return Left(IdentityFailure('Failed to get identity'));
    }
  }

  @override
  Future<bool> hasIdentity() async {
    try {
      return await _localDatasource.hasIdentity();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Either<Failure, String?>> getPublicKey() async {
    try {
      final publicKey = await _localDatasource.getPublicKey();
      return Right(publicKey);
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(IdentityFailure('Failed to get public key'));
    }
  }

  @override
  Future<Either<Failure, String?>> getPrivateKey() async {
    try {
      final privateKey = await _localDatasource.getPrivateKey();
      return Right(privateKey);
    } on SecureStorageException catch (e) {
      return Left(SecureStorageFailure(e.message));
    } catch (e) {
      return Left(IdentityFailure('Failed to get private key'));
    }
  }

  @override
  Future<Either<Failure, void>> confirmSeedPhrase() async {
    try {
      await _localDatasource.confirmSeedPhrase();
      return const Right(null);
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(IdentityFailure('Failed to confirm seed phrase'));
    }
  }

  @override
  Future<Either<Failure, void>> storeUid(String uid) async {
    try {
      await _localDatasource.storeUid(uid);
      return const Right(null);
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(IdentityFailure('Failed to store UID'));
    }
  }

  @override
  Future<Either<Failure, void>> publishIdentityToFirestore() async {
    try {
      final publicKey = await _localDatasource.getPublicKey();
      if (publicKey == null || publicKey.isEmpty) {
        return Left(IdentityFailure('No public key found'));
      }

      final uid = await _remoteDatasource.publishIdentity(publicKey);

      // Store UID locally
      await _localDatasource.storeUid(uid);

      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(FirebaseFailure(e.message));
    } catch (e) {
      developer.log('Failed to publish identity: $e');
      return Left(FirebaseFailure('Failed to publish identity'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteIdentity() async {
    try {
      // Sign out from Firebase first
      try {
        await _remoteDatasource.signOut();
      } catch (e) {
        developer.log('Firebase sign out during delete: $e');
      }

      // Delete all local data
      await _localDatasource.deleteIdentity();

      return const Right(null);
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(IdentityFailure('Failed to delete identity'));
    }
  }
}
