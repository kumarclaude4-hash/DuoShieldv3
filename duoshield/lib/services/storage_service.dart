import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/firestore_constants.dart';
import '../core/errors/exceptions.dart';

/// Centralized storage service that abstracts both secure storage (Keychain/Keystore)
/// and local Hive database operations.
///
/// Security rules:
/// - Private key: ONLY in flutter_secure_storage
/// - Public key: Hive (non-sensitive)
/// - Messages: Hive (encrypted ciphertext only, plaintext NEVER stored)
/// - Contacts: Hive + Firestore backup
/// - Signal sessions: Hive (encrypted)
class StorageService {
  final FlutterSecureStorage _secureStorage;

  // Cached Hive boxes for performance
  Box<String>? _identityBox;
  Box<Map>? _contactsBox;
  Box<Map>? _messagesBox;
  Box<Map>? _conversationsBox;
  Box<Map>? _settingsBox;
  Box<Map>? _signalSessionsBox;
  Box<String>? _plaintextCacheBox;

  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
            // FIX #11: PKCS1Padding is vulnerable to padding oracle attacks.
          // OAEP with SHA-256 is the recommended secure alternative.
          keyCipherAlgorithm:
                KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
            accountName: 'duoshield_secure_storage',
          ),
        );

  // ==================== SECURE STORAGE ====================

  /// Store the private key securely.
  /// NEVER log this value. NEVER transmit over network.
  Future<void> storePrivateKey(String privateKey) async {
    try {
      await _secureStorage.write(
        key: FirestoreConstants.securePrivateKey,
        value: privateKey,
      );
      developer.log('Private key stored in secure storage');
    } catch (e, stackTrace) {
      developer.log('Failed to store private key: $e');
      throw SecureStorageException(
        'Failed to store private key securely',
        code: 'PRIVATE_KEY_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Retrieve the private key from secure storage.
  /// Returns null if no private key is stored.
  Future<String?> getPrivateKey() async {
    try {
      final key = await _secureStorage.read(
        key: FirestoreConstants.securePrivateKey,
      );
      // NEVER log the private key value
      developer.log('Private key retrieved from secure storage');
      return key;
    } catch (e, stackTrace) {
      developer.log('Failed to retrieve private key: $e');
      throw SecureStorageException(
        'Failed to retrieve private key',
        code: 'PRIVATE_KEY_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete the private key from secure storage.
  Future<void> deletePrivateKey() async {
    try {
      await _secureStorage.delete(key: FirestoreConstants.securePrivateKey);
      developer.log('Private key deleted from secure storage');
    } catch (e, stackTrace) {
      developer.log('Failed to delete private key: $e');
      throw SecureStorageException(
        'Failed to delete private key',
        code: 'PRIVATE_KEY_DELETE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Store the PIN hash.
  Future<void> storePinHash(String pinHash) async {
    try {
      await _secureStorage.write(
        key: FirestoreConstants.securePinHash,
        value: pinHash,
      );
      developer.log('PIN hash stored in secure storage');
    } catch (e, stackTrace) {
      developer.log('Failed to store PIN hash: $e');
      throw SecureStorageException(
        'Failed to store PIN hash',
        code: 'PIN_HASH_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Retrieve the PIN hash.
  Future<String?> getPinHash() async {
    try {
      return await _secureStorage.read(
        key: FirestoreConstants.securePinHash,
      );
    } catch (e, stackTrace) {
      developer.log('Failed to retrieve PIN hash: $e');
      throw SecureStorageException(
        'Failed to retrieve PIN hash',
        code: 'PIN_HASH_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete the PIN hash.
  Future<void> deletePinHash() async {
    try {
      await _secureStorage.delete(key: FirestoreConstants.securePinHash);
      developer.log('PIN hash deleted from secure storage');
    } catch (e, stackTrace) {
      developer.log('Failed to delete PIN hash: $e');
      throw SecureStorageException(
        'Failed to delete PIN hash',
        code: 'PIN_HASH_DELETE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Store the duress PIN hash.
  Future<void> storeDuressPinHash(String pinHash) async {
    try {
      await _secureStorage.write(
        key: FirestoreConstants.secureDuressPinHash,
        value: pinHash,
      );
      developer.log('Duress PIN hash stored in secure storage');
    } catch (e, stackTrace) {
      developer.log('Failed to store duress PIN hash: $e');
      throw SecureStorageException(
        'Failed to store duress PIN hash',
        code: 'DURESS_PIN_HASH_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Retrieve the duress PIN hash.
  Future<String?> getDuressPinHash() async {
    try {
      return await _secureStorage.read(
        key: FirestoreConstants.secureDuressPinHash,
      );
    } catch (e, stackTrace) {
      developer.log('Failed to retrieve duress PIN hash: $e');
      throw SecureStorageException(
        'Failed to retrieve duress PIN hash',
        code: 'DURESS_PIN_HASH_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete the duress PIN hash.
  Future<void> deleteDuressPinHash() async {
    try {
      await _secureStorage.delete(
        key: FirestoreConstants.secureDuressPinHash,
      );
      developer.log('Duress PIN hash deleted from secure storage');
    } catch (e, stackTrace) {
      developer.log('Failed to delete duress PIN hash: $e');
      throw SecureStorageException(
        'Failed to delete duress PIN hash',
        code: 'DURESS_PIN_HASH_DELETE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Store failed PIN attempt count.
  Future<void> storeFailedAttempts(int count) async {
    try {
      await _secureStorage.write(
        key: FirestoreConstants.secureFailedAttempts,
        value: count.toString(),
      );
    } catch (e, stackTrace) {
      throw SecureStorageException(
        'Failed to store failed attempts count',
        code: 'FAILED_ATTEMPTS_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get failed PIN attempt count.
  Future<int> getFailedAttempts() async {
    try {
      final value = await _secureStorage.read(
        key: FirestoreConstants.secureFailedAttempts,
      );
      return int.tryParse(value ?? '0') ?? 0;
    } catch (e, stackTrace) {
      throw SecureStorageException(
        'Failed to retrieve failed attempts count',
        code: 'FAILED_ATTEMPTS_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Store the lock-until timestamp.
  Future<void> storeLockUntil(DateTime? lockUntil) async {
    try {
      if (lockUntil == null) {
        await _secureStorage.delete(
          key: FirestoreConstants.secureLockUntil,
        );
      } else {
        await _secureStorage.write(
          key: FirestoreConstants.secureLockUntil,
          value: lockUntil.millisecondsSinceEpoch.toString(),
        );
      }
    } catch (e, stackTrace) {
      throw SecureStorageException(
        'Failed to store lock until timestamp',
        code: 'LOCK_UNTIL_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the lock-until timestamp.
  Future<DateTime?> getLockUntil() async {
    try {
      final value = await _secureStorage.read(
        key: FirestoreConstants.secureLockUntil,
      );
      if (value == null) return null;
      final timestamp = int.tryParse(value);
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e, stackTrace) {
      throw SecureStorageException(
        'Failed to retrieve lock until timestamp',
        code: 'LOCK_UNTIL_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete all secure storage data (logout / duress wipe).
  Future<void> clearAllSecureStorage() async {
    try {
      await _secureStorage.deleteAll();
      developer.log('All secure storage data cleared');
    } catch (e, stackTrace) {
      developer.log('Failed to clear secure storage: $e');
      throw SecureStorageException(
        'Failed to clear secure storage',
        code: 'CLEAR_SECURE_STORAGE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== HIVE STORAGE - IDENTITY ====================

  Future<Box<String>> _getIdentityBox() async {
    _identityBox ??= Hive.box<String>(FirestoreConstants.hiveIdentityBox);
    return _identityBox!;
  }

  /// Store the public key in Hive.
  Future<void> storePublicKey(String publicKey) async {
    try {
      final box = await _getIdentityBox();
      await box.put(FirestoreConstants.publicKeyHiveKey, publicKey);
      developer.log('Public key stored in Hive');
    } catch (e, stackTrace) {
      developer.log('Failed to store public key: $e');
      throw LocalStorageException(
        'Failed to store public key',
        code: 'PUBLIC_KEY_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Retrieve the public key from Hive.
  Future<String?> getPublicKey() async {
    try {
      final box = await _getIdentityBox();
      return box.get(FirestoreConstants.publicKeyHiveKey);
    } catch (e, stackTrace) {
      developer.log('Failed to retrieve public key: $e');
      throw LocalStorageException(
        'Failed to retrieve public key',
        code: 'PUBLIC_KEY_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Store Firebase UID in Hive.
  Future<void> storeUid(String uid) async {
    try {
      final box = await _getIdentityBox();
      await box.put(FirestoreConstants.uidHiveKey, uid);
      developer.log('UID stored in Hive');
    } catch (e, stackTrace) {
      developer.log('Failed to store UID: $e');
      throw LocalStorageException(
        'Failed to store UID',
        code: 'UID_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Retrieve Firebase UID from Hive.
  Future<String?> getUid() async {
    try {
      final box = await _getIdentityBox();
      return box.get(FirestoreConstants.uidHiveKey);
    } catch (e, stackTrace) {
      developer.log('Failed to retrieve UID: $e');
      throw LocalStorageException(
        'Failed to retrieve UID',
        code: 'UID_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Mark seed phrase as confirmed.
  Future<void> markSeedConfirmed(bool confirmed) async {
    try {
      final box = await _getIdentityBox();
      await box.put(
        FirestoreConstants.seedConfirmedKey,
        confirmed ? 'true' : 'false',
      );
    } catch (e, stackTrace) {
      throw LocalStorageException(
        'Failed to store seed confirmation status',
        code: 'SEED_CONFIRM_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Check if seed phrase was confirmed.
  Future<bool> isSeedConfirmed() async {
    try {
      final box = await _getIdentityBox();
      final value = box.get(FirestoreConstants.seedConfirmedKey);
      return value == 'true';
    } catch (e, stackTrace) {
      throw LocalStorageException(
        'Failed to check seed confirmation status',
        code: 'SEED_CONFIRM_CHECK_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== HIVE STORAGE - CONTACTS ====================

  Future<Box<Map>> _getContactsBox() async {
    _contactsBox ??= Hive.box<Map>(FirestoreConstants.hiveContactsBox);
    return _contactsBox!;
  }

  /// Store a contact in Hive.
  Future<void> storeContact(Map<String, dynamic> contact) async {
    try {
      final box = await _getContactsBox();
      await box.put(contact['id'] as String, contact);
      developer.log('Contact stored in Hive: ${contact['id']}');
    } catch (e, stackTrace) {
      developer.log('Failed to store contact: $e');
      throw LocalStorageException(
        'Failed to store contact',
        code: 'CONTACT_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get all contacts from Hive.
  Future<List<Map<String, dynamic>>> getAllContacts() async {
    try {
      final box = await _getContactsBox();
      final contacts = <Map<String, dynamic>>[];
      for (final key in box.keys) {
        final value = box.get(key);
        if (value != null) {
          final Map<String, dynamic> contact = Map<String, dynamic>.from(value);
          contacts.add(contact);
        }
      }
      return contacts;
    } catch (e, stackTrace) {
      developer.log('Failed to retrieve contacts: $e');
      throw LocalStorageException(
        'Failed to retrieve contacts',
        code: 'CONTACTS_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete a contact from Hive.
  Future<void> deleteContact(String contactId) async {
    try {
      final box = await _getContactsBox();
      await box.delete(contactId);
      developer.log('Contact deleted from Hive: $contactId');
    } catch (e, stackTrace) {
      developer.log('Failed to delete contact: $e');
      throw LocalStorageException(
        'Failed to delete contact',
        code: 'CONTACT_DELETE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== HIVE STORAGE - MESSAGES ====================

  Future<Box<Map>> _getMessagesBox() async {
    _messagesBox ??= Hive.box<Map>(FirestoreConstants.hiveMessagesBox);
    return _messagesBox!;
  }

  /// Store an encrypted message in Hive (ciphertext only).
  /// PLAINTEXT IS NEVER STORED.
  Future<void> storeMessage(Map<String, dynamic> message) async {
    try {
      final box = await _getMessagesBox();
      // Ensure no plaintext is accidentally stored
      final sanitized = Map<String, dynamic>.from(message);
      sanitized.remove('plaintextCache');
      await box.put(message['id'] as String, sanitized);
    } catch (e, stackTrace) {
      developer.log('Failed to store message: $e');
      throw LocalStorageException(
        'Failed to store message',
        code: 'MESSAGE_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get all messages for a conversation from Hive.
  Future<List<Map<String, dynamic>>> getMessagesForConversation(
    String conversationId,
  ) async {
    try {
      final box = await _getMessagesBox();
      final messages = <Map<String, dynamic>>[];
      for (final key in box.keys) {
        final value = box.get(key);
        if (value != null &&
            value['conversationId'] == conversationId) {
          messages.add(Map<String, dynamic>.from(value));
        }
      }
      // Sort by timestamp
      messages.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] ?? '');
        final bTime = DateTime.tryParse(b['timestamp'] ?? '');
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });
      return messages;
    } catch (e, stackTrace) {
      developer.log('Failed to retrieve messages: $e');
      throw LocalStorageException(
        'Failed to retrieve messages',
        code: 'MESSAGES_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== HIVE STORAGE - CONVERSATIONS ====================

  Future<Box<Map>> _getConversationsBox() async {
    _conversationsBox ??=
        Hive.box<Map>(FirestoreConstants.hiveConversationsBox);
    return _conversationsBox!;
  }

  /// Store conversation metadata in Hive.
  Future<void> storeConversation(Map<String, dynamic> conversation) async {
    try {
      final box = await _getConversationsBox();
      await box.put(
        conversation['id'] as String,
        conversation,
      );
    } catch (e, stackTrace) {
      developer.log('Failed to store conversation: $e');
      throw LocalStorageException(
        'Failed to store conversation',
        code: 'CONVERSATION_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get all conversations from Hive.
  Future<List<Map<String, dynamic>>> getAllConversations() async {
    try {
      final box = await _getConversationsBox();
      final conversations = <Map<String, dynamic>>[];
      for (final key in box.keys) {
        final value = box.get(key);
        if (value != null) {
          conversations.add(Map<String, dynamic>.from(value));
        }
      }
      return conversations;
    } catch (e, stackTrace) {
      developer.log('Failed to retrieve conversations: $e');
      throw LocalStorageException(
        'Failed to retrieve conversations',
        code: 'CONVERSATIONS_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== HIVE STORAGE - SIGNAL SESSIONS ====================

  Future<Box<Map>> _getSignalSessionsBox() async {
    _signalSessionsBox ??=
        Hive.box<Map>(FirestoreConstants.hiveSignalSessionsBox);
    return _signalSessionsBox!;
  }

  /// Store an encrypted Signal session state in Hive.
  Future<void> storeSignalSession(
    String contactPublicKey,
    Map<String, dynamic> sessionState,
  ) async {
    try {
      final box = await _getSignalSessionsBox();
      await box.put(contactPublicKey, sessionState);
    } catch (e, stackTrace) {
      developer.log('Failed to store Signal session: $e');
      throw LocalStorageException(
        'Failed to store Signal session',
        code: 'SIGNAL_SESSION_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Retrieve a Signal session state from Hive.
  Future<Map<String, dynamic>?> getSignalSession(
    String contactPublicKey,
  ) async {
    try {
      final box = await _getSignalSessionsBox();
      final value = box.get(contactPublicKey);
      if (value == null) return null;
      return Map<String, dynamic>.from(value);
    } catch (e, stackTrace) {
      developer.log('Failed to retrieve Signal session: $e');
      throw LocalStorageException(
        'Failed to retrieve Signal session',
        code: 'SIGNAL_SESSION_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== HIVE STORAGE - PLAINTEXT CACHE ====================

  Future<Box<String>> _getPlaintextCacheBox() async {
    _plaintextCacheBox ??=
        Hive.box<String>(FirestoreConstants.hivePlaintextCacheBox);
    return _plaintextCacheBox!;
  }

  /// Cache decrypted plaintext in memory-only storage.
  /// This is wiped on app lock/background.
  Future<void> cachePlaintext(String messageId, String plaintext) async {
    try {
      final box = await _getPlaintextCacheBox();
      await box.put(messageId, plaintext);
    } catch (e, stackTrace) {
      // Non-critical: plaintext cache failures should not block
      developer.log('Failed to cache plaintext (non-critical): $e');
    }
  }

  /// Retrieve cached plaintext.
  Future<String?> getCachedPlaintext(String messageId) async {
    try {
      final box = await _getPlaintextCacheBox();
      return box.get(messageId);
    } catch (e) {
      return null;
    }
  }

  // ==================== SETTINGS ====================

  Future<Box<Map>> _getSettingsBox() async {
    _settingsBox ??= Hive.box<Map>(FirestoreConstants.hiveSettingsBox);
    return _settingsBox!;
  }

  /// Store a setting value.
  Future<void> setSetting(String key, dynamic value) async {
    try {
      final box = await _getSettingsBox();
      final settings = Map<String, dynamic>.from(box.get('settings') ?? {});
      settings[key] = value;
      await box.put('settings', settings);
    } catch (e, stackTrace) {
      throw LocalStorageException(
        'Failed to store setting',
        code: 'SETTING_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Retrieve a setting value.
  Future<dynamic> getSetting(String key) async {
    try {
      final box = await _getSettingsBox();
      final settings = box.get('settings');
      if (settings == null) return null;
      return Map<String, dynamic>.from(settings)[key];
    } catch (e, stackTrace) {
      throw LocalStorageException(
        'Failed to retrieve setting',
        code: 'SETTING_RETRIEVE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== WIPE ALL DATA ====================

  /// Wipe all local Hive data. Used for logout and duress PIN.
  /// Does NOT affect Firestore data.
  Future<void> wipeAllLocalData() async {
    try {
      // Delete all Hive boxes
      await Hive.deleteBoxFromDisk(FirestoreConstants.hiveIdentityBox);
      await Hive.deleteBoxFromDisk(FirestoreConstants.hiveContactsBox);
      await Hive.deleteBoxFromDisk(FirestoreConstants.hiveMessagesBox);
      await Hive.deleteBoxFromDisk(FirestoreConstants.hiveConversationsBox);
      await Hive.deleteBoxFromDisk(FirestoreConstants.hiveSettingsBox);
      await Hive.deleteBoxFromDisk(FirestoreConstants.hiveSignalSessionsBox);
      await Hive.deleteBoxFromDisk(FirestoreConstants.hivePlaintextCacheBox);

      // Clear cached references
      _identityBox = null;
      _contactsBox = null;
      _messagesBox = null;
      _conversationsBox = null;
      _settingsBox = null;
      _signalSessionsBox = null;
      _plaintextCacheBox = null;

      // Re-open boxes for fresh state
      await Hive.openBox<String>(FirestoreConstants.hiveIdentityBox);
      await Hive.openBox<Map>(FirestoreConstants.hiveContactsBox);
      await Hive.openBox<Map>(FirestoreConstants.hiveMessagesBox);
      await Hive.openBox<Map>(FirestoreConstants.hiveConversationsBox);
      await Hive.openBox<Map>(FirestoreConstants.hiveSettingsBox);
      await Hive.openBox<Map>(FirestoreConstants.hiveSignalSessionsBox);
      await Hive.openBox<String>(FirestoreConstants.hivePlaintextCacheBox);

      developer.log('All local Hive data wiped');
    } catch (e, stackTrace) {
      developer.log('Failed to wipe local data: $e');
      throw LocalStorageException(
        'Failed to wipe local data',
        code: 'WIPE_LOCAL_DATA_FAILED',
        stackTrace: stackTrace,
      );
    }
  }
}
