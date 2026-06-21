import 'dart:developer' as developer;

import '../../../../core/errors/exceptions.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/signal_session_manager.dart';

/// Remote data source for identity Firebase operations.
/// Handles publishing identity data to Firestore and FCM token management.
class IdentityRemoteDatasource {
  final FirebaseService _firebaseService;
  final NotificationService _notificationService;
  final SignalSessionManager _signalManager;

  IdentityRemoteDatasource({
    required FirebaseService firebaseService,
    required NotificationService notificationService,
    required SignalSessionManager signalManager,
  })  : _firebaseService = firebaseService,
        _notificationService = notificationService,
        _signalManager = signalManager;

  /// Sign in anonymously and publish identity to Firestore.
  /// Stores public key, FCM token, and pre-key bundle.
  Future<String> publishIdentity(String publicKey) async {
    try {
      // Sign in anonymously
      final user = await _firebaseService.signInAnonymously();
      final uid = user.uid;

      // Get FCM token
      String? fcmToken;
      try {
        fcmToken = await _firebaseService.getFcmToken();
      } catch (e) {
        developer.log('FCM token not available: $e');
        // Continue without FCM - messages still work via Firestore
      }

      // Generate and publish pre-key bundle
      Map<String, dynamic>? preKeyBundle;
      try {
        preKeyBundle = await _signalManager.generatePreKeyBundle();
      } catch (e) {
        developer.log('Pre-key bundle generation failed: $e');
        // Continue without pre-key bundle
      }

      // Store user document in Firestore
      await _firebaseService.setUserDocument(
        uid: uid,
        publicKey: publicKey,
        fcmToken: fcmToken,
        preKeyBundle: preKeyBundle,
      );

      developer.log('Identity published to Firestore: $uid');
      return uid;
    } on FirebaseException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Failed to publish identity: $e');
      throw FirebaseException(
        'Failed to publish identity to server',
        code: 'PUBLISH_IDENTITY_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Update FCM token in Firestore.
  Future<void> updateFcmToken(String uid) async {
    try {
      final fcmToken = await _firebaseService.getFcmToken();
      if (fcmToken != null) {
        await _firebaseService.updateFcmToken(uid, fcmToken);
        developer.log('FCM token updated in Firestore');
      }
    } catch (e) {
      developer.log('Failed to update FCM token: $e');
      // Non-critical error
    }
  }

  /// Sign out from Firebase.
  Future<void> signOut() async {
    try {
      await _firebaseService.signOut();
      developer.log('Signed out from Firebase');
    } catch (e, stackTrace) {
      throw FirebaseException(
        'Failed to sign out from Firebase',
        code: 'SIGN_OUT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Check if user is authenticated with Firebase.
  bool get isAuthenticated => _firebaseService.isAuthenticated;

  /// Get the current Firebase UID.
  String? get currentUid =>
      _firebaseService.isAuthenticated ? _firebaseService.currentUid : null;
}
