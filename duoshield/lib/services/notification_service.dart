import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/errors/exceptions.dart';
import 'firebase_service.dart';

/// Notification service for handling FCM push notifications and local notifications.
///
/// Security:
/// - Notification content is always "New message" - never includes sender or content
/// - FCM data payload contains only conversationId for routing
/// - Foreground notifications shown via flutter_local_notifications
class NotificationService {
  final FirebaseService _firebaseService;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  // Singleton instance
  static NotificationService? _instance;

  factory NotificationService({
    FirebaseService? firebaseService,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) {
    _instance ??= NotificationService._internal(
      firebaseService: firebaseService,
      messaging: messaging,
      localNotifications: localNotifications,
    );
    return _instance!;
  }

  NotificationService._internal({
    FirebaseService? firebaseService,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  // FIX: Was `Stream.empty().asBroadcastStream()` which is immutable and can
  // never emit events. Replaced with a real broadcast StreamController so that
  // _onNotificationTap can add events and callers (navigator) can subscribe.
  final _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of notification tap events, each carrying the conversation data.
  Stream<Map<String, dynamic>> get notificationTapStream =>
      _notificationTapController.stream;

  /// Initialize the notification service.
  /// Must be called after Firebase is initialized.
  Future<void> initialize() async {
    try {
      // Request notification permissions
      await _requestPermissions();

      // Set foreground notification presentation options (iOS)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Subscribe to FCM topics or configure token refresh
      await _configureFcmToken();

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listen for notification taps when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen(
        _handleBackgroundMessageTap,
      );

      // Check if app was opened from a terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleTerminatedMessageTap(initialMessage);
      }

      developer.log('Notification service initialized');
    } catch (e, stackTrace) {
      developer.log('Failed to initialize notification service: $e');
      throw NotificationException(
        'Failed to initialize notification service',
        code: 'NOTIFICATION_INIT_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Request notification permissions from the user.
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          criticalAlert: false,
        );
        developer.log(
          'iOS notification authorization status: ${settings.authorizationStatus}',
        );
      } else {
        // Android 13+ — request POST_NOTIFICATIONS at runtime
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final enabled =
            await androidPlugin?.areNotificationsEnabled() ?? false;
        if (!enabled) {
          await androidPlugin?.requestNotificationsPermission();
        }
      }
    } catch (e, stackTrace) {
      developer.log('Failed to request notification permissions: $e');
      throw NotificationException(
        'Failed to request notification permissions',
        code: 'PERMISSION_REQUEST_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Configure FCM token and token refresh handling.
  Future<void> _configureFcmToken() async {
    try {
      // Get initial token
      final token = await _messaging.getToken();
      if (token != null && _firebaseService.isAuthenticated) {
        await _firebaseService.updateFcmToken(
          _firebaseService.currentUid,
          token,
        );
      }

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen(
        (newToken) async {
          try {
            if (_firebaseService.isAuthenticated) {
              await _firebaseService.updateFcmToken(
                _firebaseService.currentUid,
                newToken,
              );
            }
            developer.log('FCM token refreshed');
          } catch (e) {
            developer.log('Failed to update refreshed FCM token: $e');
          }
        },
        onError: (e) {
          developer.log('FCM token refresh error: $e');
        },
      );
    } catch (e, stackTrace) {
      developer.log('Failed to configure FCM token: $e');
      throw NotificationException(
        'Failed to configure FCM token',
        code: 'FCM_CONFIG_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Handle foreground FCM messages by showing local notification.
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      developer.log('Foreground FCM message received');

      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        _showLocalNotification(
          title: notification.title ?? AppStrings.appName,
          body: notification.body ?? AppStrings.newMessage,
          payload: data[FirestoreConstants.fcmConversationIdKey],
        );
      } else {
        // Data-only message
        _showLocalNotification(
          title: AppStrings.appName,
          body: AppStrings.newMessage,
          payload: data[FirestoreConstants.fcmConversationIdKey],
        );
      }
    } catch (e) {
      developer.log('Error handling foreground message: $e');
    }
  }

  /// Show a local notification.
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'duoshield_messages',
        'DuoShield Messages',
        channelDescription: 'Secure message notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        color: AppColors.accent,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // FIX: Was `DateTime.now().millisecond` (range 0–999) which caused
      // frequent ID collisions and silent notification drops. Use lower 17 bits
      // of millisecondsSinceEpoch for a collision-resistant unique int ID.
      final notificationId =
          DateTime.now().millisecondsSinceEpoch & 0x1FFFF;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      developer.log('Failed to show local notification: $e');
    }
  }

  /// Handle notification tap when app was in background.
  void _handleBackgroundMessageTap(RemoteMessage message) {
    try {
      developer.log('Background notification tapped');
      final conversationId =
          message.data[FirestoreConstants.fcmConversationIdKey];
      if (conversationId != null) {
        _onNotificationTap({'conversationId': conversationId});
      }
    } catch (e) {
      developer.log('Error handling background notification tap: $e');
    }
  }

  /// Handle notification tap when app was terminated.
  void _handleTerminatedMessageTap(RemoteMessage message) {
    try {
      developer.log('Terminated state notification tapped');
      final conversationId =
          message.data[FirestoreConstants.fcmConversationIdKey];
      if (conversationId != null) {
        _onNotificationTap({'conversationId': conversationId});
      }
    } catch (e) {
      developer.log('Error handling terminated notification tap: $e');
    }
  }

  /// Emit a notification tap event on the broadcast stream so the navigator
  /// can open the correct conversation. Guarded against closed controller.
  void _onNotificationTap(Map<String, dynamic> data) {
    developer.log('Notification tapped with data: $data');
    if (!_notificationTapController.isClosed) {
      _notificationTapController.add(data);
    }
  }

  /// Subscribe to a topic for testing or group features.
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      developer.log('Subscribed to topic: $topic');
    } catch (e, stackTrace) {
      throw NotificationException(
        'Failed to subscribe to topic',
        code: 'TOPIC_SUBSCRIBE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Unsubscribe from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      developer.log('Unsubscribed from topic: $topic');
    } catch (e, stackTrace) {
      throw NotificationException(
        'Failed to unsubscribe from topic',
        code: 'TOPIC_UNSUBSCRIBE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete the FCM token.
  Future<void> deleteFcmToken() async {
    try {
      await _messaging.deleteToken();
      developer.log('FCM token deleted');
    } catch (e, stackTrace) {
      throw NotificationException(
        'Failed to delete FCM token',
        code: 'FCM_TOKEN_DELETE_FAILED',
        stackTrace: stackTrace,
      );
    }
  }

  /// Release resources. Call when the service is no longer needed.
  void dispose() {
    _notificationTapController.close();
  }
}
