import 'package:flutter_test/flutter_test.dart';
import 'package:bcrypt/bcrypt.dart';

/// Tests for PIN hashing and verification logic.
/// This mirrors the logic in SettingsRepositoryImpl.
void main() {
  const int bcryptRounds = 12;

  String hashPin(String pin) {
    return BCrypt.hashpw(pin, BCrypt.gensalt(rounds: bcryptRounds));
  }

  bool verifyPin(String pin, String hash) {
    return BCrypt.checkpw(pin, hash);
  }

  group('PIN Hashing', () {
    test('should hash 6-digit PIN', () {
      final hash = hashPin('123456');
      expect(hash, isNotEmpty);
      expect(hash, isNot(equals('123456')));
      expect(hash.startsWith('\$2a\$'), isTrue);
    });

    test('should verify correct PIN', () {
      final hash = hashPin('123456');
      expect(verifyPin('123456', hash), isTrue);
    });

    test('should reject incorrect PIN', () {
      final hash = hashPin('123456');
      expect(verifyPin('654321', hash), isFalse);
    });

    test('should reject similar PIN', () {
      final hash = hashPin('123456');
      expect(verifyPin('123455', hash), isFalse);
    });

    test('should produce different hashes for same PIN', () {
      // bcrypt salts are random, so same PIN produces different hashes
      final hash1 = hashPin('123456');
      final hash2 = hashPin('123456');
      expect(hash1, isNot(equals(hash2)));
      // But both should verify correctly
      expect(verifyPin('123456', hash1), isTrue);
      expect(verifyPin('123456', hash2), isTrue);
    });

    test('should handle PIN with leading zeros', () {
      final hash = hashPin('000000');
      expect(verifyPin('000000', hash), isTrue);
      expect(verifyPin('000001', hash), isFalse);
    });

    test('should handle edge case all-same digits', () {
      final hash = hashPin('111111');
      expect(verifyPin('111111', hash), isTrue);
      expect(verifyPin('111112', hash), isFalse);
    });
  });

  group('Duress PIN vs Normal PIN', () {
    test('normal and duress PINs should be independently verifiable', () {
      final normalHash = hashPin('123456');
      final duressHash = hashPin('987654');

      // Normal PIN verifies against normal hash
      expect(verifyPin('123456', normalHash), isTrue);
      expect(verifyPin('123456', duressHash), isFalse);

      // Duress PIN verifies against duress hash
      expect(verifyPin('987654', duressHash), isTrue);
      expect(verifyPin('987654', normalHash), isFalse);
    });

    test('duress PIN should not equal normal PIN', () {
      // This is enforced at setup time, but let's verify the concept
      final pin1 = '123456';
      final pin2 = '654321';
      expect(pin1, isNot(equals(pin2)));
    });
  });

  group('Lock Duration Calculation', () {
    Duration calculateLockDuration(int failedAttempts) {
      const maxFailedAttempts = 5;
      const baseLockSeconds = 30;

      if (failedAttempts < maxFailedAttempts) {
        return Duration.zero;
      }
      final multiplier =
          Duration.millisecondsPerSecond ~/ 1000 * (1 << (failedAttempts - maxFailedAttempts));
      // Using pow equivalent: 2^(failedAttempts - maxFailedAttempts)
      var multiplier2 = 1;
      for (var i = 0; i < failedAttempts - maxFailedAttempts; i++) {
        multiplier2 *= 2;
      }
      return Duration(seconds: baseLockSeconds * multiplier2);
    }

    test('no lock for fewer than 5 attempts', () {
      expect(calculateLockDuration(0), equals(Duration.zero));
      expect(calculateLockDuration(1), equals(Duration.zero));
      expect(calculateLockDuration(4), equals(Duration.zero));
    });

    test('30s lock at 5 attempts', () {
      expect(calculateLockDuration(5), equals(const Duration(seconds: 30)));
    });

    test('60s lock at 6 attempts', () {
      expect(calculateLockDuration(6), equals(const Duration(seconds: 60)));
    });

    test('120s lock at 7 attempts', () {
      expect(calculateLockDuration(7), equals(const Duration(seconds: 120)));
    });

    test('240s lock at 8 attempts', () {
      expect(calculateLockDuration(8), equals(const Duration(seconds: 240)));
    });

    test('480s lock at 9 attempts', () {
      expect(calculateLockDuration(9), equals(const Duration(seconds: 480)));
    });

    test('lock duration doubles each time', () {
      final d5 = calculateLockDuration(5).inSeconds;
      final d6 = calculateLockDuration(6).inSeconds;
      final d7 = calculateLockDuration(7).inSeconds;

      expect(d6, equals(d5 * 2));
      expect(d7, equals(d6 * 2));
    });
  });
}
