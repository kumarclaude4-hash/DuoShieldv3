import 'dart:developer' as developer;

import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/key_utils.dart';
import '../../../../services/storage_service.dart';
import '../models/contact_model.dart';

/// Local data source for contact storage in Hive.
class ContactLocalDatasource {
  final StorageService _storage;
  final Uuid _uuid;

  ContactLocalDatasource({
    required StorageService storage,
    Uuid? uuid,
  })  : _storage = storage,
        _uuid = uuid ?? const Uuid();

  /// Store a contact in Hive.
  Future<ContactModel> storeContact({
    required String name,
    required String publicKey,
  }) async {
    try {
      final normalizedKey = KeyUtils.normalizePublicKey(publicKey);
      final contact = ContactModel(
        id: _uuid.v4(),
        name: name.trim(),
        publicKey: normalizedKey,
        addedAt: DateTime.now(),
      );

      await _storage.storeContact(contact.toJson());
      developer.log('Contact stored locally: ${contact.id}');
      return contact;
    } catch (e, stackTrace) {
      developer.log('Failed to store contact locally: $e');
      throw LocalStorageException(
        'Failed to store contact',
        code: 'STORE_CONTACT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get all contacts from Hive.
  Future<List<ContactModel>> getContacts() async {
    try {
      final contactsData = await _storage.getAllContacts();
      final contacts = contactsData
          .map((data) => ContactModel.fromJson(data))
          .toList();

      // Sort by added date, newest first
      contacts.sort((a, b) => b.addedAt.compareTo(a.addedAt));

      developer.log('Retrieved ${contacts.length} contacts from local storage');
      return contacts;
    } catch (e, stackTrace) {
      developer.log('Failed to get contacts from local storage: $e');
      throw LocalStorageException(
        'Failed to retrieve contacts',
        code: 'GET_CONTACTS_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get a contact by ID.
  Future<ContactModel?> getContact(String id) async {
    try {
      final contacts = await getContacts();
      return contacts.where((c) => c.id == id).firstOrNull;
    } catch (e, stackTrace) {
      developer.log('Failed to get contact by ID: $e');
      throw LocalStorageException(
        'Failed to retrieve contact',
        code: 'GET_CONTACT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get a contact by public key.
  Future<ContactModel?> getContactByPublicKey(String publicKey) async {
    try {
      final normalizedKey = KeyUtils.normalizePublicKey(publicKey);
      final contacts = await getContacts();
      return contacts
          .where((c) =>
              KeyUtils.normalizePublicKey(c.publicKey) == normalizedKey)
          .firstOrNull;
    } catch (e, stackTrace) {
      developer.log('Failed to get contact by public key: $e');
      throw LocalStorageException(
        'Failed to retrieve contact by public key',
        code: 'GET_CONTACT_BY_KEY_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete a contact.
  Future<void> deleteContact(String id) async {
    try {
      await _storage.deleteContact(id);
      developer.log('Contact deleted from local storage: $id');
    } catch (e, stackTrace) {
      developer.log('Failed to delete contact: $e');
      throw LocalStorageException(
        'Failed to delete contact',
        code: 'DELETE_CONTACT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Check if a contact with this public key exists.
  Future<bool> contactExists(String publicKey) async {
    try {
      final contact = await getContactByPublicKey(publicKey);
      return contact != null;
    } catch (e) {
      return false;
    }
  }

  /// Replace all contacts (used for restore).
  Future<void> replaceAllContacts(List<ContactModel> contacts) async {
    try {
      // Get existing contacts to delete them
      final existing = await getContacts();
      for (final contact in existing) {
        await _storage.deleteContact(contact.id);
      }

      // Store new contacts
      for (final contact in contacts) {
        await _storage.storeContact(contact.toJson());
      }

      developer.log('Replaced ${contacts.length} contacts');
    } catch (e, stackTrace) {
      developer.log('Failed to replace contacts: $e');
      throw LocalStorageException(
        'Failed to replace contacts',
        code: 'REPLACE_CONTACTS_FAILED',
        stackTrace: stackTrace,
      );
    }
  }
}
