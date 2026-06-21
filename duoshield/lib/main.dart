import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/constants/app_colors.dart';

// Global background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  developer.log('Background FCM message received: ${message.messageId}');
}

// Initialize local notifications plugin globally for background access
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Local notification channel configuration
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'duoshield_messages',
  'DuoShield Messages',
  description: 'Secure message notifications for DuoShield',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

Future<void> main() async {
  // FIX #1: Was ensureInstance() — correct method is ensureInitialized()
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    developer.log('Firebase initialized successfully');
  } catch (e) {
    developer.log('Firebase initialization failed: $e');
    // Continue anyway - app should work in offline mode
  }

  // Set up background message handler for FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Hive local database
  await Hive.initFlutter();

  // FIX: Removed the misleading TODO and commented-out adapter registrations.
  // Models in this project use toJson()/fromJson() with raw Box<Map> — they do
  // NOT have @HiveType/@HiveField annotations, so no TypeAdapters are generated
  // or needed. Running build_runner would not produce adapter files for these
  // classes, and the previous comment implied you had to do so.
  _registerHiveAdapters();

  // Open required Hive boxes
  await _openHiveBoxes();

  // Initialize local notifications
  await _initializeLocalNotifications();

  // Run the app with Riverpod ProviderScope
  runApp(
    const ProviderScope(
      child: DuoShieldApp(),
    ),
  );
}

/// No-op: models use raw Map boxes (Box<String> / Box<Map>) with toJson() /
/// fromJson(). There are no generated Hive TypeAdapters for this project.
void _registerHiveAdapters() {}

Future<void> _openHiveBoxes() async {
  try {
    await Hive.openBox<String>('duoshield_identity');
    await Hive.openBox<Map>('duoshield_contacts');
    await Hive.openBox<Map>('duoshield_messages');
    await Hive.openBox<Map>('duoshield_conversations');
    await Hive.openBox<Map>('duoshield_settings');
    await Hive.openBox<Map>('duoshield_signal_sessions');
    await Hive.openBox<String>('duoshield_plaintext_cache');
    developer.log('All Hive boxes opened successfully');
  } catch (e) {
    developer.log('Error opening Hive boxes: $e');
    rethrow;
  }
}

Future<void> _initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: _onNotificationTapped,
    onDidReceiveBackgroundNotificationResponse:
        _onBackgroundNotificationTapped,
  );

  // Create Android notification channel
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(channel);

  developer.log('Local notifications initialized');
}

void _onNotificationTapped(NotificationResponse response) {
  developer.log('Notification tapped: ${response.payload}');
}

@pragma('vm:entry-point')
void _onBackgroundNotificationTapped(NotificationResponse response) {
  developer.log('Background notification tapped: ${response.payload}');
}
