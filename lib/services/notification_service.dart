// lib/services/notification_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // 🚀 Your FCM server key (keep private)
  static const String _serverKey = 'YOUR_FCM_SERVER_KEY_HERE';

  BuildContext? appContext;

  /// -------------------- INIT --------------------
  Future<void> init({BuildContext? context}) async {
    appContext = context ?? appContext;

    await Firebase.initializeApp();

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (payload) {
        _handleNavigation(payload as String?);
      },
    );

    // Save device token
    await _saveDeviceToken();

    // Subscribe to all users topic
    await subscribeToTopic('allUsers');

    // Listen to role-based database events
    _listenToRoleEvents();

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Background/terminated messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNavigation(message.data['type']);
    });
  }

  /// -------------------- BACKGROUND HANDLER --------------------
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp();
    print('📩 Background message received: ${message.messageId}');
  }

  /// -------------------- SAVE DEVICE TOKEN --------------------
  Future<void> _saveDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await _messaging.getToken();
      if (token != null) {
        await _dbRef.child('users/${user.uid}/fcmToken').set(token);
        print('✅ Saved FCM token for user: ${user.uid}');
      }
    }
  }

  /// -------------------- SUBSCRIBE / UNSUBSCRIBE --------------------
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  /// -------------------- SEND PUSH NOTIFICATION --------------------
  static Future<void> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final postUrl = Uri.parse('https://fcm.googleapis.com/fcm/send');
      final payload = {
        "to": fcmToken,
        "notification": {"title": title, "body": body, "sound": "default"},
        "data": data ?? {},
      };

      final response = await http.post(
        postUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print("✅ Push notification sent successfully!");
      } else {
        print("❌ Failed to send notification: ${response.body}");
      }
    } catch (e) {
      print("⚠️ Error sending notification: $e");
    }
  }

  /// -------------------- LOCAL NOTIFICATIONS --------------------
  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (message.notification != null) {
      final notification = message.notification!;
      await _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'vitalink_channel',
            'VitaLink Notifications',
            channelDescription: 'Channel for VitaLink notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: message.data['type'], // Pass type for navigation
      );
    }
  }

  void _showLocalNotificationForRole({
    required String title,
    required String body,
  }) {
    _flutterLocalNotificationsPlugin.show(
      title.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'vitalink_channel',
          'VitaLink Notifications',
          channelDescription: 'Channel for VitaLink notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// -------------------- ROLE-BASED LISTENERS --------------------
  void _listenToRoleEvents() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _dbRef.child('users/${user.uid}/role').onValue.listen((event) {
      final role = event.snapshot.value as String?;
      if (role == null) return;

      if (role == 'doctor') {
        _dbRef
            .child('appointments')
            .orderByChild('doctorId')
            .equalTo(user.uid)
            .onChildAdded
            .listen((event) {
              final appointment = event.snapshot.value as Map;
              _showLocalNotificationForRole(
                title: 'New Appointment',
                body: 'Appointment with ${appointment['patientName']}',
              );
            });
      } else if (role == 'patient') {
        _dbRef
            .child('reports')
            .orderByChild('patientId')
            .equalTo(user.uid)
            .onChildAdded
            .listen((event) {
              final report = event.snapshot.value as Map;
              _showLocalNotificationForRole(
                title: 'New Report Available',
                body: 'Your report from Dr. ${report['doctorName']} is ready.',
              );
            });
      }
    });
  }

  /// -------------------- NAVIGATION BASED ON NOTIFICATION TYPE --------------------
  void _handleNavigation(String? type) {
    if (type == null || appContext == null) return;

    switch (type) {
      case 'lab_report':
        Navigator.pushNamed(appContext!, '/labReports');
        break;
      case 'appointment':
        Navigator.pushNamed(appContext!, '/appointments');
        break;
      case 'bed_availability':
        Navigator.pushNamed(appContext!, '/bedAvailability');
        break;
      case 'doctor_approval':
        Navigator.pushNamed(appContext!, '/doctorApproval');
        break;
      default:
        Navigator.pushNamed(appContext!, '/');
    }
  }

  /// -------------------- STATIC METHODS FOR GLOBAL USAGE --------------------
  static Future<void> initialize({BuildContext? context}) async {
    await NotificationService().init(context: context);
  }

  static Future<void> saveUserToken() async {
    await NotificationService()._saveDeviceToken();
  }

  static void setupFCMListeners(BuildContext context) {
    NotificationService().appContext = context;
    NotificationService()._listenToRoleEvents();
    FirebaseMessaging.onMessage.listen(
      (message) => NotificationService()._showLocalNotification(message),
    );
  }
}
