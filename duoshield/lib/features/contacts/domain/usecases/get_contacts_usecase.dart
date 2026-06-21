import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/contact_entity.dart';
import '../repositories/contact_repository.dart';

/// Use case for retrieving all contacts.
class GetContactsUseCase {
  final ContactRepository _repository;

  const GetContactsUseCase(this._repository);

  /// Execute the use case.
  /// Returns list of all contacts sorted by added date (newest first).
  Future<Either<Failure, List<ContactEntity>>> call() async {
    return await _repository.getContacts();
  }

  /// Get a single contact by ID.
  Future<Either<Failure, ContactEntity?>> getById(String id) async {
    return await _repository.getContact(id);
  }

  /// Find a contact by their public key.
  Future<Either<Failure, ContactEntity?>> getByPublicKey(String publicKey) async {
    return await _repository.getContactByPublicKey(publicKey);
  }

  /// Delete a contact.
  Future<Either<Failure, void>> delete(String id) async {
    return await _repository.deleteContact(id);
  }
}
