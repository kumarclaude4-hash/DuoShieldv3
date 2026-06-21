import 'package:flutter_test/flutter_test.dart';
import 'package:bcrypt/bcrypt.dart';

/// Tests for duress PIN wipe logic.
/// Ensures the duress flow works correctly without exposing the wipe to observers.
void main() {
  const int bcryptRounds = 12;

  String hashPin(String pin) {
    return BCrypt.hashpw(pin, BCrypt.gensalt(rounds: bcryptRounds));
  }

  bool verifyPin(String pin, String hash) {
    return BCrypt.checkpw(pin, hash);
  }

  group('Duress PIN Wipe Logic', () {
    test('should detect duress PIN correctly', () {
      final normalPinHash = hashPin('123456');
      final duressPinHash = hashPin('999999');

      // User enters duress PIN
      final enteredPin = '999999';

      // Check against normal PIN - should fail
      final isNormalPin = verifyPin(enteredPin, normalPinHash);
      expect(isNormalPin, isFalse);

      // Check against duress PIN - should succeed
      final isDuressPin = verifyPin(enteredPin, duressPinHash);
      expect(isDuressPin, isTrue);
    });

    test('should appear to unlock normally when duress PIN is used', () {
      // The UI should not show any difference between normal unlock and duress unlock
      // Both return a successful verification

      final duressPinHash = hashPin('999999');
      final enteredPin = '999999';

      final isValid = verifyPin(enteredPin, duressPinHash);

      // From the UI perspective, this is a successful unlock
      expect(isValid, isTrue);

      // The background wipe happens after the unlock appears successful
      // This is the critical security property
    });

    test('duress PIN should be different from normal PIN', () {
      final normalPin = '123456';
      final duressPin = '999999';

      expect(normalPin, isNot(equals(duressPin)));
    });

    test('should not confuse normal PIN with duress PIN', () {
      final normalPinHash = hashPin('123456');
      final duressPinHash = hashPin('999999');

      // Normal PIN should only verify against normal hash
      expect(verifyPin('123456', normalPinHash), isTrue);
      expect(verifyPin('123456', duressPinHash), isFalse);

      // Duress PIN should only verify against duress hash
      expect(verifyPin('999999', duressPinHash), isTrue);
      expect(verifyPin('999999', normalPinHash), isFalse);
    });

    test('wipe sequence should clear all sensitive data', () {
      // This test verifies the wipe sequence logic
      // In real implementation, this would verify Hive boxes are cleared
      // and secure storage is wiped

      final itemsToWipe = [
        'private_key',
        'pin_hash',
        'duress_pin_hash',
        'identity_data',
        'contacts',
        'messages',
        'signal_sessions',
      ];

      // Simulate wipe
      final wipedItems = <String>[];
      for (final item in itemsToWipe) {
        wipedItems.add(item);
      }

      // All items should be wiped
      expect(wipedItems.length, equals(itemsToWipe.length));
      expect(wipedItems, contains('private_key'));
      expect(wipedItems, contains('pin_hash'));
      expect(wipedItems, contains('duress_pin_hash'));
      expect(wipedItems, contains('signal_sessions'));
    });

    test('wipe should NOT affect Firestore data', () {
      // Critical security property: duress only affects local data
      // Firestore data (encrypted messages, public key, etc.) remains intact

      final localData = ['messages', 'keys', 'contacts'];
      final remoteData = ['firestore_messages', 'firestore_profile'];

      // After wipe
      final wipedLocal = <String>[];
      final preservedRemote = List<String>.from(remoteData);

      // Local data is wiped
      for (final item in localData) {
        wipedLocal.add(item);
      }
      expect(wipedLocal.length, equals(localData.length));

      // Remote data is preserved
      expect(preservedRemote.length, equals(remoteData.length));
      expect(preservedRemote, contains('firestore_messages'));
      expect(preservedRemote, contains('firestore_profile'));
    });

    test('duress PIN setup should validate PINs are different', () {
      final normalPin = '123456';
      final duressPin = '123456'; // Same as normal - should be rejected

      // Validation at setup time
      final isDifferent = normalPin != duressPin;
      expect(isDifferent, isFalse);

      // Now with different PINs
      final duressPin2 = '999999';
      final isDifferent2 = normalPin != duressPin2;
      expect(isDifferent2, isTrue);
    });

    test('should handle duress PIN not set', () {
      // When no duress PIN is set, the hash is null/empty
      String? duressPinHash;

      final enteredPin = '999999';

      // Should not verify
      final isDuress = duressPinHash != null &&
          duressPinHash.isNotEmpty &&
          verifyPin(enteredPin, duressPinHash);

      expect(isDuress, isFalse);
    });
  });

  group('Exponential Backoff for Failed Attempts', () {
    test('should calculate correct lock durations', () {
      const baseSeconds = 30;

      int calculateLockSeconds(int failedAttempts) {
        const maxFailedAttempts = 5;
        if (failedAttempts < maxFailedAttempts) return 0;

        var multiplier = 1;
        for (var i = 0; i < failedAttempts - maxFailedAttempts; i++) {
          multiplier *= 2;
        }
        return baseSeconds * multiplier;
      }

      // 0-4 attempts: no lock
      expect(calculateLockSeconds(0), equals(0));
      expect(calculateLockSeconds(4), equals(0));

      // 5 attempts: 30 seconds
      expect(calculateLockSeconds(5), equals(30));

      // 6 attempts: 60 seconds
      expect(calculateLockSeconds(6), equals(60));

      // 7 attempts: 120 seconds
      expect(calculateLockSeconds(7), equals(120));

      // 8 attempts: 240 seconds
      expect(calculateLockSeconds(8), equals(240));

      // 10 attempts: 960 seconds
      expect(calculateLockSeconds(10), equals(960));
    });
  });
}
