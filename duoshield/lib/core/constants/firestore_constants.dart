/// Firestore collection and field name constants for DuoShield.
/// Centralizes all Firestore schema references to prevent typos and enable refactoring.
class FirestoreConstants {
  // Prevent instantiation
  const FirestoreConstants._();

  // Collection names
  static const String usersCollection = 'users';
  static const String conversationsCollection = 'conversations';
  static const String messagesSubcollection = 'messages';

  // User document fields
  static const String publicKey = 'publicKey';
  static const String fcmToken = 'fcmToken';
  static const String preKeyBundle = 'preKeyBundle';
  static const String createdAt = 'createdAt';

  // Pre-key bundle fields
  static const String identityKey = 'identityKey';
  static const String signedPreKey = 'signedPreKey';
  static const String signedPreKeyId = 'keyId';
  static const String signedPreKeyPublic = 'publicKey';
  static const String signedPreKeySignature = 'signature';
  static const String oneTimePreKeys = 'oneTimePreKeys';
  static const String oneTimePreKeyId = 'keyId';
  static const String oneTimePreKeyPublic = 'publicKey';

  // Conversation document fields
  static const String participants = 'participants';
  static const String lastMessageAt = 'lastMessageAt';

  // Message document fields
  static const String senderId = 'senderId';
  static const String ciphertext = 'ciphertext';
  static const String timestamp = 'timestamp';
  static const String status = 'status';
  static const String messageType = 'messageType';

  // Message status values
  static const String statusSending = 'sending';
  static const String statusSent = 'sent';
  static const String statusDelivered = 'delivered';
  static const String statusRead = 'read';

  // Message type values
  static const String messageTypeText = 'text';

  // Local Hive storage keys (not Firestore, but related)
  static const String hiveIdentityBox = 'duoshield_identity';
  static const String hiveContactsBox = 'duoshield_contacts';
  static const String hiveMessagesBox = 'duoshield_messages';
  static const String hiveConversationsBox = 'duoshield_conversations';
  static const String hiveSettingsBox = 'duoshield_settings';
  static const String hiveSignalSessionsBox = 'duoshield_signal_sessions';
  static const String hivePlaintextCacheBox = 'duoshield_plaintext_cache';

  // Secure Storage keys
  static const String securePrivateKey = 'duoshield_private_key';
  static const String securePinHash = 'duoshield_pin_hash';
  static const String secureDuressPinHash = 'duoshield_duress_pin_hash';
  static const String secureFailedAttempts = 'duoshield_failed_attempts';
  static const String secureLockUntil = 'duoshield_lock_until';

  // Identity storage
  static const String publicKeyHiveKey = 'duoshield_public_key';
  static const String uidHiveKey = 'duoshield_uid';
  static const String seedConfirmedKey = 'duoshield_seed_confirmed';

  // Settings
  static const String pinSetKey = 'duoshield_pin_set';
  static const String duressPinSetKey = 'duoshield_duress_pin_set';
  static const String darkModeKey = 'duoshield_dark_mode';

  // FCM
  static const String fcmMessageChannelId = 'duoshield_messages';
  static const String fcmMessageChannelName = 'DuoShield Messages';
  static const String fcmConversationIdKey = 'conversationId';

  /// Build a Firestore user document path
  static String userPath(String uid) => '$usersCollection/$uid';

  /// Build a Firestore conversation document path
  static String conversationPath(String conversationId) =>
      '$conversationsCollection/$conversationId';

  /// Build a Firestore messages subcollection path
  static String messagesPath(String conversationId) =>
      '$conversationsCollection/$conversationId/$messagesSubcollection';

  /// Build a Firestore message document path
  static String messagePath(String conversationId, String messageId) =>
      '$conversationsCollection/$conversationId/$messagesSubcollection/$messageId';
}
