import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto;
import 'package:convert/convert.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';

import '../errors/exceptions.dart';

/// Utility class for all cryptographic key operations in DuoShield.
/// Handles seed phrase generation, key derivation, and key format validation.
class KeyUtils {
  const KeyUtils._();

  static const String _derivationPath = "m/44'/784'/0'/0'/0'";
  static const int _seedLength = 32;

  /// Generate a new 24-word BIP39 mnemonic seed phrase.
  static String generateSeedPhrase() {
    try {
      final mnemonic = bip39.generateMnemonic(strength: 256);
      developer.log('Seed phrase generated (24 words)');
      return mnemonic;
    } catch (e, stackTrace) {
      developer.log('Failed to generate seed phrase: $e');
      throw IdentityException(
        'Failed to generate seed phrase',
        code: 'SEED_GENERATE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Validate a BIP39 mnemonic seed phrase.
  static bool validateSeedPhrase(String mnemonic) {
    try {
      if (mnemonic.trim().isEmpty) return false;
      return bip39.validateMnemonic(mnemonic.trim());
    } catch (e) {
      developer.log('Seed phrase validation error: $e');
      return false;
    }
  }

  /// Convert a mnemonic seed phrase to its BIP39 seed bytes.
  static Uint8List mnemonicToSeed(String mnemonic) {
    try {
      if (!validateSeedPhrase(mnemonic)) {
        throw ValidationException(
          'Invalid mnemonic seed phrase',
          code: 'INVALID_MNEMONIC',
        );
      }
      final seed = bip39.mnemonicToSeed(mnemonic.trim());
      developer.log('Mnemonic converted to seed');
      return seed;
    } on ValidationException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to convert mnemonic to seed: $e');
      throw IdentityException(
        'Failed to derive seed from mnemonic',
        code: 'MNEMONIC_TO_SEED_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Derive an Ed25519 keypair from a mnemonic seed phrase.
  /// Returns a map with 'privateKey' and 'publicKey' as hex strings.
  static Future<Map<String, String>> deriveKeypair(String mnemonic) async {
    try {
      final seed = mnemonicToSeed(mnemonic);

      final keyData = await ED25519_HD_KEY.derivePath(
        _derivationPath,
        seed,
      );

      final privateKey = keyData.key;

      if (privateKey.length != _seedLength) {
        throw IdentityException(
          'Derived private key has invalid length: ${privateKey.length}',
          code: 'INVALID_KEY_LENGTH',
        );
      }

      // FIX #9b: Use getPublicKey() from ed25519_hd_key — the previous
      // implementation called getMasterKeyFromSeed(privateKey) which is
      // semantically wrong (it treats an already-derived key as a seed),
      // and then returned the chain code bytes instead of the public key.
      final publicKey = await _derivePublicKey(privateKey);

      final privateKeyHex = hex.encode(privateKey);
      final publicKeyHex = hex.encode(publicKey);

      developer.log(
        'Keypair derived successfully. Public key: ${publicKeyHex.substring(0, 16)}...',
      );

      return {
        'privateKey': privateKeyHex,
        'publicKey': publicKeyHex,
      };
    } on IdentityException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to derive keypair: $e');
      throw IdentityException(
        'Failed to derive identity keypair',
        code: 'KEYPAIR_DERIVATION_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Derive Ed25519 public key from private key bytes.
  ///
  /// FIX #9b: Replaced wrong getMasterKeyFromSeed(privateKey) call with the
  /// correct ED25519_HD_KEY.getPublicKey(privateKey, false) API.
  /// The old code passed an already-derived private key as if it were a root
  /// seed, then returned chain-code bytes (not the public key).
  static Future<Uint8List> _derivePublicKey(Uint8List privateKey) async {
    try {
      // getPublicKey(privateKey, withZeroByte: false) performs Ed25519
      // scalar multiplication to produce the compressed public key (32 bytes).
      final publicKey = await ED25519_HD_KEY.getPublicKey(privateKey, false);
      return publicKey;
    } catch (e, stackTrace) {
      developer.log('Failed to derive public key: $e');
      throw IdentityException(
        'Failed to derive public key from private key',
        code: 'PUBLIC_KEY_DERIVATION_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Validate that a string is a valid hex-encoded public key (32 bytes = 64 hex chars).
  static bool isValidPublicKey(String publicKey) {
    if (publicKey.isEmpty) return false;
    final cleanKey =
        publicKey.startsWith('0x') ? publicKey.substring(2) : publicKey;
    if (cleanKey.length != 64) return false;
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
    return hexRegex.hasMatch(cleanKey);
  }

  /// Normalize a public key string to lowercase hex without 0x prefix.
  static String normalizePublicKey(String publicKey) {
    final cleanKey =
        publicKey.startsWith('0x') ? publicKey.substring(2) : publicKey;
    return cleanKey.toLowerCase();
  }

  /// Hash a public key to create a shorter display identifier (first 16 hex chars of SHA-256).
  static String hashPublicKeyForDisplay(String publicKey) {
    try {
      final normalized = normalizePublicKey(publicKey);
      final bytes = hex.decode(normalized);
      final hashResult = crypto.sha256.convert(bytes);
      return hex.encode(hashResult.bytes).substring(0, 16);
    } catch (e) {
      developer.log('Failed to hash public key: $e');
      return publicKey.substring(0, 16);
    }
  }

  /// Convert hex string to bytes.
  static Uint8List hexToBytes(String hexStr) {
    try {
      final clean =
          hexStr.startsWith('0x') ? hexStr.substring(2) : hexStr;
      return Uint8List.fromList(hex.decode(clean));
    } catch (e, stackTrace) {
      developer.log('Failed to convert hex to bytes: $e');
      throw ValidationException(
        'Invalid hex string: $hexStr',
        code: 'INVALID_HEX',
        stackTrace: stackTrace,
      );
    }
  }

  /// Convert bytes to hex string.
  static String bytesToHex(Uint8List bytes) {
    return hex.encode(bytes);
  }

  /// Generate a SHA-256 hash of the given data.
  static String sha256(String data) {
    final bytes = Uint8List.fromList(utf8.encode(data));
    final hashResult = crypto.sha256.convert(bytes);
    return hex.encode(hashResult.bytes);
  }

  /// Generate a cryptographically secure random nonce.
  ///
  /// FIX #9a: crypto.SecureRandom() does not exist in the crypto package.
  /// Replaced with dart:math Random.secure(), which is the correct Flutter/Dart
  /// API for a cryptographically secure pseudo-random number generator.
  static Uint8List generateNonce(int length) {
    final random = math.Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
