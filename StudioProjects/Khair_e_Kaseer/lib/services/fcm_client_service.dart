import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMClientService {
  static const String _projectId = 'khair-e-kaseer';
  static const String _fcmUrl =
      'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

  /// Obtains OAuth2 Access Token using local service account credentials
  static Future<String?> _getAccessToken() async {
    try {
      final jsonString =
      await rootBundle.loadString('assets/service_account.json');
      final accountCredentials =
      auth.ServiceAccountCredentials.fromJson(jsonString);

      final scopes = [
        'https://www.googleapis.com/auth/firebase.messaging'
      ];

      final client =
      await auth.clientViaServiceAccount(accountCredentials, scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();
      return accessToken;
    } catch (e) {
      debugPrint('Error obtaining OAuth2 token: $e');
      return null;
    }
  }

  /// Saves or refreshes the FCM token for the currently logged-in user
  static Future<void> saveTokenToDatabase() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(currentUser.uid)
            .set({
          'fcmToken': fcmToken,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error saving FCM token to database: $e");
    }
  }

  /// Listens to incoming FCM push notifications while the app is in the foreground
  static void listenToForegroundMessages(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${message.notification!.title ?? 'Notification'}: ${message.notification!.body ?? ''}",
            ),
            backgroundColor: const Color(0xFF347A5C),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  /// Send a push notification to a specific FCM Topic with high priority for background delivery
  static Future<bool> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? extraData,
  }) async {
    final token = await _getAccessToken();
    if (token == null) {
      debugPrint('FCM Access Token missing');
      return false;
    }

    final payload = {
      'message': {
        'topic': topic,
        'notification': {
          'title': title,
          'body': body,
        },
        'android': {
          'priority': 'HIGH',
          'notification': {
            'channel_id': 'khair_e_kaseer_channel',
            'sound': 'default',
            'notification_priority': 'PRIORITY_MAX',
            'default_sound': true,
            'default_vibrate_timings': true,
          }
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'title': title,
          'body': body,
          if (extraData != null) ...extraData,
        }
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('Topic Notification successfully sent to $topic');
        return true;
      } else {
        debugPrint('Failed to send topic message ($topic): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint("Error posting FCM message: $e");
      return false;
    }
  }

  /// Send a direct push notification to a single device FCM Token
  static Future<bool> sendNotificationToUserToken({
    required String targetFcmToken,
    required String title,
    required String body,
    Map<String, String>? extraData,
  }) async {
    final token = await _getAccessToken();
    if (token == null) return false;

    final payload = {
      'message': {
        'token': targetFcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'android': {
          'priority': 'HIGH',
          'notification': {
            'channel_id': 'khair_e_kaseer_channel',
            'sound': 'default',
            'notification_priority': 'PRIORITY_MAX',
          }
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'title': title,
          'body': body,
          if (extraData != null) ...extraData,
        }
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('Direct Notification sent successfully');
        return true;
      } else {
        debugPrint('Failed to send direct message: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint("Error sending direct notification: $e");
      return false;
    }
  }
}