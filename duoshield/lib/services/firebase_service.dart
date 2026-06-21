import 'dart:developer' as developer;

// FIX #2: Added 'as firebase_auth' alias so FirebaseAuthException can be
// referenced with the prefix, avoiding the name clash with our custom
// FirebaseException in exceptions.dart.
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/constants/firestore_constants.dart';
import '../core/errors/exceptions.dart';

/// Firebase service that centralizes all Firebase Auth and Firestore operations.
/// Handles anonymous authentication, document CRUD, and real-time listeners.
///
/// Security:
/// - All writes are validated against Firestore Security Rules
/// - Private key NEVER touches this service
/// - Only public key and encrypted data are transmitted
class FirebaseService {
  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  FirebaseService({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  })  : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  // ==================== AUTH ====================

  /// Sign in anonymously to Firebase.
  /// Returns the Firebase User object.
  Future<firebase_auth.User> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw FirebaseException(
          'Anonymous sign-in returned null user',
          code: 'NULL_USER',
        );
      }
      developer.log('Anonymous auth successful: ${user.uid}');
      return user;
    } on FirebaseException {
      rethrow;
    } on firebase_auth.FirebaseAuthException catch (e, stackTrace) {
      developer.log('Firebase Auth error: ${e.code}: ${e.message}');
      throw FirebaseException(
        'Authentication failed: ${e.message}',
        code: e.code,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      developer.log('Anonymous auth failed: $e');
      throw FirebaseException(
        'Failed to sign in anonymously',
        code: 'AUTH_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the current Firebase user.
  /// Returns null if not authenticated.
  firebase_auth.User? get currentUser => _auth.currentUser;

  /// Get the current user's UID.
  /// Throws [UnauthorizedException] if not authenticated.
  String get currentUid {
    final user = _auth.currentUser;
    if (user == null) {
      throw UnauthorizedException(
        'No authenticated user',
        code: 'NOT_AUTHENTICATED',
      );
    }
    return user.uid;
  }

  /// Check if a user is currently authenticated.
  bool get isAuthenticated => _auth.currentUser != null;

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      developer.log('User signed out');
    } catch (e, stackTrace) {
      developer.log('Sign out failed: $e');
      throw FirebaseException(
        'Failed to sign out',
        code: 'SIGN_OUT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get authentication state stream.
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  // ==================== FCM TOKENS ====================

  /// Get the FCM token for push notifications.
  Future<String?> getFcmToken() async {
    try {
      final token = await _messaging.getToken();
      developer.log('FCM token retrieved');
      return token;
    } catch (e, stackTrace) {
      developer.log('Failed to get FCM token: $e');
      throw NotificationException(
        'Failed to get FCM token',
        code: 'FCM_TOKEN_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Listen for FCM token refreshes.
  Stream<String> get onFcmTokenRefresh => _messaging.onTokenRefresh;

  // ==================== USER DOCUMENTS ====================

  /// Create or update the user document in Firestore.
  /// Stores public key, FCM token, and pre-key bundle.
  ///
  /// FIX: The original used `set(data, SetOptions(merge: true))` which included
  /// `createdAt: FieldValue.serverTimestamp()` in every call. With merge:true,
  /// Firestore writes ALL supplied fields — so `createdAt` was overwritten on
  /// every login/re-publish. Fixed by reading the document first:
  /// - New document → full set() including createdAt (server timestamp).
  /// - Existing document → update() touching only the mutable fields, leaving
  ///   createdAt untouched.
  Future<void> setUserDocument({
    required String uid,
    required String publicKey,
    required String? fcmToken,
    required Map<String, dynamic>? preKeyBundle,
  }) async {
    try {
      final docRef = _firestore
          .collection(FirestoreConstants.usersCollection)
          .doc(uid);

      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        // New document: write createdAt exactly once
        final data = <String, dynamic>{
          FirestoreConstants.publicKey: publicKey,
          FirestoreConstants.createdAt: FieldValue.serverTimestamp(),
        };
        if (fcmToken != null) data[FirestoreConstants.fcmToken] = fcmToken;
        if (preKeyBundle != null) {
          data[FirestoreConstants.preKeyBundle] = preKeyBundle;
        }
        await docRef.set(data);
      } else {
        // Existing document: update mutable fields only — createdAt is preserved
        final updates = <String, dynamic>{
          FirestoreConstants.publicKey: publicKey,
        };
        if (fcmToken != null) updates[FirestoreConstants.fcmToken] = fcmToken;
        if (preKeyBundle != null) {
          updates[FirestoreConstants.preKeyBundle] = preKeyBundle;
        }
        await docRef.update(updates);
      }

      developer.log('User document set: $uid');
    } on FirebaseException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to set user document: $e');
      throw FirebaseException(
        'Failed to store user data',
        code: 'USER_DOCUMENT_SET_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get a user document from Firestore.
  /// Returns null if the document doesn't exist.
  Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    try {
      final doc = await _firestore
          .collection(FirestoreConstants.usersCollection)
          .doc(uid)
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e, stackTrace) {
      developer.log('Failed to get user document: $e');
      throw FirebaseException(
        'Failed to retrieve user data',
        code: 'USER_DOCUMENT_GET_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get a user's public key from Firestore.
  Future<String?> getUserPublicKey(String uid) async {
    try {
      final doc = await getUserDocument(uid);
      return doc?[FirestoreConstants.publicKey] as String?;
    } catch (e, stackTrace) {
      throw FirebaseException(
        'Failed to retrieve user public key',
        code: 'PUBLIC_KEY_GET_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get a user's pre-key bundle from Firestore.
  Future<Map<String, dynamic>?> getUserPreKeyBundle(String uid) async {
    try {
      final doc = await getUserDocument(uid);
      final bundle = doc?[FirestoreConstants.preKeyBundle];
      if (bundle == null) return null;
      return Map<String, dynamic>.from(bundle as Map);
    } catch (e, stackTrace) {
      throw FirebaseException(
        'Failed to retrieve pre-key bundle',
        code: 'PRE_KEY_BUNDLE_GET_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Update FCM token in user document.
  Future<void> updateFcmToken(String uid, String fcmToken) async {
    try {
      await _firestore
          .collection(FirestoreConstants.usersCollection)
          .doc(uid)
          .update({FirestoreConstants.fcmToken: fcmToken});
      developer.log('FCM token updated for user: $uid');
    } catch (e, stackTrace) {
      developer.log('Failed to update FCM token: $e');
      throw FirebaseException(
        'Failed to update FCM token',
        code: 'FCM_TOKEN_UPDATE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== CONVERSATIONS ====================

  /// Create or update a conversation document.
  Future<void> setConversationDocument({
    required String conversationId,
    required List<String> participants,
  }) async {
    try {
      await _firestore
          .collection(FirestoreConstants.conversationsCollection)
          .doc(conversationId)
          .set({
        FirestoreConstants.participants: participants,
        FirestoreConstants.lastMessageAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      developer.log('Conversation document set: $conversationId');
    } catch (e, stackTrace) {
      developer.log('Failed to set conversation: $e');
      throw FirebaseException(
        'Failed to create conversation',
        code: 'CONVERSATION_SET_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get conversation document.
  Future<Map<String, dynamic>?> getConversationDocument(
    String conversationId,
  ) async {
    try {
      final doc = await _firestore
          .collection(FirestoreConstants.conversationsCollection)
          .doc(conversationId)
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e, stackTrace) {
      developer.log('Failed to get conversation: $e');
      throw FirebaseException(
        'Failed to retrieve conversation',
        code: 'CONVERSATION_GET_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Listen to conversations where the user is a participant.
  Stream<List<Map<String, dynamic>>> listenToConversations(String uid) {
    try {
      return _firestore
          .collection(FirestoreConstants.conversationsCollection)
          .where(FirestoreConstants.participants, arrayContains: uid)
          .orderBy(FirestoreConstants.lastMessageAt, descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e, stackTrace) {
      developer.log('Failed to listen to conversations: $e');
      throw FirebaseException(
        'Failed to listen to conversations',
        code: 'CONVERSATIONS_LISTEN_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== MESSAGES ====================

  /// Send an encrypted message to Firestore.
  /// Stores only ciphertext - plaintext never touches the network.
  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String ciphertext,
    required String messageType,
  }) async {
    try {
      final messageData = <String, dynamic>{
        FirestoreConstants.senderId: senderId,
        FirestoreConstants.ciphertext: ciphertext,
        FirestoreConstants.timestamp: FieldValue.serverTimestamp(),
        FirestoreConstants.status: FirestoreConstants.statusSent,
        FirestoreConstants.messageType: messageType,
      };

      // Write message
      await _firestore
          .collection(FirestoreConstants.conversationsCollection)
          .doc(conversationId)
          .collection(FirestoreConstants.messagesSubcollection)
          .doc(messageId)
          .set(messageData);

      // Update conversation last message timestamp
      await _firestore
          .collection(FirestoreConstants.conversationsCollection)
          .doc(conversationId)
          .update({
        FirestoreConstants.lastMessageAt: FieldValue.serverTimestamp(),
      });

      developer.log('Message sent: $messageId');
    } catch (e, stackTrace) {
      developer.log('Failed to send message: $e');
      throw FirebaseException(
        'Failed to send message',
        code: 'MESSAGE_SEND_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Listen to messages in a conversation.
  Stream<List<Map<String, dynamic>>> listenToMessages(
    String conversationId,
  ) {
    try {
      return _firestore
          .collection(FirestoreConstants.conversationsCollection)
          .doc(conversationId)
          .collection(FirestoreConstants.messagesSubcollection)
          .orderBy(FirestoreConstants.timestamp, descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e, stackTrace) {
      developer.log('Failed to listen to messages: $e');
      throw FirebaseException(
        'Failed to listen to messages',
        code: 'MESSAGES_LISTEN_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Update message status (delivered/read).
  Future<void> updateMessageStatus({
    required String conversationId,
    required String messageId,
    required String status,
  }) async {
    try {
      await _firestore
          .collection(FirestoreConstants.conversationsCollection)
          .doc(conversationId)
          .collection(FirestoreConstants.messagesSubcollection)
          .doc(messageId)
          .update({FirestoreConstants.status: status});

      developer.log('Message status updated: $messageId -> $status');
    } catch (e, stackTrace) {
      developer.log('Failed to update message status: $e');
      throw FirebaseException(
        'Failed to update message status',
        code: 'STATUS_UPDATE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== CONTACTS BACKUP ====================

  /// Store encrypted contacts backup in Firestore.
  Future<void> storeContactsBackup({
    required String uid,
    required String encryptedContacts,
  }) async {
    try {
      await _firestore
          .collection(FirestoreConstants.usersCollection)
          .doc(uid)
          .update({'encryptedContacts': encryptedContacts});
      developer.log('Contacts backup stored');
    } catch (e, stackTrace) {
      developer.log('Failed to store contacts backup: $e');
      throw FirebaseException(
        'Failed to store contacts backup',
        code: 'CONTACTS_BACKUP_STORE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Get encrypted contacts backup from Firestore.
  Future<String?> getContactsBackup(String uid) async {
    try {
      final doc = await getUserDocument(uid);
      return doc?['encryptedContacts'] as String?;
    } catch (e, stackTrace) {
      developer.log('Failed to get contacts backup: $e');
      throw FirebaseException(
        'Failed to retrieve contacts backup',
        code: 'CONTACTS_BACKUP_GET_FAILED',
        stackTrace: stackTrace,
      );
    }
  }
}
