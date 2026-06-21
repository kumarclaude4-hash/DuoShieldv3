/// Base exception class for all DuoShield application exceptions.
/// All custom exceptions extend this class to provide consistent error handling.
class DuoShieldException implements Exception {
  final String message;
  final String? code;
  final StackTrace? stackTrace;

  const DuoShieldException(this.message, {this.code, this.stackTrace});

  @override
  String toString() => 'DuoShieldException[$code]: $message';
}

/// Exception thrown when an encryption operation fails.
/// This includes Signal protocol errors, AES encryption failures, etc.
class EncryptionException extends DuoShieldException {
  const EncryptionException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when a decryption operation fails.
/// This includes Signal protocol errors, AES decryption failures, etc.
class DecryptionException extends DuoShieldException {
  const DecryptionException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when there is a problem with secure storage.
/// This includes keychain/keystore access failures.
class SecureStorageException extends DuoShieldException {
  const SecureStorageException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when there is a problem with local Hive storage.
class LocalStorageException extends DuoShieldException {
  const LocalStorageException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when there is a Firebase communication error.
class FirebaseException extends DuoShieldException {
  const FirebaseException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when the network is unavailable.
class NetworkException extends DuoShieldException {
  const NetworkException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when user input is invalid.
class ValidationException extends DuoShieldException {
  const ValidationException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when the user is not authenticated.
class UnauthorizedException extends DuoShieldException {
  const UnauthorizedException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when a requested resource is not found.
class NotFoundException extends DuoShieldException {
  const NotFoundException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when a resource already exists (e.g., duplicate contact).
class AlreadyExistsException extends DuoShieldException {
  const AlreadyExistsException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when Signal protocol session operations fail.
class SignalProtocolException extends DuoShieldException {
  const SignalProtocolException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when identity operations fail.
class IdentityException extends DuoShieldException {
  const IdentityException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when PIN operations fail.
class PinException extends DuoShieldException {
  const PinException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when too many failed PIN attempts occur.
class TooManyAttemptsException extends PinException {
  final Duration remainingLockDuration;

  const TooManyAttemptsException(
    super.message, {
    required this.remainingLockDuration,
    super.code,
    super.stackTrace,
  });
}

/// Exception thrown when a seed phrase operation fails.
class SeedPhraseException extends DuoShieldException {
  const SeedPhraseException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when a contact operation fails.
class ContactException extends DuoShieldException {
  const ContactException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when a messaging operation fails.
class MessagingException extends DuoShieldException {
  const MessagingException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when notification operations fail.
class NotificationException extends DuoShieldException {
  const NotificationException(super.message, {super.code, super.stackTrace});
}
