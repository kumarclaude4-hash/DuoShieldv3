import 'package:equatable/equatable.dart';

/// Identity entity representing the user's cryptographic identity.
///
/// Contains only the public-facing identity information.
/// The private key is stored separately in flutter_secure_storage.
class IdentityEntity extends Equatable {
  /// User's public key (hex string) - also used as user identifier
  final String publicKey;

  /// Firebase anonymous authentication UID
  final String? uid;

  /// Whether the seed phrase has been confirmed by the user
  final bool seedConfirmed;

  /// When the identity was created
  final DateTime? createdAt;

  const IdentityEntity({
    required this.publicKey,
    this.uid,
    this.seedConfirmed = false,
    this.createdAt,
  });

  /// Get a shortened display version of the public key
  String get displayPublicKey {
    if (publicKey.length <= 16) return publicKey;
    return '${publicKey.substring(0, 8)}...${publicKey.substring(publicKey.length - 8)}';
  }

  /// Get the first 16 characters for QR code compact display
  String get qrDisplayKey {
    if (publicKey.length <= 16) return publicKey;
    return publicKey.substring(0, 16);
  }

  /// Check if identity is fully initialized
  bool get isComplete => publicKey.isNotEmpty && seedConfirmed;

  IdentityEntity copyWith({
    String? publicKey,
    String? uid,
    bool? seedConfirmed,
    DateTime? createdAt,
  }) {
    return IdentityEntity(
      publicKey: publicKey ?? this.publicKey,
      uid: uid ?? this.uid,
      seedConfirmed: seedConfirmed ?? this.seedConfirmed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [publicKey, uid, seedConfirmed, createdAt];

  @override
  String toString() =>
      'IdentityEntity(publicKey: ${displayPublicKey}, uid: $uid, confirmed: $seedConfirmed)';
}
