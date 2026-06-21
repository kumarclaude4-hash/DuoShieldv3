import 'package:equatable/equatable.dart';

/// Contact entity representing a user's contact.
/// Each contact has a unique ID, display name, and public key for encryption.
class ContactEntity extends Equatable {
  /// Unique contact ID (UUID)
  final String id;

  /// Display name chosen by the user
  final String name;

  /// Contact's public key (hex string) used for Signal encryption
  final String publicKey;

  /// When the contact was added
  final DateTime addedAt;

  const ContactEntity({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.addedAt,
  });

  /// Get shortened display version of the public key
  String get displayPublicKey {
    if (publicKey.length <= 16) return publicKey;
    return '${publicKey.substring(0, 8)}...${publicKey.substring(publicKey.length - 8)}';
  }

  /// Get a very short version for compact UI
  String get shortPublicKey {
    if (publicKey.length <= 12) return publicKey;
    return '${publicKey.substring(0, 6)}...${publicKey.substring(publicKey.length - 6)}';
  }

  ContactEntity copyWith({
    String? id,
    String? name,
    String? publicKey,
    DateTime? addedAt,
  }) {
    return ContactEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      publicKey: publicKey ?? this.publicKey,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, publicKey, addedAt];

  @override
  String toString() => 'ContactEntity(id: $id, name: $name, key: $shortPublicKey)';
}
