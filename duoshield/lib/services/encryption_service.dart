import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart' as pc;

import '../core/errors/exceptions.dart';

/// Encryption service for AES-256-GCM encryption of data.
/// Used for encrypting contact backups before storing in Firestore.
/// Signal Protocol handles message encryption separately.
///
/// Security notes:
/// - AES-256-GCM provides authenticated encryption (AEAD)
/// - 12-byte random nonce generated via Random.secure() for each operation
/// - Key derived from user's private key via SHA-256
/// - PointyCastle provides the real AES-GCM implementation (no placeholder)
class EncryptionService {
  const EncryptionService._();

  static const int _keySize = 32;
  static const int _nonceSize = 12;
  static const int _tagSizeBits = 128; // 16 bytes

  /// Derive an encryption key from the user's private key using SHA-256.
  static Uint8List deriveKeyFromPrivateKey(String privateKeyHex) {
    try {
      final privateKeyBytes = Uint8List.fromList(hex.decode(privateKeyHex));
      final digest = pc.SHA256Digest();
      return digest.process(privateKeyBytes);
    } catch (e, stackTrace) {
      developer.log('Failed to derive encryption key: $e');
      throw EncryptionException(
        'Failed to derive encryption key from private key',
        code: 'KEY_DERIVATION_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Encrypt plaintext data using AES-256-GCM.
  ///
  /// Returns a base64-encoded string containing:
  /// [nonce (12 bytes) || ciphertext || auth tag (16 bytes)]
  static String encrypt({
    required String plaintext,
    required Uint8List key,
  }) {
    try {
      if (key.length != _keySize) {
        throw EncryptionException(
          'Invalid key size: ${key.length} bytes, expected $_keySize',
          code: 'INVALID_KEY_SIZE',
        );
      }

      final nonce = _generateSecureRandom(_nonceSize);
      final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

      // FIX #6: Real AES-256-GCM via PointyCastle — replaces the XOR placeholder
      final encrypted = _aesGcmEncrypt(
        key: key,
        nonce: nonce,
        plaintext: plaintextBytes,
      );

      // Output format: nonce || ciphertext+tag
      final result = Uint8List(nonce.length + encrypted.length);
      result.setRange(0, nonce.length, nonce);
      result.setRange(nonce.length, result.length, encrypted);

      developer.log('Data encrypted successfully (AES-256-GCM)');
      return base64Encode(result);
    } on EncryptionException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Encryption failed: $e');
      throw EncryptionException(
        'Failed to encrypt data',
        code: 'ENCRYPTION_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Decrypt data encrypted with AES-256-GCM.
  ///
  /// Expects a base64-encoded string containing:
  /// [nonce (12 bytes) || ciphertext || auth tag (16 bytes)]
  static String decrypt({
    required String ciphertextBase64,
    required Uint8List key,
  }) {
    try {
      if (key.length != _keySize) {
        throw DecryptionException(
          'Invalid key size: ${key.length} bytes, expected $_keySize',
          code: 'INVALID_KEY_SIZE',
        );
      }

      final encryptedData = base64Decode(ciphertextBase64);

      // Minimum length: nonce + tag
      if (encryptedData.length < _nonceSize + (_tagSizeBits ~/ 8)) {
        throw DecryptionException(
          'Ciphertext too short',
          code: 'CIPHERTEXT_TOO_SHORT',
        );
      }

      final nonce = encryptedData.sublist(0, _nonceSize);
      final ciphertextWithTag = encryptedData.sublist(_nonceSize);

      final decrypted = _aesGcmDecrypt(
        key: key,
        nonce: nonce,
        ciphertextWithTag: ciphertextWithTag,
      );

      developer.log('Data decrypted successfully (AES-256-GCM)');
      return utf8.decode(decrypted);
    } on DecryptionException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Decryption failed: $e');
      throw DecryptionException(
        'Failed to decrypt data - data may be corrupted or key is wrong',
        code: 'DECRYPTION_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Encrypt a contacts list for Firestore backup.
  static String encryptContactsBackup({
    required List<Map<String, dynamic>> contacts,
    required String privateKeyHex,
  }) {
    try {
      final key = deriveKeyFromPrivateKey(privateKeyHex);
      final jsonData = jsonEncode(contacts);
      return encrypt(plaintext: jsonData, key: key);
    } catch (e, stackTrace) {
      throw EncryptionException(
        'Failed to encrypt contacts backup',
        code: 'CONTACTS_BACKUP_ENCRYPT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Decrypt a contacts backup from Firestore.
  static List<Map<String, dynamic>> decryptContactsBackup({
    required String encryptedBackupBase64,
    required String privateKeyHex,
  }) {
    try {
      final key = deriveKeyFromPrivateKey(privateKeyHex);
      final jsonData = decrypt(
        ciphertextBase64: encryptedBackupBase64,
        key: key,
      );
      final List<dynamic> decoded = jsonDecode(jsonData);
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e, stackTrace) {
      throw DecryptionException(
        'Failed to decrypt contacts backup',
        code: 'CONTACTS_BACKUP_DECRYPT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== PRIVATE HELPERS ====================

  /// Generate cryptographically secure random bytes.
  static Uint8List _generateSecureRandom(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Real AES-256-GCM encryption via PointyCastle.
  /// Returns ciphertext concatenated with 16-byte authentication tag.
  static Uint8List _aesGcmEncrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List plaintext,
  }) {
    final params = pc.AEADParameters(
      pc.KeyParameter(key),
      _tagSizeBits,
      nonce,
      Uint8List(0), // no additional authenticated data
    );

    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(true, params); // true = encrypt

    final output = Uint8List(cipher.getOutputSize(plaintext.length));
    var offset = cipher.processBytes(plaintext, 0, plaintext.length, output, 0);
    offset += cipher.doFinal(output, offset);

    return output.sublist(0, offset);
  }

  /// Real AES-256-GCM decryption via PointyCastle.
  /// Throws [DecryptionException] if the authentication tag is invalid.
  static Uint8List _aesGcmDecrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List ciphertextWithTag,
  }) {
    final params = pc.AEADParameters(
      pc.KeyParameter(key),
      _tagSizeBits,
      nonce,
      Uint8List(0),
    );

    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(false, params); // false = decrypt

    final output = Uint8List(cipher.getOutputSize(ciphertextWithTag.length));
    int offset;
    try {
      offset = cipher.processBytes(
        ciphertextWithTag, 0, ciphertextWithTag.length, output, 0,
      );
      offset += cipher.doFinal(output, offset);
    } on pc.InvalidCipherTextException catch (e) {
      developer.log('GCM auth tag verification failed: $e');
      throw DecryptionException(
        'Authentication tag verification failed - data may be tampered',
        code: 'AUTH_TAG_MISMATCH',
      );
    }

    return output.sublist(0, offset);
  }
}
