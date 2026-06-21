import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/contact_entity.dart';
import '../repositories/contact_repository.dart';

/// Use case for adding a new contact.
/// Validates the public key format and checks for duplicates.
class AddContactUseCase {
  final ContactRepository _repository;

  const AddContactUseCase(this._repository);

  /// Execute the use case.
  /// [name] - Display name for the contact.
  /// [publicKey] - Hex-encoded public key of the contact.
  /// Returns the created ContactEntity on success.
  Future<Either<Failure, ContactEntity>> call({
    required String name,
    required String publicKey,
  }) async {
    return await _repository.addContact(
      name: name,
      publicKey: publicKey,
    );
  }

  /// Check if a contact with this public key already exists.
  Future<bool> contactExists(String publicKey) async {
    return await _repository.contactExists(publicKey);
  }
}
