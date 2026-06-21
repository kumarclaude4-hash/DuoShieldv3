import 'dart:developer' as developer;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/key_utils.dart';
import '../../../../services/storage_service.dart';
import '../models/identity_model.dart';

/// Local data source for identity storage operations.
/// Handles secure storage of keys and Hive persistence.
class IdentityLocalDatasource {
  final StorageService _storage;

  IdentityLocalDatasource({required StorageService storage})
      : _storage = storage;

  /// Generate a new seed phrase and keypair.
  /// Stores keys locally and returns the seed phrase.
  Future<String> generateAndStoreKeys() async {
    try {
      // Generate 24-word BIP39 seed phrase
      final seedPhrase = KeyUtils.generateSeedPhrase();

      // Derive Ed25519 keypair
      final keypair = await KeyUtils.deriveKeypair(seedPhrase);

      // Store private key in secure storage (NEVER logged)
      await _storage.storePrivateKey(keypair['privateKey']!);

      // Store public key in Hive
      await _storage.storePublicKey(keypair['publicKey']!);

      developer.log('Identity generated and stored locally');
      return seedPhrase;
    } on IdentityException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to generate and store keys: $e');
      throw IdentityException(
        'Failed to generate identity',
        code: 'GENERATE_AND_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Restore identity from seed phrase.
  /// Regenerates keypair and validates against stored public key.
  Future<IdentityModel> restoreFromSeedPhrase(String mnemonic) async {
    try {
      // Validate mnemonic
      if (!KeyUtils.validateSeedPhrase(mnemonic)) {
        throw SeedPhraseException(
          'Invalid seed phrase',
          code: 'INVALID_MNEMONIC',
        );
      }

      // Derive keypair from mnemonic
      final keypair = await KeyUtils.deriveKeypair(mnemonic);

      // Get stored public key for comparison
      final storedPublicKey = await _storage.getPublicKey();

      if (storedPublicKey != null && storedPublicKey.isNotEmpty) {
        // Verify derived public key matches stored key
        final normalizedDerived = KeyUtils.normalizePublicKey(keypair['publicKey']!);
        final normalizedStored = KeyUtils.normalizePublicKey(storedPublicKey);

        if (normalizedDerived != normalizedStored) {
          throw IdentityException(
            'Derived public key does not match stored key. This seed phrase belongs to a different identity.',
            code: 'PUBLIC_KEY_MISMATCH',
          );
        }
      }

      // Store (or re-store) the keys
      await _storage.storePrivateKey(keypair['privateKey']!);
      await _storage.storePublicKey(keypair['publicKey']!);

      // Get UID if available
      final uid = await _storage.getUid();
      final seedConfirmed = await _storage.isSeedConfirmed();

      developer.log('Identity restored from seed phrase');

      return IdentityModel(
        publicKey: keypair['publicKey']!,
        uid: uid,
        seedConfirmed: seedConfirmed,
        createdAt: DateTime.now(),
      );
    } on SeedPhraseException {
      rethrow;
    } on IdentityException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to restore identity: $e');
      throw IdentityException(
        'Failed to restore identity from seed phrase',
        code: 'RESTORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the stored identity from local storage.
  Future<IdentityModel?> getStoredIdentity() async {
    try {
      final publicKey = await _storage.getPublicKey();
      if (publicKey == null || publicKey.isEmpty) {
        return null;
      }

      final uid = await _storage.getUid();
      final seedConfirmed = await _storage.isSeedConfirmed();

      return IdentityModel(
        publicKey: publicKey,
        uid: uid,
        seedConfirmed: seedConfirmed,
      );
    } catch (e, stackTrace) {
      developer.log('Failed to get stored identity: $e');
      throw LocalStorageException(
        'Failed to retrieve stored identity',
        code: 'GET_IDENTITY_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Check if an identity exists in local storage.
  Future<bool> hasIdentity() async {
    try {
      final publicKey = await _storage.getPublicKey();
      return publicKey != null && publicKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the stored public key.
  Future<String?> getPublicKey() async {
    try {
      return await _storage.getPublicKey();
    } catch (e, stackTrace) {
      throw LocalStorageException(
        'Failed to get public key',
        code: 'GET_PUBLIC_KEY_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the stored private key from secure storage.
  /// Returns null if not found.
  Future<String?> getPrivateKey() async {
    try {
      return await _storage.getPrivateKey();
    } catch (e, stackTrace) {
      throw SecureStorageException(
        'Failed to get private key',
        code: 'GET_PRIVATE_KEY_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Mark the seed phrase as confirmed.
  Future<void> confirmSeedPhrase() async {
    try {
      await _storage.markSeedConfirmed(true);
      developer.log('Seed phrase confirmed');
    } catch (e, stackTrace) {
      throw LocalStorageException(
        'Failed to confirm seed phrase',
        code: 'CONFIRM_SEED_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Store the Firebase UID locally.
  Future<void> storeUid(String uid) async {
    try {
      await _storage.storeUid(uid);
      developer.log('UID stored locally: $uid');
    } catch (e, stackTrace) {
      throw LocalStorageException(
        'Failed to store UID',
        code: 'STORE_UID_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete all local identity data.
  Future<void> deleteIdentity() async {
    try {
      await _storage.clearAllSecureStorage();
      developer.log('Identity data deleted from local storage');
    } catch (e, stackTrace) {
      throw LocalStorageException(
        'Failed to delete identity',
        code: 'DELETE_IDENTITY_FAILED',
        stackTrace: stackTrace,
      );
    }
  }
}
