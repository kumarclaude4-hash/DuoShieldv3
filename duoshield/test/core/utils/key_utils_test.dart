import 'package:flutter_test/flutter_test.dart';
import 'package:duoshield/core/utils/key_utils.dart';

void main() {
  group('KeyUtils', () {
    group('generateSeedPhrase', () {
      test('should generate a 24-word seed phrase', () {
        final seedPhrase = KeyUtils.generateSeedPhrase();
        final words = seedPhrase.split(' ');
        expect(words.length, equals(24));
      });

      test('should generate different seed phrases each time', () {
        final seedPhrase1 = KeyUtils.generateSeedPhrase();
        final seedPhrase2 = KeyUtils.generateSeedPhrase();
        expect(seedPhrase1, isNot(equals(seedPhrase2)));
      });

      test('should generate valid BIP39 mnemonic', () {
        final seedPhrase = KeyUtils.generateSeedPhrase();
        final isValid = KeyUtils.validateSeedPhrase(seedPhrase);
        expect(isValid, isTrue);
      });
    });

    group('validateSeedPhrase', () {
      test('should return true for valid 24-word mnemonic', () {
        final seedPhrase = KeyUtils.generateSeedPhrase();
        expect(KeyUtils.validateSeedPhrase(seedPhrase), isTrue);
      });

      test('should return false for empty string', () {
        expect(KeyUtils.validateSeedPhrase(''), isFalse);
      });

      test('should return false for invalid words', () {
        expect(
          KeyUtils.validateSeedPhrase('invalid word list here'),
          isFalse,
        );
      });

      test('should return false for wrong word count', () {
        // 12 words instead of 24
        final shortPhrase =
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon';
        expect(KeyUtils.validateSeedPhrase(shortPhrase), isFalse);
      });
    });

    group('deriveKeypair', () {
      test('should derive consistent keypair from same mnemonic', () async {
        final seedPhrase = KeyUtils.generateSeedPhrase();
        final keypair1 = await KeyUtils.deriveKeypair(seedPhrase);
        final keypair2 = await KeyUtils.deriveKeypair(seedPhrase);

        expect(keypair1['publicKey'], equals(keypair2['publicKey']));
        expect(keypair1['privateKey'], equals(keypair2['privateKey']));
      });

      test('should derive different keypairs from different mnemonics', () async {
        final seedPhrase1 = KeyUtils.generateSeedPhrase();
        final seedPhrase2 = KeyUtils.generateSeedPhrase();

        final keypair1 = await KeyUtils.deriveKeypair(seedPhrase1);
        final keypair2 = await KeyUtils.deriveKeypair(seedPhrase2);

        expect(keypair1['publicKey'], isNot(equals(keypair2['publicKey'])));
      });

      test('should produce 64-char hex public key', () async {
        final seedPhrase = KeyUtils.generateSeedPhrase();
        final keypair = await KeyUtils.deriveKeypair(seedPhrase);

        expect(keypair['publicKey']!.length, equals(64));
        expect(keypair['privateKey']!.length, equals(64));
      });
    });

    group('isValidPublicKey', () {
      test('should return true for valid 64-char hex key', () {
        expect(
          KeyUtils.isValidPublicKey(
            'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456',
          ),
          isTrue,
        );
      });

      test('should return true for valid key with 0x prefix', () {
        expect(
          KeyUtils.isValidPublicKey(
            '0xa1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456',
          ),
          isTrue,
        );
      });

      test('should return false for empty string', () {
        expect(KeyUtils.isValidPublicKey(''), isFalse);
      });

      test('should return false for non-hex characters', () {
        expect(
          KeyUtils.isValidPublicKey(
            'g1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456',
          ),
          isFalse,
        );
      });

      test('should return false for wrong length', () {
        expect(
          KeyUtils.isValidPublicKey('a1b2c3d4'),
          isFalse,
        );
      });

      test('should return false for 63 characters', () {
        expect(
          KeyUtils.isValidPublicKey(
            'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef12345',
          ),
          isFalse,
        );
      });
    });

    group('normalizePublicKey', () {
      test('should remove 0x prefix and lowercase', () {
        final result = KeyUtils.normalizePublicKey(
          '0xA1B2C3D4E5F6789012345678901234567890ABCDEF1234567890ABCDEF123456',
        );
        expect(
          result,
          equals('a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456'),
        );
      });

      test('should handle already normalized key', () {
        final key = 'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456';
        final result = KeyUtils.normalizePublicKey(key);
        expect(result, equals(key));
      });
    });

    group('hexToBytes / bytesToHex', () {
      test('should convert hex to bytes and back', () {
        final hexStr = 'a1b2c3d4e5f67890';
        final bytes = KeyUtils.hexToBytes(hexStr);
        final backToHex = KeyUtils.bytesToHex(bytes);
        expect(backToHex, equals(hexStr));
      });

      test('should handle hex with 0x prefix', () {
        final bytes = KeyUtils.hexToBytes('0xa1b2');
        expect(bytes.length, equals(2));
      });
    });

    group('sha256', () {
      test('should produce 64-char hex hash', () {
        final hash = KeyUtils.sha256('test');
        expect(hash.length, equals(64));
      });

      test('should produce consistent hash for same input', () {
        final hash1 = KeyUtils.sha256('test');
        final hash2 = KeyUtils.sha256('test');
        expect(hash1, equals(hash2));
      });

      test('should produce different hashes for different inputs', () {
        final hash1 = KeyUtils.sha256('test1');
        final hash2 = KeyUtils.sha256('test2');
        expect(hash1, isNot(equals(hash2)));
      });
    });
  });
}
