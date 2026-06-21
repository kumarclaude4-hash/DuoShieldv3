import 'dart:developer' as developer;

import '../../../../core/errors/exceptions.dart';
import '../../../../services/encryption_service.dart';
import '../../../../services/firebase_service.dart';
import '../../domain/entities/contact_entity.dart';

/// Remote data source for contacts Firebase operations.
/// Handles encrypted backup and restore of contacts to/from Firestore.
class ContactRemoteDatasource {
  final FirebaseService _firebaseService;

  ContactRemoteDatasource({required FirebaseService firebaseService})
      : _firebaseService = firebaseService;

  /// Backup encrypted contacts to Firestore.
  Future<void> backupContacts({
    required String uid,
    required String privateKeyHex,
    required List<ContactEntity> contacts,
  }) async {
    try {
      // Serialize contacts to JSON
      final contactsJson = contacts
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'publicKey': c.publicKey,
                'addedAt': c.addedAt.toIso8601String(),
              })
          .toList();

      // Encrypt contacts using private key-derived key
      final encrypted = EncryptionService.encryptContactsBackup(
        contacts: contactsJson,
        privateKeyHex: privateKeyHex,
      );

      // Store in Firestore
      await _firebaseService.storeContactsBackup(
        uid: uid,
        encryptedContacts: encrypted,
      );

      developer.log('Contacts backed up to Firestore: ${contacts.length} contacts');
    } on EncryptionException {
      rethrow;
    } on FirebaseException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to backup contacts: $e');
      throw FirebaseException(
        'Failed to backup contacts',
        code: 'CONTACTS_BACKUP_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Restore contacts from Firestore backup.
  Future<List<ContactEntity>> restoreContacts({
    required String uid,
    required String privateKeyHex,
  }) async {
    try {
      // Get encrypted backup from Firestore
      final encrypted = await _firebaseService.getContactsBackup(uid);
      if (encrypted == null || encrypted.isEmpty) {
        developer.log('No contacts backup found in Firestore');
        return [];
      }

      // Decrypt contacts
      final contactsJson = EncryptionService.decryptContactsBackup(
        encryptedBackupBase64: encrypted,
        privateKeyHex: privateKeyHex,
      );

      // Convert to entities
      final contacts = contactsJson
          .map((json) => ContactEntity(
                id: json['id'] as String,
                name: json['name'] as String,
                publicKey: json['publicKey'] as String,
                addedAt: DateTime.parse(json['addedAt'] as String),
              ))
          .toList();

      developer.log('Contacts restored from Firestore: ${contacts.length} contacts');
      return contacts;
    } on DecryptionException catch (e) {
      developer.log('Failed to decrypt contacts backup: $e');
      return []; // Return empty list if decryption fails
    } on FirebaseException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to restore contacts: $e');
      throw FirebaseException(
        'Failed to restore contacts',
        code: 'CONTACTS_RESTORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get a user's public key from Firestore by their UID.
  Future<String?> getUserPublicKey(String uid) async {
    try {
      return await _firebaseService.getUserPublicKey(uid);
    } catch (e, stackTrace) {
      developer.log('Failed to get user public key: $e');
      throw FirebaseException(
        'Failed to get user public key',
        code: 'GET_USER_KEY_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get a user's pre-key bundle from Firestore.
  Future<Map<String, dynamic>?> getUserPreKeyBundle(String uid) async {
    try {
      return await _firebaseService.getUserPreKeyBundle(uid);
    } catch (e, stackTrace) {
      developer.log('Failed to get user pre-key bundle: $e');
      throw FirebaseException(
        'Failed to get pre-key bundle',
        code: 'GET_PRE_KEY_BUNDLE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }
}
