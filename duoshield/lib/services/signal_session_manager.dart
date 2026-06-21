import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../core/errors/exceptions.dart';
import 'storage_service.dart';

/// Manages Signal Protocol sessions for end-to-end encryption.
/// Handles X3DH key exchange and Double Ratchet for secure messaging.
///
/// Architecture:
/// - Each contact has a unique Signal session
/// - Session state is persisted in Hive after every encrypt/decrypt (ratchet step)
/// - Uses libsignal_protocol_dart for all cryptographic operations
class SignalSessionManager {
  final StorageService _storage;

  final Map<String, SessionCipher> _sessionCiphers = {};
  final Map<String, SignalProtocolAddress> _addresses = {};

  // Per-contact session stores (kept in memory, persisted on each ratchet step)
  final Map<String, InMemorySessionStore> _sessionStores = {};
  final Map<String, InMemoryIdentityKeyStore> _identityStores = {};

  IdentityKeyPair? _identityKeyPair;
  int _registrationId = 0;

  SignalSessionManager({required StorageService storage})
      : _storage = storage;

  /// Initialize the Signal session manager with the user's identity key pair.
  /// Must be called before any encrypt/decrypt operations.
  ///
  /// FIX #4: Replaced non-existent Curve25519.generatePrivateKey /
  /// Curve25519.derivePublicKey with the correct libsignal_protocol_dart API.
  /// The first 32 bytes of the Ed25519-derived private key are clamped to
  /// Curve25519 (X25519) scalar format before use.
  Future<void> initialize(Uint8List privateKeyBytes) async {
    try {
      // Clamp the private key bytes to valid Curve25519 (X25519) scalar format.
      final clamped = Uint8List.fromList(privateKeyBytes.sublist(0, 32));
      clamped[0] &= 248;
      clamped[31] = (clamped[31] & 127) | 64;

      // Construct ECPrivateKey and derive the corresponding public key.
      final ecPrivateKey = ECPrivateKey(clamped);
      final ecPublicKey = Curve.generatePublicKey(ecPrivateKey);

      final identityKey = IdentityKey(ecPublicKey);
      _identityKeyPair = IdentityKeyPair(identityKey, ecPrivateKey);
      _registrationId = KeyHelper.generateRegistrationId(false);

      developer.log('Signal session manager initialized');
    } catch (e, stackTrace) {
      developer.log('Failed to initialize Signal session manager: $e');
      throw SignalProtocolException(
        'Failed to initialize Signal protocol',
        code: 'SIGNAL_INIT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Generate a pre-key bundle for the current user.
  Future<Map<String, dynamic>> generatePreKeyBundle() async {
    try {
      if (_identityKeyPair == null) {
        throw SignalProtocolException(
          'Signal session manager not initialized',
          code: 'NOT_INITIALIZED',
        );
      }

      final signedPreKey = await KeyHelper.generateSignedPreKey(
        _identityKeyPair!,
        0,
      );

      final oneTimePreKeys = <PreKeyRecord>[];
      for (var i = 0; i < 100; i++) {
        final preKey = await KeyHelper.generatePreKey(i);
        oneTimePreKeys.add(preKey);
      }

      final bundle = <String, dynamic>{
        'identityKey': base64Encode(
          _identityKeyPair!.getPublicKey().serialize(),
        ),
        'signedPreKey': {
          'keyId': signedPreKey.id,
          'publicKey': base64Encode(signedPreKey.getKeyPair().publicKey.serialize()),
          'signature': base64Encode(signedPreKey.signature),
        },
        'oneTimePreKeys': oneTimePreKeys
            .map((pk) => {
                  'keyId': pk.id,
                  'publicKey': base64Encode(
                    pk.getKeyPair().publicKey.serialize(),
                  ),
                })
            .toList(),
      };

      await _storePreKeys(oneTimePreKeys);
      await _storeSignedPreKey(signedPreKey);

      developer.log('Pre-key bundle generated with ${oneTimePreKeys.length} one-time keys');
      return bundle;
    } on SignalProtocolException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to generate pre-key bundle: $e');
      throw SignalProtocolException(
        'Failed to generate pre-key bundle',
        code: 'PRE_KEY_BUNDLE_GENERATE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Establish a Signal session with a contact using their pre-key bundle.
  Future<void> establishSession({
    required String contactPublicKeyHex,
    required Map<String, dynamic> preKeyBundle,
  }) async {
    try {
      if (_identityKeyPair == null) {
        throw SignalProtocolException(
          'Signal session manager not initialized',
          code: 'NOT_INITIALIZED',
        );
      }

      final identityKeyBytes = base64Decode(preKeyBundle['identityKey'] as String);
      final identityKey = IdentityKey.fromBytes(identityKeyBytes, 0);

      final signedPreKeyData =
          preKeyBundle['signedPreKey'] as Map<String, dynamic>;
      final signedPreKeyId = signedPreKeyData['keyId'] as int;
      final signedPreKeyPublic =
          base64Decode(signedPreKeyData['publicKey'] as String);
      final signedPreKeySignature =
          base64Decode(signedPreKeyData['signature'] as String);
      final signedPreKey = ECPublicKey(signedPreKeyPublic);

      ECPublicKey? oneTimePreKey;
      int? oneTimePreKeyId;
      final oneTimePreKeys = preKeyBundle['oneTimePreKeys'] as List<dynamic>?;
      if (oneTimePreKeys != null && oneTimePreKeys.isNotEmpty) {
        final selectedPreKey = oneTimePreKeys.first as Map<String, dynamic>;
        oneTimePreKeyId = selectedPreKey['keyId'] as int;
        oneTimePreKey = ECPublicKey(
          base64Decode(selectedPreKey['publicKey'] as String),
        );
      }

      final address = SignalProtocolAddress(contactPublicKeyHex, 0);
      _addresses[contactPublicKeyHex] = address;

      final sessionStore = InMemorySessionStore();
      final preKeyStore = InMemoryPreKeyStore();
      final signedPreKeyStore = InMemorySignedPreKeyStore();
      final identityStore = InMemoryIdentityKeyStore(
        _identityKeyPair!,
        _registrationId,
      );

      final retrievedPreKey = PreKeyBundle(
        signedPreKeyId,
        0,
        oneTimePreKeyId ?? 0,
        oneTimePreKey != null
            ? oneTimePreKey.serialize()
            : Uint8List(0),
        signedPreKeyId,
        signedPreKey.serialize(),
        signedPreKeySignature,
        identityKey,
      );

      await SessionBuilder.fromStore(
        sessionStore,
        preKeyStore,
        signedPreKeyStore,
        identityStore,
        address,
      ).processPreKeyBundle(retrievedPreKey);

      final sessionCipher = SessionCipher(
        sessionStore,
        preKeyStore,
        signedPreKeyStore,
        identityStore,
        address,
      );

      _sessionCiphers[contactPublicKeyHex] = sessionCipher;
      _sessionStores[contactPublicKeyHex] = sessionStore;
      _identityStores[contactPublicKeyHex] = identityStore;

      // Persist initial session state
      await _persistSessionState(contactPublicKeyHex, sessionStore, address);

      developer.log(
        'Signal session established with: ${contactPublicKeyHex.substring(0, 16)}...',
      );
    } on SignalProtocolException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to establish Signal session: $e');
      throw SignalProtocolException(
        'Failed to establish secure session',
        code: 'SESSION_ESTABLISH_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Encrypt a message for a contact using the Double Ratchet.
  Future<String> encryptMessage({
    required String contactPublicKeyHex,
    required String plaintext,
  }) async {
    try {
      if (!_sessionCiphers.containsKey(contactPublicKeyHex)) {
        final loaded = await _loadSessionState(contactPublicKeyHex);
        if (!loaded) {
          throw SignalProtocolException(
            'No session found for contact. Pre-key bundle required.',
            code: 'NO_SESSION',
          );
        }
      }

      final cipher = _sessionCiphers[contactPublicKeyHex]!;
      final ciphertext = await cipher.encrypt(
        Uint8List.fromList(utf8.encode(plaintext)),
      );

      // FIX #5: Persist the updated ratchet state after every encrypt step.
      await _persistCipherState(contactPublicKeyHex);

      developer.log(
        'Message encrypted for: ${contactPublicKeyHex.substring(0, 16)}...',
      );
      return base64Encode(ciphertext.serialize());
    } on SignalProtocolException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to encrypt message: $e');
      throw EncryptionException(
        'Failed to encrypt message',
        code: 'SIGNAL_ENCRYPT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Decrypt a message from a contact using the Double Ratchet.
  Future<String> decryptMessage({
    required String contactPublicKeyHex,
    required String ciphertextBase64,
  }) async {
    try {
      if (!_sessionCiphers.containsKey(contactPublicKeyHex)) {
        final loaded = await _loadSessionState(contactPublicKeyHex);
        if (!loaded) {
          throw SignalProtocolException(
            'No session found for contact',
            code: 'NO_SESSION',
          );
        }
      }

      final cipher = _sessionCiphers[contactPublicKeyHex]!;
      final ciphertextBytes = base64Decode(ciphertextBase64);
      final ciphertext = SignalMessage.fromSerialized(ciphertextBytes);

      final plaintext = await cipher.decrypt(ciphertext);

      // FIX #5: Persist the updated ratchet state after every decrypt step.
      await _persistCipherState(contactPublicKeyHex);

      developer.log(
        'Message decrypted from: ${contactPublicKeyHex.substring(0, 16)}...',
      );
      return utf8.decode(plaintext);
    } on SignalProtocolException {
      rethrow;
    } on FormatException catch (e, stackTrace) {
      developer.log('Signal message parse failed, trying pre-key message: $e');
      return _decryptAsPreKeyMessage(
        contactPublicKeyHex,
        base64Decode(ciphertextBase64),
      );
    } catch (e, stackTrace) {
      developer.log('Failed to decrypt message: $e');
      throw DecryptionException(
        'Failed to decrypt message',
        code: 'SIGNAL_DECRYPT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Try to decrypt as a pre-key message (X3DH initial message).
  Future<String> _decryptAsPreKeyMessage(
    String contactPublicKeyHex,
    Uint8List ciphertextBytes,
  ) async {
    try {
      final cipher = _sessionCiphers[contactPublicKeyHex];
      if (cipher == null) {
        throw SignalProtocolException(
          'No cipher available for pre-key message',
          code: 'NO_CIPHER',
        );
      }

      final preKeyMessage = PreKeySignalMessage(ciphertextBytes);
      final plaintext = await cipher.decryptFromSignal(preKeyMessage);

      // Persist ratchet state after decrypting pre-key message too
      await _persistCipherState(contactPublicKeyHex);

      developer.log('Pre-key message decrypted');
      return utf8.decode(plaintext);
    } catch (e, stackTrace) {
      developer.log('Pre-key message decryption failed: $e');
      throw DecryptionException(
        'Failed to decrypt pre-key message',
        code: 'PRE_KEY_DECRYPT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Check if a session exists for a contact.
  Future<bool> hasSession(String contactPublicKeyHex) async {
    if (_sessionCiphers.containsKey(contactPublicKeyHex)) return true;
    final state = await _storage.getSignalSession(contactPublicKeyHex);
    return state != null;
  }

  /// Delete a session for a contact.
  Future<void> deleteSession(String contactPublicKeyHex) async {
    _sessionCiphers.remove(contactPublicKeyHex);
    _addresses.remove(contactPublicKeyHex);
    _sessionStores.remove(contactPublicKeyHex);
    _identityStores.remove(contactPublicKeyHex);
    developer.log('Session removed from memory: $contactPublicKeyHex');
  }

  // ==================== PRIVATE: STATE PERSISTENCE ====================

  Future<void> _storePreKeys(List<PreKeyRecord> preKeys) async {
    try {
      final serialized = preKeys
          .map((pk) => {
                'id': pk.id,
                'publicKey': base64Encode(pk.getKeyPair().publicKey.serialize()),
                'privateKey': base64Encode(pk.getKeyPair().privateKey.serialize()),
              })
          .toList();
      await _storage.setSetting('preKeys', serialized);
    } catch (e) {
      developer.log('Failed to store pre-keys: $e');
    }
  }

  Future<void> _storeSignedPreKey(SignedPreKeyRecord signedPreKey) async {
    try {
      await _storage.setSetting('signedPreKey', {
        'id': signedPreKey.id,
        'publicKey':
            base64Encode(signedPreKey.getKeyPair().publicKey.serialize()),
        'privateKey':
            base64Encode(signedPreKey.getKeyPair().privateKey.serialize()),
        'signature': base64Encode(signedPreKey.signature),
      });
    } catch (e) {
      developer.log('Failed to store signed pre-key: $e');
    }
  }

  /// Persist the full session record for a contact after X3DH establishment.
  Future<void> _persistSessionState(
    String contactPublicKeyHex,
    InMemorySessionStore sessionStore,
    SignalProtocolAddress address,
  ) async {
    try {
      final sessionRecord = await sessionStore.loadSession(address);
      final state = <String, dynamic>{
        'session': base64Encode(sessionRecord.serialize()),
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _storage.storeSignalSession(contactPublicKeyHex, state);
    } catch (e) {
      developer.log('Failed to persist session state: $e');
    }
  }

  /// FIX #5: Persist the ratchet state after every encrypt/decrypt step.
  /// Previously this was an empty placeholder — the ratchet state was lost on
  /// app restart, causing decryption failures for all subsequent messages.
  Future<void> _persistCipherState(String contactPublicKeyHex) async {
    try {
      final address = _addresses[contactPublicKeyHex];
      final sessionStore = _sessionStores[contactPublicKeyHex];
      if (address == null || sessionStore == null) return;

      final sessionRecord = await sessionStore.loadSession(address);
      final state = <String, dynamic>{
        'session': base64Encode(sessionRecord.serialize()),
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _storage.storeSignalSession(contactPublicKeyHex, state);
    } catch (e) {
      developer.log('Failed to persist cipher state after ratchet step: $e');
      // Non-fatal: next app restart may fail to decrypt but does not crash now
    }
  }

  Future<bool> _loadSessionState(String contactPublicKeyHex) async {
    try {
      final state = await _storage.getSignalSession(contactPublicKeyHex);
      if (state == null) return false;

      final sessionStore = InMemorySessionStore();
      final preKeyStore = InMemoryPreKeyStore();
      final signedPreKeyStore = InMemorySignedPreKeyStore();
      final identityStore = InMemoryIdentityKeyStore(
        _identityKeyPair!,
        _registrationId,
      );

      final sessionBytes = base64Decode(state['session'] as String);
      final sessionRecord = SessionRecord.fromSerialized(sessionBytes);
      final address = SignalProtocolAddress(contactPublicKeyHex, 0);

      await sessionStore.storeSession(address, sessionRecord);

      final cipher = SessionCipher(
        sessionStore,
        preKeyStore,
        signedPreKeyStore,
        identityStore,
        address,
      );

      _sessionCiphers[contactPublicKeyHex] = cipher;
      _addresses[contactPublicKeyHex] = address;
      _sessionStores[contactPublicKeyHex] = sessionStore;
      _identityStores[contactPublicKeyHex] = identityStore;

      developer.log(
        'Session state loaded for: ${contactPublicKeyHex.substring(0, 16)}...',
      );
      return true;
    } catch (e) {
      developer.log('Failed to load session state: $e');
      return false;
    }
  }
}
