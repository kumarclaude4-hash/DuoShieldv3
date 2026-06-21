import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/key_utils.dart';
import '../../../../features/identity/domain/repositories/identity_repository.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/repositories/contact_repository.dart';
import '../datasources/contact_local_datasource.dart';
import '../datasources/contact_remote_datasource.dart';

/// Implementation of [ContactRepository].
class ContactRepositoryImpl implements ContactRepository {
  final ContactLocalDatasource _localDatasource;
  final ContactRemoteDatasource _remoteDatasource;
  final IdentityRepository _identityRepository;

  ContactRepositoryImpl({
    required ContactLocalDatasource localDatasource,
    required ContactRemoteDatasource remoteDatasource,
    required IdentityRepository identityRepository,
  })  : _localDatasource = localDatasource,
        _remoteDatasource = remoteDatasource,
        _identityRepository = identityRepository;

  @override
  Future<Either<Failure, ContactEntity>> addContact({
    required String name,
    required String publicKey,
  }) async {
    try {
      // Validate name
      if (name.trim().isEmpty) {
        return Left(ValidationFailure('Contact name cannot be empty'));
      }

      // Validate public key format
      if (!KeyUtils.isValidPublicKey(publicKey)) {
        return Left(ValidationFailure('Invalid public key format'));
      }

      // Normalize public key
      final normalizedKey = KeyUtils.normalizePublicKey(publicKey);

      // Check for duplicate
      if (await _localDatasource.contactExists(normalizedKey)) {
        return Left(AlreadyExistsFailure('Contact with this public key already exists'));
      }

      // Store locally
      final model = await _localDatasource.storeContact(
        name: name,
        publicKey: normalizedKey,
      );

      // Backup to Firestore
      await _backupContacts();

      developer.log('Contact added: ${model.id}');
      return Right(model.toEntity());
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on AlreadyExistsException catch (e) {
      return Left(AlreadyExistsFailure(e.message));
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(FirebaseFailure(e.message));
    } catch (e) {
      developer.log('Unexpected error adding contact: $e');
      return Left(UnknownFailure('Failed to add contact'));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> getContacts() async {
    try {
      final models = await _localDatasource.getContacts();
      return Right(models.map((m) => m.toEntity()).toList());
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      developer.log('Unexpected error getting contacts: $e');
      return Left(UnknownFailure('Failed to get contacts'));
    }
  }

  @override
  Future<Either<Failure, ContactEntity?>> getContact(String id) async {
    try {
      final model = await _localDatasource.getContact(id);
      return Right(model?.toEntity());
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get contact'));
    }
  }

  @override
  Future<Either<Failure, ContactEntity?>> getContactByPublicKey(String publicKey) async {
    try {
      final model = await _localDatasource.getContactByPublicKey(publicKey);
      return Right(model?.toEntity());
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get contact by public key'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteContact(String id) async {
    try {
      await _localDatasource.deleteContact(id);
      await _backupContacts();
      return const Right(null);
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to delete contact'));
    }
  }

  @override
  Future<bool> contactExists(String publicKey) async {
    try {
      return await _localDatasource.contactExists(publicKey);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Either<Failure, void>> backupContacts() async {
    return await _backupContacts();
  }

  Future<Either<Failure, void>> _backupContacts() async {
    try {
      // Get private key
      final privateKeyResult = await _identityRepository.getPrivateKey();
      final privateKey = privateKeyResult.fold(
        (failure) => null,
        (key) => key,
      );
      if (privateKey == null) {
        developer.log('No private key available for backup');
        return const Right(null);
      }

      // Get UID
      final identityResult = await _identityRepository.getCurrentIdentity();
      final uid = identityResult.fold(
        (failure) => null,
        (identity) => identity?.uid,
      );
      if (uid == null) {
        developer.log('No UID available for backup');
        return const Right(null);
      }

      // Get all contacts
      final contactsResult = await getContacts();
      final contacts = contactsResult.fold(
        (failure) => <ContactEntity>[],
        (list) => list,
      );

      if (contacts.isEmpty) {
        return const Right(null);
      }

      await _remoteDatasource.backupContacts(
        uid: uid,
        privateKeyHex: privateKey,
        contacts: contacts,
      );

      return const Right(null);
    } on EncryptionException catch (e) {
      return Left(EncryptionFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(FirebaseFailure(e.message));
    } catch (e) {
      developer.log('Contact backup failed: $e');
      return const Right(null); // Non-critical
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> restoreContacts() async {
    try {
      // Get private key
      final privateKeyResult = await _identityRepository.getPrivateKey();
      final privateKey = privateKeyResult.fold(
        (failure) => null,
        (key) => key,
      );
      if (privateKey == null) {
        return const Right([]);
      }

      // Get UID
      final identityResult = await _identityRepository.getCurrentIdentity();
      final uid = identityResult.fold(
        (failure) => null,
        (identity) => identity?.uid,
      );
      if (uid == null) {
        return const Right([]);
      }

      final contacts = await _remoteDatasource.restoreContacts(
        uid: uid,
        privateKeyHex: privateKey,
      );

      // Store restored contacts locally
      for (final contact in contacts) {
        if (!await _localDatasource.contactExists(contact.publicKey)) {
          await _localDatasource.storeContact(
            name: contact.name,
            publicKey: contact.publicKey,
          );
        }
      }

      return Right(contacts);
    } on DecryptionException catch (e) {
      developer.log('Contacts restore decryption failed: $e');
      return const Right([]);
    } on FirebaseException catch (e) {
      return Left(FirebaseFailure(e.message));
    } catch (e) {
      developer.log('Contacts restore failed: $e');
      return const Right([]);
    }
  }
}
