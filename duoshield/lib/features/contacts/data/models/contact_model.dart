import '../../domain/entities/contact_entity.dart';

/// Data model for contact storage in Hive.
/// Maps to [ContactEntity] for domain layer usage.
class ContactModel {
  /// Unique contact ID (UUID)
  final String id;

  /// Display name
  final String name;

  /// Public key (hex string)
  final String publicKey;

  /// When the contact was added
  final DateTime addedAt;

  const ContactModel({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.addedAt,
  });

  /// Convert from JSON/Hive map
  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String,
      name: json['name'] as String,
      publicKey: json['publicKey'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  /// Convert to JSON/Hive map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'publicKey': publicKey,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  /// Convert to domain entity
  ContactEntity toEntity() {
    return ContactEntity(
      id: id,
      name: name,
      publicKey: publicKey,
      addedAt: addedAt,
    );
  }

  /// Create from domain entity
  factory ContactModel.fromEntity(ContactEntity entity) {
    return ContactModel(
      id: entity.id,
      name: entity.name,
      publicKey: entity.publicKey,
      addedAt: entity.addedAt,
    );
  }

  ContactModel copyWith({
    String? id,
    String? name,
    String? publicKey,
    DateTime? addedAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      publicKey: publicKey ?? this.publicKey,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
