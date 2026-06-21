import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/contact_entity.dart';

/// Repository interface for contact management operations.
abstract class ContactRepository {
  /// Add a new contact with validation.
  Future<Either<Failure, ContactEntity>> addContact({
    required String name,
    required String publicKey,
  });

  /// Get all contacts.
  Future<Either<Failure, List<ContactEntity>>> getContacts();

  /// Get a single contact by ID.
  Future<Either<Failure, ContactEntity?>> getContact(String id);

  /// Get a contact by their public key.
  Future<Either<Failure, ContactEntity?>> getContactByPublicKey(String publicKey);

  /// Delete a contact.
  Future<Either<Failure, void>> deleteContact(String id);

  /// Check if a contact with this public key already exists.
  Future<bool> contactExists(String publicKey);

  /// Backup encrypted contacts to Firestore.
  Future<Either<Failure, void>> backupContacts();

  /// Restore contacts from Firestore backup.
  Future<Either<Failure, List<ContactEntity>>> restoreContacts();
}
