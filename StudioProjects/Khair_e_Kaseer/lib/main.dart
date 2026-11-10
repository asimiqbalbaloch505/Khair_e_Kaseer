import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:khair_e_kaseer/firebase_options.dart';
import 'package:khair_e_kaseer/screens/onboarding/auth_wrapper.dart';
import 'package:khair_e_kaseer/screens/login_form_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:khair_e_kaseer/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint("Handling background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    FirebaseDatabase.instance.databaseURL =
    "https://khair-e-kaseer-default-rtdb.asia-southeast1.firebasedatabase.app";

    // Register Background Handler for FCM
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize Push Notification Service
    await NotificationService().initialize();

    // Listen to Auth State Changes for Phase 2 Topic Subscriptions & Cleanup
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        debugPrint("Auth State: User logged in (${user.uid})");
        await NotificationService().saveDeviceToken();
        await NotificationService().setupUserSubscriptions();
      } else {
        debugPrint("Auth State: User logged out");
        await NotificationService().unsubscribeFromAllTopics();
      }
    });
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Khair-e-Kaseer',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      routes: {
        '/login': (context) => const LoginFormScreen(),
      },
      home: const AuthWrapper(),
    );
  }
}