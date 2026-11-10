import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("User granted notification permission");
    }

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'khair_e_kaseer_channel',
      'High Priority Notifications',
      description: 'This channel is used for important app alerts.',
      importance: Importance.max,
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(initializationSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon ?? '@mipmap/launcher_icon',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    await saveDeviceToken();
    await setupUserSubscriptions();

    _fcm.onTokenRefresh.listen((newToken) async {
      await _updateTokenInFirestore(newToken);
    });
  }

  Future<void> saveDeviceToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _updateTokenInFirestore(token);
      }
    }
  }

  Future<void> _updateTokenInFirestore(String token) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('Users').doc(user.uid).set(
          {
            'fcmToken': token,
            'fcmTokenLastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        debugPrint("FCM Token saved successfully for user ${user.uid}");
      } catch (e) {
        debugPrint("Error saving FCM Token: $e");
      }
    }
  }

  /// Subscribes current device to FCM topics based on role and vehicle type.
  Future<void> subscribeToRoleTopics({
    required String role,
    String? vehicleType,
  }) async {
    await unsubscribeFromAllTopics();

    String normalizedRole = role.trim().toLowerCase();

    switch (normalizedRole) {
      case 'donor':
        await _fcm.subscribeToTopic('topic_donor');
        debugPrint("Subscribed to topic_donor");
        break;

      case 'ngo':
        await _fcm.subscribeToTopic('topic_ngo');
        debugPrint("Subscribed to topic_ngo");
        break;

      case 'beneficiary':
        await _fcm.subscribeToTopic('topic_beneficiary');
        debugPrint("Subscribed to topic_beneficiary");
        break;

      case 'volunteer':
      case 'rider':
      // Subscribe to general volunteer topic
        await _fcm.subscribeToTopic('topic_volunteer');
        debugPrint("Subscribed to topic_volunteer");

        if (vehicleType != null && vehicleType.isNotEmpty) {
          String normalizedVehicle = vehicleType.trim().toLowerCase();

          // Handles both 'large'/'small' values and 'van'/'bike' synonyms
          if (normalizedVehicle == 'large' ||
              normalizedVehicle == 'van' ||
              normalizedVehicle == 'cargo' ||
              normalizedVehicle == 'truck') {
            await _fcm.subscribeToTopic('topic_volunteer_large');
            debugPrint("Subscribed to topic_volunteer_large");
          } else {
            await _fcm.subscribeToTopic('topic_volunteer_small');
            debugPrint("Subscribed to topic_volunteer_small");
          }
        } else {
          // Default fallback to small vehicle topic
          await _fcm.subscribeToTopic('topic_volunteer_small');
          debugPrint("Subscribed to default topic_volunteer_small");
        }
        break;

      default:
        debugPrint("No matching notification topic for role: $role");
        break;
    }
  }

  Future<void> setupUserSubscriptions() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        String role = data['role'] ?? '';
        String? vehicleType = data['vehicleType'];

        await subscribeToRoleTopics(role: role, vehicleType: vehicleType);
      }
    } catch (e) {
      debugPrint("Error setting up user topic subscriptions: $e");
    }
  }

  Future<void> unsubscribeFromAllTopics() async {
    try {
      await _fcm.unsubscribeFromTopic('topic_donor');
      await _fcm.unsubscribeFromTopic('topic_ngo');
      await _fcm.unsubscribeFromTopic('topic_beneficiary');
      await _fcm.unsubscribeFromTopic('topic_volunteer');
      await _fcm.unsubscribeFromTopic('topic_volunteer_large');
      await _fcm.unsubscribeFromTopic('topic_volunteer_small');
      await _fcm.unsubscribeFromTopic('topic_volunteer_heavy');
      await _fcm.unsubscribeFromTopic('topic_volunteer_light');
      debugPrint("Unsubscribed from all role topics");
    } catch (e) {
      debugPrint("Error unsubscribing from topics: $e");
    }
  }
}