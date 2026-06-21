import '../../domain/entities/identity_entity.dart';

/// Data model for identity storage in Hive.
/// Maps to [IdentityEntity] for domain layer usage.
class IdentityModel {
  /// Public key as hex string
  final String publicKey;

  /// Firebase anonymous UID
  final String? uid;

  /// Whether seed phrase was confirmed
  final bool seedConfirmed;

  /// Creation timestamp
  final DateTime? createdAt;

  const IdentityModel({
    required this.publicKey,
    this.uid,
    this.seedConfirmed = false,
    this.createdAt,
  });

  /// Convert from JSON/Hive map
  factory IdentityModel.fromJson(Map<String, dynamic> json) {
    return IdentityModel(
      publicKey: json['publicKey'] as String,
      uid: json['uid'] as String?,
      seedConfirmed: json['seedConfirmed'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  /// Convert to JSON/Hive map
  Map<String, dynamic> toJson() {
    return {
      'publicKey': publicKey,
      'uid': uid,
      'seedConfirmed': seedConfirmed,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// Convert to domain entity
  IdentityEntity toEntity() {
    return IdentityEntity(
      publicKey: publicKey,
      uid: uid,
      seedConfirmed: seedConfirmed,
      createdAt: createdAt,
    );
  }

  /// Create from domain entity
  factory IdentityModel.fromEntity(IdentityEntity entity) {
    return IdentityModel(
      publicKey: entity.publicKey,
      uid: entity.uid,
      seedConfirmed: entity.seedConfirmed,
      createdAt: entity.createdAt,
    );
  }

  IdentityModel copyWith({
    String? publicKey,
    String? uid,
    bool? seedConfirmed,
    DateTime? createdAt,
  }) {
    return IdentityModel(
      publicKey: publicKey ?? this.publicKey,
      uid: uid ?? this.uid,
      seedConfirmed: seedConfirmed ?? this.seedConfirmed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
