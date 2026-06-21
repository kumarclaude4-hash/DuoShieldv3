import 'package:equatable/equatable.dart';
import 'exceptions.dart';

/// Base failure class for all DuoShield domain-level failures.
/// Failures represent errors in the domain layer and are used by use cases.
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];

  /// Convert an exception to a failure
  factory Failure.fromException(Exception exception) {
    if (exception is EncryptionException) {
      return EncryptionFailure(exception.message);
    } else if (exception is DecryptionException) {
      return DecryptionFailure(exception.message);
    } else if (exception is SecureStorageException) {
      return SecureStorageFailure(exception.message);
    } else if (exception is LocalStorageException) {
      return LocalStorageFailure(exception.message);
    } else if (exception is FirebaseException) {
      return FirebaseFailure(exception.message);
    } else if (exception is NetworkException) {
      return NetworkFailure(exception.message);
    } else if (exception is ValidationException) {
      return ValidationFailure(exception.message);
    } else if (exception is UnauthorizedException) {
      return UnauthorizedFailure(exception.message);
    } else if (exception is NotFoundException) {
      return NotFoundFailure(exception.message);
    } else if (exception is AlreadyExistsException) {
      return AlreadyExistsFailure(exception.message);
    } else if (exception is SignalProtocolException) {
      return SignalProtocolFailure(exception.message);
    } else if (exception is IdentityException) {
      return IdentityFailure(exception.message);
    } else if (exception is PinException) {
      return PinFailure(exception.message);
    } else if (exception is SeedPhraseException) {
      return SeedPhraseFailure(exception.message);
    } else if (exception is ContactException) {
      return ContactFailure(exception.message);
    } else if (exception is MessagingException) {
      return MessagingFailure(exception.message);
    } else if (exception is NotificationException) {
      return NotificationFailure(exception.message);
    } else {
      return UnknownFailure(exception.toString());
    }
  }
}

/// Failure for encryption operations.
class EncryptionFailure extends Failure {
  const EncryptionFailure(super.message);
}

/// Failure for decryption operations.
class DecryptionFailure extends Failure {
  const DecryptionFailure(super.message);
}

/// Failure for secure storage operations.
class SecureStorageFailure extends Failure {
  const SecureStorageFailure(super.message);
}

/// Failure for local storage operations.
class LocalStorageFailure extends Failure {
  const LocalStorageFailure(super.message);
}

/// Failure for Firebase operations.
class FirebaseFailure extends Failure {
  const FirebaseFailure(super.message);
}

/// Failure for network operations.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Failure for validation operations.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Failure for unauthorized access.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message);
}

/// Failure for not found resources.
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Failure for duplicate resources.
class AlreadyExistsFailure extends Failure {
  const AlreadyExistsFailure(super.message);
}

/// Failure for Signal protocol operations.
class SignalProtocolFailure extends Failure {
  const SignalProtocolFailure(super.message);
}

/// Failure for identity operations.
class IdentityFailure extends Failure {
  const IdentityFailure(super.message);
}

/// Failure for PIN operations.
class PinFailure extends Failure {
  const PinFailure(super.message);
}

/// Failure for seed phrase operations.
class SeedPhraseFailure extends Failure {
  const SeedPhraseFailure(super.message);
}

/// Failure for contact operations.
class ContactFailure extends Failure {
  const ContactFailure(super.message);
}

/// Failure for messaging operations.
class MessagingFailure extends Failure {
  const MessagingFailure(super.message);
}

/// Failure for notification operations.
class NotificationFailure extends Failure {
  const NotificationFailure(super.message);
}

/// Failure for unknown errors.
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
