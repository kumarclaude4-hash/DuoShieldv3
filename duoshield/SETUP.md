# DuoShield - Setup Guide

Complete step-by-step instructions to build, configure, and deploy the DuoShield secure messaging application.

---

## Bug Fixes Applied (v1.0.2)

### Pass 1 — Critical / Serious / Medium (13 fixes)

| # | File | Issue Fixed |
|---|------|-------------|
| 1 | `lib/main.dart` | `ensureInstance()` → `ensureInitialized()` (compile error) |
| 2 | `lib/services/firebase_service.dart` | Added `as firebase_auth` import alias; fixed `FirebaseAuthException` catch clause (compile error) |
| 3 | `pubspec.yaml` + `assets/` | Created placeholder PNG files so declared asset dirs are non-empty (build failure) |
| 4 | `lib/services/signal_session_manager.dart` | Signal API: `ECPrivateKey(clamped)` + `Curve.generatePublicKey()` replaces non-existent `Curve25519.*` (runtime crash) |
| 5 | `lib/services/signal_session_manager.dart` | `_persistCipherState()` now saves ratchet state to Hive after every step (was empty placeholder — caused decrypt failures on restart) |
| 6 | `lib/services/encryption_service.dart` | Replaced XOR placeholder with real **AES-256-GCM** via PointyCastle |
| 7 | `lib/features/settings/presentation/providers/lock_provider.dart` | Removed unused `attemptsResult` variable (lint warning) |
| 8 | `lib/app.dart` | Removed nested `MaterialApp` inside `_AppLockOverlay` — now bare `Scaffold` (broke theme/nav context) |
| 9 | `lib/app.dart` | `withOpacity()` → `withAlpha()` (deprecated in Flutter 3.27+) |
| 10 | `lib/services/storage_service.dart` | RSA padding: `PKCS1Padding` → `OAEPwithSHA_256andMGF1Padding` (security vulnerability) |
| 11 | `lib/core/utils/key_utils.dart` | `crypto.SecureRandom()` → `Random.secure()` from `dart:math` (runtime crash) |
| 12 | `lib/core/utils/key_utils.dart` | `_derivePublicKey()` fixed: was calling `getMasterKeyFromSeed(privateKey)` (wrong — returned chain code bytes, not the public key); now uses `getPublicKey(privateKey, false)` |
| 13 | `lib/services/firebase_service.dart` | `createdAt: FieldValue.serverTimestamp()` in `set(merge:true)` was overwriting the original creation date on every re-login; fixed by reading the doc first and using `set()` for creation vs `update()` for updates |

### Pass 2 — Additional bugs found in audit (8 fixes)

| # | File | Issue Fixed |
|---|------|-------------|
| 14 | `lib/features/messaging/data/repositories/messaging_repository_impl.dart` | `myUidResult` declared but referenced as `myUid` on the very next line — **undefined variable / runtime crash** every time a message was sent |
| 15 | `lib/features/messaging/data/repositories/messaging_repository_impl.dart` | Removed unused `rxdart` import (not in pubspec; would cause a compile error) |
| 16 | `lib/services/notification_service.dart` | `Stream.empty().asBroadcastStream()` assigned to `_notificationTapController` — immutable stream with no `add()` method; notification tap events were silently dropped. Replaced with `StreamController<Map<String,dynamic>>.broadcast()` and wired `_onNotificationTap` to emit events |
| 17 | `lib/services/notification_service.dart` | `DateTime.now().millisecond` (range 0–999) as notification ID caused frequent collisions and silent drops; replaced with `DateTime.now().millisecondsSinceEpoch & 0x1FFFF` |
| 18 | `lib/features/messaging/data/models/message_model.dart` | `fromFirestore()` only checked `if (ts is DateTime)` — Firestore SDK returns `cloud_firestore.Timestamp` objects, not `DateTime`; every message timestamp fell back to `DateTime.now()`. Added `Timestamp` branch |
| 19 | `lib/features/messaging/data/models/conversation_model.dart` | Same Firestore `Timestamp` bug as #18 — `lastMessageAt` was always null, breaking conversation sort order |
| 20 | `lib/app.dart` | `AppLifecycleState.inactive` and `hidden` were both starting the lock timer. On iOS, `inactive` fires for every system overlay (notification shade, Control Centre, incoming call). Only `paused` reliably means the app is backgrounded; moved `inactive`/`hidden` to no-op cases |
| 21 | `lib/main.dart` | Removed misleading `build_runner` TODO and commented-out adapter registrations from `_registerHiveAdapters()`. Models use `toJson()`/`fromJson()` with raw `Box<Map>` — no `@HiveType`/`@HiveField` annotations exist, so `build_runner` would not produce TypeAdapter files |

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Firebase Project Setup](#2-firebase-project-setup)
3. [Flutter App Configuration](#3-flutter-app-configuration)
4. [Build and Code Generation](#4-build-and-code-generation)
5. [Deploy Firebase Rules](#5-deploy-firebase-rules)
6. [Deploy Cloud Functions](#6-deploy-cloud-functions)
7. [Platform-Specific Setup](#7-platform-specific-setup)
8. [First Run Checklist](#8-first-run-checklist)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites

Before starting, ensure you have the following installed:

- **Flutter SDK** >= 3.22.0, **Dart SDK** >= 3.4.0
  ```bash
  flutter doctor
  ```
- **Node.js** >= 18.0.0 (for Cloud Functions)
  ```bash
  node --version
  ```
- **Firebase CLI** (for deployment)
  ```bash
  npm install -g firebase-tools
  firebase login
  ```
- **Android Studio** or **Xcode** (for platform builds)
- A **Firebase account** (free tier is sufficient)

---

## 2. Firebase Project Setup

### Step 2.1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Enter project name: `duoshield-messaging` (or your preferred name)
4. Disable Google Analytics (not needed for this app)
5. Click **"Create project"**
6. Note your **Project ID** (you'll need it later)

### Step 2.2: Enable Anonymous Authentication

1. In Firebase Console, go to **Build > Authentication**
2. Click **"Get started"**
3. Go to the **"Sign-in method"** tab
4. Click **"Anonymous"** in the providers list
5. Toggle **"Enable"** to ON
6. Click **"Save"**

### Step 2.3: Enable Cloud Firestore

1. Go to **Build > Firestore Database**
2. Click **"Create database"**
3. Select **"Start in production mode"**
4. Choose your region (recommend `us-central1`)
5. Click **"Create"**
6. After creation, go to the **"Rules"** tab
7. Replace the default rules with the content from `firestore.rules` in this project
8. Click **"Publish"**

### Step 2.4: Enable Firebase Cloud Messaging (FCM)

1. Go to **Project settings** (gear icon)
2. Go to the **"Cloud Messaging"** tab
3. Note your **Server key** (used for Cloud Functions)
4. No additional configuration needed for FCM v1

### Step 2.5: Register Your Apps

#### Android

1. In Project settings, click the **Android icon** to add an Android app
2. Package name: `com.duoshield.app` (or your chosen package name)
3. App nickname: `DuoShield Android`
4. Click **"Register app"**
5. Download `google-services.json`
6. Place it in: `android/app/google-services.json`

#### iOS

1. In Project settings, click the **iOS icon** to add an iOS app
2. Bundle ID: `com.duoshield.app` (must match your iOS bundle ID)
3. App nickname: `DuoShield iOS`
4. Click **"Register app"**
5. Download `GoogleService-Info.plist`
6. Place it in: `ios/Runner/GoogleService-Info.plist`

---

## 3. Flutter App Configuration

### Step 3.1: Install Dependencies

```bash
flutter pub get
```

### Step 3.2: Generate Code

Run the build runner to generate Hive adapters and Riverpod providers:

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Note:** This generates `.g.dart` files for Hive type adapters and Riverpod providers.

### Step 3.3: Configure Firebase in Flutter

#### Android Configuration

The `android/app/build.gradle` should already include:

```gradle
plugins {
    id 'com.android.application'
    id 'kotlin-android'
    id 'com.google.gms.google-services'  // Add this
}
```

The `android/build.gradle` should include:

```gradle
plugins {
    // ...
    id 'com.google.gms.google-services' version '4.4.1' apply false
}
```

#### iOS Configuration

Run in the `ios` directory:

```bash
cd ios
pod install --repo-update
```

---

## 4. Build and Code Generation

### Step 4.1: Generate Hive Adapters

After modifying any Hive model, regenerate adapters:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 4.2: Run Tests

```bash
flutter test
```

All 60+ tests should pass, covering:
- Key derivation and validation
- Encryption/decryption roundtrips
- PIN hashing and verification
- Duress PIN wipe logic
- Conversation ID generation

### Step 4.3: Build the App

#### Debug Build

```bash
flutter run
```

#### Release Build - Android

```bash
flutter build apk --release
# Or for app bundle:
flutter build appbundle --release
```

#### Release Build - iOS

```bash
flutter build ios --release
```

---

## 5. Deploy Firebase Rules

### Step 5.1: Initialize Firebase (if not already done)

```bash
firebase init firestore
```

Select your project and use the existing `firestore.rules` file.

### Step 5.2: Deploy Rules

```bash
firebase deploy --only firestore:rules
```

Verify the rules are deployed in Firebase Console > Firestore Database > Rules.

---

## 6. Deploy Cloud Functions

### Step 6.1: Navigate to Functions Directory

```bash
cd functions
```

### Step 6.2: Install Function Dependencies

```bash
npm install
```

### Step 6.3: Deploy Functions

```bash
cd ..  # Return to project root
firebase deploy --only functions
```

### Step 6.4: Verify Deployment

In Firebase Console > Functions, you should see:
- `sendMessageNotification` (active)
- `userPresenceOnAuth` (if enabled)

Check the **Logs** tab for any deployment errors.

---

## 7. Platform-Specific Setup

### Android

#### Minimum SDK Version

Ensure `android/app/build.gradle` has:

```gradle
android {
    defaultConfig {
        minSdkVersion 23  // Required for flutter_secure_storage
        targetSdkVersion 34
    }
}
```

#### ProGuard Rules (Release Build)

Add to `android/app/proguard-rules.pro`:

```proguard
# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep BouncyCastle (used by some crypto packages)
-keep class org.bouncycastle.** { *; }
```

#### keystore.properties (Optional - for signing)

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=<path-to-keystore>
```

### iOS

#### Minimum iOS Version

In `ios/Podfile`, ensure:

```ruby
platform :ios, '13.0'
```

#### Keychain Sharing (Required for flutter_secure_storage)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** project
3. Go to **Signing & Capabilities**
4. Click **"+ Capability"**
5. Add **"Keychain Sharing"**
6. Add a keychain group: `$(AppIdentifierPrefix)com.duoshield.app`

#### NSAppTransportSecurity

In `ios/Runner/Info.plist`, Firebase should already handle this, but ensure:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

#### Local Network Privacy (iOS 14+)

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs to access local network for development</string>
<key>NSBonjourServices</key>
<array>
    <string>_dartobservatory._tcp</string>
</array>
```

---

## 8. First Run Checklist

### Before First Launch

- [ ] Firebase project created
- [ ] Anonymous Authentication enabled
- [ ] Firestore Database created with rules deployed
- [ ] FCM enabled
- [ ] `google-services.json` placed in `android/app/`
- [ ] `GoogleService-Info.plist` placed in `ios/Runner/`
- [ ] `flutter pub get` completed successfully
- [ ] `dart run build_runner build` completed
- [ ] All tests pass (`flutter test`)
- [ ] Firebase Functions deployed
- [ ] Android: minSdkVersion >= 23
- [ ] iOS: platform >= 13.0, Keychain Sharing enabled

### First Launch Flow

1. **Onboarding Screen**
   - App shows welcome screen with feature highlights
   - User taps "Get Started"
   - App generates 24-word BIP39 seed phrase
   - User writes down seed phrase
   - User confirms 3 random words from the phrase
   - Identity is created and stored securely

2. **PIN Setup**
   - User sets a 6-digit PIN
   - User confirms the PIN
   - User optionally sets a duress PIN (different from normal)
   - Duress PIN warning is shown

3. **Firebase Publish**
   - App signs in anonymously to Firebase
   - Public key and pre-key bundle are published to Firestore
   - FCM token is registered

4. **Using the App**
   - Add contacts via QR scan or manual public key entry
   - Start secure conversations
   - Messages are encrypted with Signal Protocol before sending
   - App locks after 30 seconds in background
   - Duress PIN silently wipes all local data if used

### Security Verification

- [ ] Seed phrase is shown exactly once
- [ ] Private key is only in secure storage (never logged or transmitted)
- [ ] Messages are encrypted before Firestore write
- [ ] Notification contains no message content
- [ ] PIN hashing uses bcrypt with 12 rounds
- [ ] Duress PIN triggers silent wipe (test in safe environment)
- [ ] Logout wipes local data but preserves Firestore data

---

## 9. Troubleshooting

### Build Issues

**Error: `flutter_secure_storage` requires minSdkVersion 23**
- Solution: Update `android/app/build.gradle` to set `minSdkVersion 23`

**Error: Hive adapter not found**
- Solution: Run `dart run build_runner build --delete-conflicting-outputs`

**Error: Firebase not initialized**
- Solution: Verify `google-services.json` / `GoogleService-Info.plist` is in the correct location

**Error: Cloud Function deployment fails**
- Solution: Ensure you're logged in (`firebase login`) and have selected the correct project (`firebase use <project-id>`)

### Runtime Issues

**Issue: Identity not persisting**
- Check that `flutter_secure_storage` has proper keychain/keystore access
- On iOS: Verify Keychain Sharing capability is enabled
- On Android: Check that `encryptedSharedPreferences: true` is set

**Issue: Messages not sending**
- Verify Firebase Anonymous Auth is working
- Check Firestore rules are deployed correctly
- Verify Cloud Function is deployed and running

**Issue: Notifications not received**
- Verify FCM token is being generated and stored
- Check that the Cloud Function has execute permissions
- Ensure notification permissions are granted on the device

**Issue: Duress PIN not working**
- Verify both normal and duress PINs are set and different
- Check that the wipe function is completing without errors
- Review logs for any exceptions during the wipe process

### Testing Issues

**Error: `bcrypt` not found in tests**
- Solution: Run `flutter pub get` to ensure all dependencies are resolved

**Error: Crypto operations hang in tests**
- Solution: Ensure you're running tests with `flutter test` (not `dart test`) for proper platform crypto support

---

## Security Notes

- **Never commit `google-services.json` or `GoogleService-Info.plist` to version control**
- **Store your seed phrase securely - it cannot be recovered if lost**
- **The duress PIN is a destructive action - test it only in a safe environment**
- **All messages are encrypted client-side before any network transmission**
- **Plaintext messages exist only in memory and are never written to disk**

---

## Support

For issues related to:
- **Flutter**: https://docs.flutter.dev/
- **Firebase**: https://firebase.google.com/docs
- **Signal Protocol (libsignal)**: https://github.com/MixinNetwork/libsignal_protocol_dart
- **BIP39**: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki

---

**DuoShield v1.0.0 - Built for privacy. Built for you.**
