# 📞 ConnectCall — Enterprise-Grade Audio/Video Calling & Screen Sharing App

[![GitHub Repo](https://img.shields.io/badge/GitHub-Repository-181717?style=flat&logo=github&logoColor=white)](https://github.com/DeepakMewada20/connect-call.git)
[![Flutter](https://img.shields.io/badge/Flutter-3.29%2B-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12%2B-blue.svg)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2F%20GetX-green.svg)](https://pub.dev/packages/get)
[![Calling SDK](https://img.shields.io/badge/Calling-ZEGOCLOUD%20UIKit-orange.svg)](https://www.zegocloud.com)
[![Backend](https://img.shields.io/badge/Backend-Firebase%20%2B%20Cloud%20Functions-yellow.svg)](https://firebase.google.com)
[![Tests](https://img.shields.io/badge/Tests-201%20Passed-brightgreen.svg)](test/)

> **🔗 Quick Links & Downloads:**
> - **🎥 Video Walkthrough Demo:** [Watch on Google Drive](https://drive.google.com/file/d/1Z3ElECZ7K0cbYEhzUJpY8oFkJEmzoB5C/view?usp=drive_link)
> - **💻 Source Code Repository:** [https://github.com/DeepakMewada20/connect-call.git](https://github.com/DeepakMewada20/connect-call.git)
> 
> ```bash
> # Clone the complete repository:
> git clone https://github.com/DeepakMewada20/connect-call.git
> ```

**ConnectCall** is a modern, enterprise-ready real-time communication application built with **Flutter**, **Firebase**, and **ZEGOCLOUD**. It features 1-to-1 and multi-party HD voice/video calling, real-time in-call screen sharing, background/terminated push notification waking via FCM, intelligent device contact synchronization with UTF-16 emoji-safe display resolution, and offline-first local SQLite call history persistence.

---

## 📑 Table of Contents
1. [Project Overview](#-project-overview)
2. [Key Features](#-key-features)
3. [SDK & Technology Stack](#-sdk--technology-stack)
4. [Packages & Dependencies](#-packages--dependencies)
5. [Architecture & Design Pattern](#-architecture--design-pattern)
6. [Backend Infrastructure](#-backend-infrastructure)
7. [Calling & Media Engine](#-calling--media-engine)
8. [Setup & Installation Guide](#-setup--installation-guide)
9. [Configuration & Environment](#-configuration--environment)
10. [How to Test](#-how-to-test)
11. [Known Limitations](#-known-limitations)
12. [AI Tools Used](#-ai-tools-used)

---

## 🌟 Project Overview

ConnectCall provides a WhatsApp/FaceTime-grade calling experience on mobile devices. It solves complex mobile real-time challenges including:
- Receiving and answering incoming calls when the app is in the background or killed (terminated state).
- Seamless screen sharing on Android 14+ using strict `MediaProjection` foreground services.
- Resilient Unicode handling preventing UTF-16 crashes when rendering contact names with emojis.
- Full offline-first local SQLite database for instant call logs without network roundtrips.

---

## 🚀 Key Features

### 1. 🔐 Authentication & Onboarding
- **Phone Number OTP Login**: Seamless authentication with Firebase Phone Auth, automated verification, and SMS OTP resend timers.
- **User Profile Management**: Custom profile avatar upload with interactive circular image cropping (`image_cropper`).
- **Real-time Online Presence**: Automatic active/idle presence tracking stored in Cloud Firestore.

### 2. 🎙️ High-Definition Audio Calling
- **Crystal Clear Audio**: Hardware acoustic echo cancellation (AEC), automatic gain control (AGC), and active noise suppression.
- **In-Call Audio Controls**: Real-time microphone mute/unmute, audio routing toggle (Earpiece vs. Speakerphone), and dynamic soundwave animations.
- **Live Call Timer**: Precise duration tracking synchronized with local storage.

### 3. 📹 High-Definition Video Calling
- **1-on-1 & Multi-Party Video**: Smooth 720p/1080p adaptive bitrate video streams.
- **Camera Controls**: Instant front/rear camera flip, local video mute, and aspect-fill video rendering.
- **Gallery Layout with Fullscreen Support**: Dynamically adapts stream tiles to optimize screen space and host active screen sharing.

### 4. 🖥️ Real-time Screen Sharing
- **Android 14+ Ready**: Fully configured `mediaProjection` foreground service compliant with Android 14 security rules.
- **Interactive Toggles**: In-call quick action buttons in top and bottom bars.
- **Active Visual Indicator**: Top floating pulsing badge (🔴 "Sharing your screen") with a single-tap "Stop" action.

### 5. 👥 Multi-Party Conferencing & In-Call Invitations
- **Add to Call**: Bottom sheet participant picker allowing users to invite active contacts directly into an ongoing call without leaving the room.

### 6. 📱 Intelligent Contact Management
- **Two-Way Sync**: Fetches device contacts with non-blocking caching.
- **Address Book Priority Resolution**: Automatically prioritizes names saved in local contacts over cloud usernames.
- **Safe UTF-16 & Emoji Support**: Custom Unicode grapheme parser preventing unpaired surrogate exceptions (`string is not well-formed UTF-16`).
- **Smart Search**: Real-time search by name, phone number digits, or initials.
- **Quick Native Actions**: Direct integration to launch phone dialer, SMS app, or WhatsApp chat.

### 7. 🔔 Push Notifications & Smart Call Handling
- **FCM High-Priority Data Messages**: Wakes up terminated apps on incoming calls.
- **Unified Decision Dialog**: Custom full-screen Accept / Reject dialog with a 60-second expiration guard.
- **Persistent Ringtone & Vibration**: High-priority notification channels configured with full-screen intent permissions.

### 8. 🗄️ Offline-First SQLite Call History
- **Zero Latency**: Reads and writes call logs directly into a local SQLite database (`sqflite`).
- **Comprehensive Metadata**: Tracks caller, callee, call direction (incoming/outgoing), status (answered, missed, rejected, failed), timestamp, and duration.
- **One-Tap Redial**: Instantly place an audio or video call directly from any history card.

---

## 🛠️ SDK & Technology Stack

| Component | Specification |
| :--- | :--- |
| **Framework** | **Flutter** (Target: `>=3.29.0`) |
| **Language** | **Dart** (`>=3.12.2 <4.0.0`) |
| **State Management** | **GetX** (Reactive State, Dependency Injection & Navigation) |
| **Target Platforms** | Android (API 24 to 35 / Android 14+), iOS |
| **Local Database** | **SQLite** (`sqflite`) |
| **Cloud Services** | **Google Firebase** (Auth, Firestore, Messaging, Functions) |
| **RTC Media Engine** | **ZEGOCLOUD Express Engine & ZIM Signaling** |

---

## 📦 Packages & Dependencies

Below is the complete inventory of packages declared in `pubspec.yaml`:

```yaml
dependencies:
  # State Management & Routing
  get: ^4.7.3

  # Firebase Ecosystem
  firebase_core: ^4.14.0
  firebase_auth: ^6.6.1
  cloud_firestore: ^6.9.0
  cloud_functions: ^6.4.0
  firebase_messaging: ^16.4.1

  # Calling & RTC Media (ZEGOCLOUD)
  zego_uikit_prebuilt_call: ^4.24.4
  zego_uikit_signaling_plugin: ^2.8.21
  zego_uikit: ^2.29.2

  # Local Storage & Database
  sqflite: ^2.4.3
  path: ^1.9.1
  shared_preferences: ^2.3.5

  # Contacts & Permissions
  flutter_contacts: ^2.3.1
  permission_handler: ^12.0.3

  # Media & UI Components
  image_picker: ^1.1.2
  image_cropper: ^12.2.1
  pinput: ^6.0.2
  flutter_local_notifications: ^22.0.1
  url_launcher: ^6.3.2
  share_plus: ^12.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  sqflite_common_ffi: ^2.4.2+1
  flutter_lints: ^6.0.0
```

---

## 🏗️ Architecture & Design Pattern

The application strictly follows a **Layered Clean Architecture** combined with **GetX** for dependency injection and reactive state bindings:

```
lib/
├── core/                         # Enterprise Foundation Layer
│   ├── constants/                # App strings, assets, dimensions
│   ├── theme/                    # Color palettes, dark/light themes
│   └── utils/                    # UTF-16 StringUtils, PhoneNumberUtil
├── data/                         # Local & Remote Persistence Layer
│   ├── datasources/              # SQLite Local Data Source (sqflite)
│   └── repositories/             # Call History Repository implementation
├── models/                       # Type-Safe Domain Data Models
│   ├── call_model.dart           # SQLite Call History entity
│   ├── user_model.dart           # Firestore User profile entity
│   ├── pending_call_model.dart   # FCM Push Payload entity
│   └── zego_token_response.dart  # Secure Token Exchange model
├── routes/                       # Central Declarative Navigation
│   └── app_routes.dart           # GetPage routing definitions
├── screens/                      # Presentation Layer (UI & Controllers)
│   ├── auth/                     # Login & OTP screens + AuthController
│   ├── calls/                    # Calls history tab + CallsController
│   ├── calling/                  # Active call UI, Screen Share & Overlays
│   ├── contacts/                 # Device contacts, search & details
│   ├── home/                     # Bottom nav hub & dashboard
│   ├── profile/                  # User profile & edit screen
│   └── splash/                   # App bootstrap & auth guard
└── services/                     # Singleton Business Logic & Platform APIs
    ├── auth_service.dart         # Firebase Auth abstraction
    ├── block_service.dart        # Firestore User blocklist
    ├── call_history_service.dart # SQLite bridge service
    ├── contact_service.dart      # Device contacts & name resolver
    ├── fcm_service.dart          # Push notifications & message handlers
    ├── network_quality_service.dart # Real-time latency/packet-loss monitoring
    ├── theme_service.dart        # Reactive ThemeController
    ├── user_service.dart         # Firestore User CRUD operations
    └── zego_call_service.dart    # ZEGOCLOUD Call & Screen Sharing Service
```

---

## ☁️ Backend Infrastructure

1. **Firebase Authentication**:
   - Phone Number Authentication with SMS OTP verification.
   - Session persistence across cold starts.
2. **Cloud Firestore**:
   - `users/{uid}`: Stores user display name, phone number, avatar URL, push token, and online status.
   - `blocked_users/{uid}`: Subcollection tracking blocked contacts.
   - `favorites/{uid}`: Tracks starred contacts.
3. **Cloud Functions**:
   - `getZegoToken`: Secure server-side function that mints temporary calling tokens (prevents hardcoding ZEGOCLOUD AppSign on client devices).
   - `sendCallNotification`: Dispatches high-priority data payloads via Firebase Admin SDK to awaken callee devices.
4. **Local SQLite (`sqflite`)**:
   - Stores all call logs locally (`calls.db`).
   - Indexes by `user_id` and `started_at` for instantaneous querying.

---

## 📡 Calling & Media Engine

- **ZEGOCLOUD Prebuilt Call UIKit**: Orchestrates audio/video pipelines, camera capture, speaker routing, and stream rendering.
- **ZIM (Zego Instant Messaging)**: Powers the signaling channel for call invitations, accept, decline, busy, and cancellation events.
- **Screen Capture Engine**: Native Android `MediaProjectionManager` combined with `im.zego.internal.screencapture.ZegoScreenCaptureService` in `AndroidManifest.xml` under foreground service type `mediaProjection`.

---

## 🚀 Setup & Installation Guide

### Prerequisites
1. **Flutter SDK**: Ensure Flutter `3.29.x`+ is installed.
   ```bash
   flutter --version
   ```
2. **Android Setup**:
   - Android Studio with Android SDK API 34+ installed.
   - JDK 17 (Java Development Kit 17).
   - Physical Android device with Developer Options and USB Debugging enabled. *(Note: Audio/Video calling and screen sharing require physical hardware).*

### Step 1: Clone the Repository
```bash
git clone https://github.com/DeepakMewada20/connect-call.git
cd connect_call
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

### Step 3: Configure Firebase
1. Create a project on the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Phone Authentication** under *Authentication > Sign-in method*.
3. Create a **Firestore Database** in production mode.
4. Place your Android `google-services.json` file inside:
   ```
   android/app/google-services.json
   ```
5. *(Optional)* If configuring for iOS, place `GoogleService-Info.plist` inside `ios/Runner/`.

### Step 4: Configure ZEGOCLOUD Credentials
1. Register on [ZEGOCLOUD Console](https://console.zegocloud.com/) and create a project with **Voice & Video Call**.
2. Deploy the token server function or configure your credentials in Firebase Cloud Functions.

---

## 📱 How to Build & Install

### Option A: Run Directly on Connected Device
Connect your physical Android device via USB and run:
```bash
flutter run
```

### Option B: Build Release APK
To generate an optimized release APK for distribution:
```bash
flutter build apk --release
```
The resulting APK will be generated at:
```
build/app/outputs/flutter-apk/app-release.apk
```

To install directly to your device via ADB:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## ⚙️ Configuration & Environment

### Android Permissions
The app's permissions are fully declared in `android/app/src/main/AndroidManifest.xml`:
- `INTERNET` & `ACCESS_NETWORK_STATE`: For RTC media streaming and Firebase connectivity.
- `RECORD_AUDIO` & `MODIFY_AUDIO_SETTINGS`: For microphone capture and earpiece/speaker routing.
- `CAMERA`: For video calling.
- `FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_MEDIA_PROJECTION`: For in-call screen sharing on Android 14+.
- `READ_CONTACTS` & `WRITE_CONTACTS`: For device contact synchronization.
- `POST_NOTIFICATIONS` & `USE_FULL_SCREEN_INTENT`: For high-priority incoming call alerts.

---

## 🧪 How to Test

ConnectCall features a comprehensive automated test suite with **201 passing tests**.

### 1. Run All Automated Unit & Widget Tests
Execute the entire test suite from the project root:
```bash
flutter test
```
*Expected Output:*
```text
00:14 +201: All tests passed!
```

### 2. Run Static Code Analysis
Ensure zero lint or type errors exist:
```bash
flutter analyze lib/
```
*Expected Output:*
```text
No issues found!
```

### 3. Run Specific Feature Tests
You can run individual test suites for specific modules:
```bash
# Test SQLite call history offline persistence
flutter test test/call_history_sqlite_test.dart

# Test FCM Push Notifications & Call Lifecycle
flutter test test/phase10_fcm_call_notification_test.dart

# Test Screen Sharing service & UI indicator
flutter test test/screen_sharing_service_test.dart

# Test Contact Name Resolution & Emoji safety
flutter test test/contact_name_resolution_test.dart
```

### 4. Manual End-to-End Testing Matrix
1. **Audio Call Test**:
   - Log in on Device A and Device B with different phone numbers.
   - From Device A, open Contacts and tap the Audio Call button for Device B.
   - Verify ringtone on Device B, tap **Accept**, and test microphone mute and speakerphone.
2. **Video Call & Screen Sharing Test**:
   - Start a Video Call between Device A and Device B.
   - On Device A, tap the **Screen Share** button.
   - When the Android system dialog prompts *"Start recording or casting"*, select *"Entire screen"* and tap **Start now**.
   - Verify that Device B immediately receives the live screen stream in fullscreen mode and Device A shows the red pulsing indicator.
   - Tap **Stop** to smoothly return to normal camera streaming.
3. **Background/Terminated Call Test**:
   - Lock Device B or kill the app from recent tasks.
   - Place a call from Device A.
   - Verify that Device B wakes up with the incoming call decision screen.

---

## ⚠️ Known Limitations

1. **Physical Hardware Requirement**:
   - ZEGOCLOUD media streaming, camera hardware, and Android `MediaProjection` screen recording APIs require a **physical mobile device** and cannot run inside headless Android emulators.
2. **Android 14 MediaProjection Single-Use Token**:
   - On Android 14+, screen capture permission is strictly session-bound. If the user stops screen sharing and starts again, Android will re-prompt the system permission dialog for security.
3. **SMS OTP Quotas**:
   - Firebase Phone Authentication is subject to SMS carrier limits and regional quotas on the Spark (free) tier. For continuous development testing, configure test phone numbers in the Firebase Console.

---

## 🤖 AI Tools Used

This application was engineered, architected, and optimized with the assistance of **Google DeepMind Advanced Agentic Coding (Antigravity AI)**, utilizing:
- Autonomous bug diagnosis and stack trace analysis.
- End-to-end test-driven development (TDD) producing 201 automated unit and widget tests.
- Low-level Unicode UTF-16 surrogate pair sanitization.
- Android 14 foreground service compliance and ZEGOCLOUD lifecycle orchestration.
