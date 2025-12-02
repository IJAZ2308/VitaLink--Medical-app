// lib/services/push_notifications_service.dart
// Handles saving token, receiving FCM, showing local popup, saving inbox, sending via Cloud Function

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Initialize after Firebase.initializeApp() and login
  static Future<void> initialize({
    required String userId,
    required String role,
    BuildContext? context,
  }) async {
    // Mark firebase_core & auth as used
    Firebase.app();
    FirebaseAuth.instance.currentUser;

    // Request notification permission
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Get token and save
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenForUser(userId: userId, role: role, token: token);
    }

    // Token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _saveTokenForUser(userId: userId, role: role, token: newToken);
    });

    // Local notifications setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null && context != null) {
          _handleNavigation(context, payload);
        }
      },
    );

    // Foreground messages
    FirebaseMessaging.onMessage.listen((message) async {
      final n = message.notification;
      if (n != null) {
        await _showLocal(title: n.title ?? '', body: n.body ?? '');
        await saveNotificationToInbox(
          userId: userId,
          title: n.title ?? '',
          body: n.body ?? '',
        );
      }
    });

    // Background tapped
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final type = message.data['type'];
      if (type != null && context != null) {
        // ignore: use_build_context_synchronously
        _handleNavigation(context, type);
      }
    });

    // App opened from killed state
    RemoteMessage? initial = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initial != null && context != null) {
      final type = initial.data['type'];
      if (type != null) {
        // ignore: use_build_context_synchronously
        _handleNavigation(context, type);
      }
    }
  }

  /// Save FCM token to Realtime DB
  static Future<void> _saveTokenForUser({
    required String userId,
    required String role,
    required String token,
  }) async {
    if (role == 'doctor') {
      await _db.child('doctors/$userId/fcmToken').set(token);
    } else {
      await _db.child('users/$userId/fcmToken').set(token);
    }
    debugPrint('Saved FCM token for $userId');
  }

  /// Show local notification
  static Future<void> _showLocal({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'vitalink_channel',
      'VitaLink Notifications',
      channelDescription: 'Channel for VitaLink app notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const platform = NotificationDetails(android: androidDetails);
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platform,
    );
  }

  /// Save inbox notification
  static Future<void> saveNotificationToInbox({
    required String userId,
    required String title,
    required String body,
  }) async {
    final ref = _db.child('notifications/$userId').push();
    await ref.set({
      'title': title,
      'body': body,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'read': false,
    });
  }

  /// Handle navigation when notification tapped
  static void _handleNavigation(BuildContext ctx, String type) {
    switch (type) {
      case 'appointment':
        Navigator.pushNamed(ctx, '/appointments');
        break;
      case 'lab_report':
        Navigator.pushNamed(ctx, '/labReports');
        break;
      case 'bed_availability':
        Navigator.pushNamed(ctx, '/bedAvailability');
        break;
      case 'doctor_confirmed':
        Navigator.pushNamed(ctx, '/doctorAppointments');
        break;
      case 'chat':
        Navigator.pushNamed(ctx, '/chat');
        break;
      default:
        Navigator.pushNamed(ctx, '/');
    }
  }

  /// Send notification via Firebase Cloud Function (secure)
  static Future<void> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
    String type = 'general',
    required Map<String, String> data,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendPushNotification',
      );
      final result = await callable.call(<String, dynamic>{
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'type': type,
      });
      debugPrint('Notification sent: ${result.data}');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  static void setupFCMListeners(BuildContext context) {}

  static Future<void> saveUserToken() async {}

  static Future<void> sendPushMessage(
    String doctorToken,
    String s,
    String t,
  ) async {}
}
