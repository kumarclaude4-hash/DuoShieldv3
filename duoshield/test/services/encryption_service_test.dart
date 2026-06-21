import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:duoshield/services/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    late String _testPrivateKey;

    setUp(() {
      _testPrivateKey =
          'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456';
    });

    group('deriveKeyFromPrivateKey', () {
      test('should produce 32-byte key', () {
        final key = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);
        expect(key.length, equals(32));
      });

      test('should produce consistent key for same input', () {
        final key1 = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);
        final key2 = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);
        expect(key1, equals(key2));
      });

      test('should produce different keys for different inputs', () {
        final key1 = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);
        final key2 = EncryptionService.deriveKeyFromPrivateKey(
          'b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456a1',
        );
        expect(key1, isNot(equals(key2)));
      });
    });

    group('encrypt and decrypt', () {
      test('should successfully encrypt and decrypt data', () {
        final key = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);
        final plaintext = 'Hello, secure world!';

        final ciphertext = EncryptionService.encrypt(
          plaintext: plaintext,
          key: key,
        );

        expect(ciphertext, isNot(equals(plaintext)));
        expect(ciphertext.isNotEmpty, isTrue);

        final decrypted = EncryptionService.decrypt(
          ciphertextBase64: ciphertext,
          key: key,
        );

        expect(decrypted, equals(plaintext));
      });

      test('should produce different ciphertexts for same plaintext', () {
        final key = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);
        final plaintext = 'Test message';

        final ciphertext1 = EncryptionService.encrypt(
          plaintext: plaintext,
          key: key,
        );
        final ciphertext2 = EncryptionService.encrypt(
          plaintext: plaintext,
          key: key,
        );

        // Due to random nonce, ciphertexts should differ
        expect(ciphertext1, isNot(equals(ciphertext2)));
      });

      test('should handle empty string', () {
        final key = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);

        final ciphertext = EncryptionService.encrypt(
          plaintext: '',
          key: key,
        );

        final decrypted = EncryptionService.decrypt(
          ciphertextBase64: ciphertext,
          key: key,
        );

        expect(decrypted, equals(''));
      });

      test('should handle unicode characters', () {
        final key = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);
        final plaintext = 'Hello 世界 🌍 Привет';

        final ciphertext = EncryptionService.encrypt(
          plaintext: plaintext,
          key: key,
        );

        final decrypted = EncryptionService.decrypt(
          ciphertextBase64: ciphertext,
          key: key,
        );

        expect(decrypted, equals(plaintext));
      });

      test('should handle long text', () {
        final key = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);
        final plaintext = 'A' * 10000;

        final ciphertext = EncryptionService.encrypt(
          plaintext: plaintext,
          key: key,
        );

        final decrypted = EncryptionService.decrypt(
          ciphertextBase64: ciphertext,
          key: key,
        );

        expect(decrypted, equals(plaintext));
      });

      test('should fail with wrong key', () {
        final key1 = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);
        final key2 = EncryptionService.deriveKeyFromPrivateKey(
          '0000000000000000000000000000000000000000000000000000000000000000',
        );
        final plaintext = 'Secret message';

        final ciphertext = EncryptionService.encrypt(
          plaintext: plaintext,
          key: key1,
        );

        // Expect decryption with wrong key to fail
        expect(
          () => EncryptionService.decrypt(
            ciphertextBase64: ciphertext,
            key: key2,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should fail with corrupted ciphertext', () {
        final key = EncryptionService.deriveKeyFromPrivateKey(_testPrivateKey);
        final plaintext = 'Secret message';

        final ciphertext = EncryptionService.encrypt(
          plaintext: plaintext,
          key: key,
        );

        // Corrupt the ciphertext
        final corrupted = ciphertext.substring(0, ciphertext.length - 4) + 'XXXX';

        expect(
          () => EncryptionService.decrypt(
            ciphertextBase64: corrupted,
            key: key,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('encryptContactsBackup / decryptContactsBackup', () {
      test('should encrypt and decrypt contacts list', () {
        final contacts = [
          {
            'id': 'contact-1',
            'name': 'Alice',
            'publicKey': 'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456',
            'addedAt': '2024-01-01T00:00:00.000Z',
          },
          {
            'id': 'contact-2',
            'name': 'Bob',
            'publicKey': 'b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456a1',
            'addedAt': '2024-01-02T00:00:00.000Z',
          },
        ];

        final encrypted = EncryptionService.encryptContactsBackup(
          contacts: contacts,
          privateKeyHex: _testPrivateKey,
        );

        expect(encrypted, isNotEmpty);
        expect(encrypted, isNot(contains('Alice')));

        final decrypted = EncryptionService.decryptContactsBackup(
          encryptedBackupBase64: encrypted,
          privateKeyHex: _testPrivateKey,
        );

        expect(decrypted.length, equals(2));
        expect(decrypted[0]['name'], equals('Alice'));
        expect(decrypted[1]['name'], equals('Bob'));
        expect(decrypted[0]['publicKey'], equals(contacts[0]['publicKey']));
      });

      test('should handle empty contacts list', () {
        final encrypted = EncryptionService.encryptContactsBackup(
          contacts: [],
          privateKeyHex: _testPrivateKey,
        );

        final decrypted = EncryptionService.decryptContactsBackup(
          encryptedBackupBase64: encrypted,
          privateKeyHex: _testPrivateKey,
        );

        expect(decrypted, isEmpty);
      });
    });
  });
}
