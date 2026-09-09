import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'routes/app_pages.dart';
import 'screens/calling/incoming_call_decision_dialog.dart';
import 'services/call_notification_service.dart';
import 'services/fcm_service.dart';
import 'services/theme_service.dart';
import 'services/zego_call_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize theme mode preference
  await ThemeService.instance.init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Register top-level background messaging handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize local notifications service with action callbacks
    await CallNotificationService.instance.initialize(
      onNotificationBodyTapped: (call) {
        debugPrint('[CALL PUSH] Notification body tapped -> Opening incoming call decision.');
        final context = ZegoCallService.navigatorKey.currentContext ?? Get.context;
        if (context != null) {
          IncomingCallDecisionDialog.show(context, call);
        }
      },
      onAcceptTapped: (call) {
        debugPrint('[CALL PUSH] Notification ACCEPT action tapped.');
        ZegoCallService.instance.acceptCallFromNotification(call);
      },
      onRejectTapped: (call) {
        debugPrint('[CALL PUSH] Notification REJECT action tapped.');
        ZegoCallService.instance.rejectCallFromNotification(call);
      },
    );

    // Initialize FCM listeners and token synchronization
    await FcmService.instance.initialize(
      onIncomingCallTapped: (call) {
        final context = ZegoCallService.navigatorKey.currentContext ?? Get.context;
        if (context != null) {
          IncomingCallDecisionDialog.show(context, call);
        }
      },
    );
  } catch (e, stackTrace) {
    debugPrint('Firebase / Notification initialization failed: $e');
    debugPrint('$stackTrace');
  }

  runApp(const ConnectCallApp());
}

class ConnectCallApp extends StatelessWidget {
  const ConnectCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeService.instance.themeMode.value,
        navigatorKey: ZegoCallService.navigatorKey,
        initialRoute: AppPages.initial,
        getPages: AppPages.pages,
      ),
    );
  }
}
