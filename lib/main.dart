import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show
        AndroidInitializationSettings,
        FlutterLocalNotificationsPlugin,
        AndroidNotificationChannel,
        Importance,
        AndroidNotificationDetails,
        NotificationDetails,
        Priority,
        AndroidFlutterLocalNotificationsPlugin,
        InitializationSettings;

import 'package:http/http.dart' as http;

import 'package:dr_shahin_uk/screens/auth/login_screen.dart';
import 'package:dr_shahin_uk/services/database_service.dart';

final DatabaseService dbService = DatabaseService();

/// --------------------------------------------------------------
///                  LOCAL NOTIFICATION SETUP
/// --------------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

/// --------------------------------------------------------------
///                  FIREBASE OPTIONS
/// --------------------------------------------------------------
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: "AIzaSyCbcpM-BuqGUtfy071fODqwib_Nhm0BrEY",
      authDomain: "drshahin-uk.firebaseapp.com",
      projectId: "drshahin-uk",
      storageBucket: "drshahin-uk.appspot.com",
      messagingSenderId: "943831581906",
      appId: "1:943831581906:web:a9812cd3ca574d2ee5d90b",
      measurementId: "G-KP31V1Q2P9",
      databaseURL: "https://drshahin-uk-default-rtdb.firebaseio.com/",
    );
  }
}

/// --------------------------------------------------------------
///                  MAIN APP WIDGET
/// --------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VitaLink',
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}

/// --------------------------------------------------------------
///                       AUTH SERVICE
/// --------------------------------------------------------------
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  final String cloudName = "dij8c34qm";
  final String uploadPreset = "medi360_unsigned";

  /// ---------------- Cloudinary License Upload ----------------
  Future<String?> uploadLicense(File licenseFile) async {
    try {
      final Uri uploadUrl = Uri.parse(
        "https://api.cloudinary.com/v1_1/dij8c34qm/auto/upload",
      );

      final http.MultipartRequest request =
          http.MultipartRequest("POST", uploadUrl)
            ..fields['upload_preset'] = uploadPreset
            ..files.add(
              await http.MultipartFile.fromPath('file', licenseFile.path),
            );

      final http.StreamedResponse response = await request.send();
      final http.Response responseData = await http.Response.fromStream(
        response,
      );

      developer.log("Cloudinary response: ${responseData.body}");

      final Map<String, dynamic> data = jsonDecode(responseData.body);

      if (response.statusCode == 200 && data['secure_url'] != null) {
        return data['secure_url'];
      } else {
        throw Exception(
          "Cloudinary upload failed: ${data['error'] ?? responseData.body}",
        );
      }
    } catch (e) {
      developer.log("Cloudinary upload error", error: e);
      return null;
    }
  }

  /// ---------------- Cloudinary Profile Upload ----------------
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("https://api.cloudinary.com/v1_1/dij8c34qm/auto/upload"),
      );
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      final data = json.decode(resBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data['secure_url'];
      } else {
        debugPrint("Cloudinary upload failed: $data");
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  /// ---------------- Register User / Doctor ----------------
  Future<bool> registerUser({
    required String email,
    required String password,
    required String name,
    required String role,
    required String specialization,
    required bool isVerified,
    required String doctorType,
    required String s,
    required String licenseFileUrl, // <-- pass uploaded license URL
    required String profileFileUrl,
    required licenseFile,
    required String licenseUrl,
    required String profileUrl, // <-- pass uploaded profile URL
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = result.user!.uid;

      final doctorRef = _db.child("doctors").child(uid);

      await doctorRef.set({
        'uid': uid,
        'name': name,
        'email': email,
        'role': "doctor",
        'doctorRole': s,
        'licenseUrl': licenseFileUrl, // <-- fixed
        'profileUrl': profileFileUrl, // <-- fixed
        'specialization': specialization,
        'status': doctorType,
        'isVerified': isVerified,
        'fcmToken': '',
        'createdAt': DateTime.now().toIso8601String(),
      });

      await saveFCMToken(uid: uid, isDoctor: true);

      return true;
    } catch (e) {
      developer.log("Register error", error: e);
      return false;
    }
  }

  /// ---------------- Login Function ----------------
  Future<String?> login(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = result.user!.uid;

      final DataSnapshot doctorSnap = await _db.child("doctors/$uid").get();

      if (doctorSnap.exists) {
        final data = Map<String, dynamic>.from(doctorSnap.value as Map);

        if (data['isVerified'] == false) return null;

        await saveFCMToken(uid: uid, isDoctor: true);
        return data['role'];
      }

      final DataSnapshot userSnap = await _db.child("users/$uid").get();

      if (!userSnap.exists) return null;

      final data = Map<String, dynamic>.from(userSnap.value as Map);

      await saveFCMToken(uid: uid, isDoctor: false);
      return data['role'];
    } catch (e) {
      developer.log("Login error", error: e);
      return null;
    }
  }

  /// ---------------- Save FCM Token ----------------
  Future<void> saveFCMToken({
    required String uid,
    required bool isDoctor,
  }) async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      final node = isDoctor ? "doctors/$uid" : "users/$uid";
      await _db.child(node).update({"fcmToken": token});
      developer.log("Saved FCM Token for $node: $token");

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _db.child(node).update({"fcmToken": newToken});
      });
    }
  }

  /// ---------------- Foreground Listener ----------------
  void setupFCMListeners(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  /// ---------------- Background Handler ----------------
  Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log("Handling background message: ${message.messageId}");
  }

  /// ---------------- Local Notification Show ----------------
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;

    if (notification != null && Platform.isAndroid) {
      final androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
      );

      final platformDetails = NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformDetails,
      );
    }
  }
}

/// --------------------------------------------------------------
///                        MAIN FUNCTION
/// --------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onBackgroundMessage(
    AuthService().firebaseMessagingBackgroundHandler,
  );

  runApp(const MyApp());
}
