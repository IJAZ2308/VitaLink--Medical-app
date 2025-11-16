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

/// ------------------------ LOCAL NOTIFICATIONS ------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Android notification channel
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // name
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

/// ------------------------ FIREBASE OPTIONS ------------------------
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

/// ------------------------ MAIN APP ------------------------
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

/// ------------------------ AUTH SERVICE ------------------------
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  final String cloudName = "dij8c34qm";
  final String uploadPreset = "medi360_unsigned";

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

      final Map<String, dynamic> data =
          jsonDecode(responseData.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['secure_url'] != null) {
        return data['secure_url'] as String;
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
      debugPrint('Error uploading profile image to Cloudinary: $e');
      return null;
    }
  }

  Future<bool> registerUser({
    required String email,
    required String password,
    required String name,
    required String role, // always "doctor"
    required String specialization,
    required bool isVerified, // false for new doctor
    required String doctorType, // pending / approved
    required String s, // labDoctor / consultingDoctor
    required String licenseUrl, // FIXED
    required String profileUrl,
    required licenseFile,
    required String licenseFileUrl,
    File? profileFile,
    required String profileFileUrl, // FIXED
  }) async {
    try {
      // Create user
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = result.user!.uid;

      // Save doctor data
      final doctorRef = _db.child("doctors").child(uid);

      await doctorRef.set({
        'uid': uid,
        'name': name,
        'email': email,
        'role': "doctor", // doctor main role
        'doctorRole': s, // consultingDoctor / labDoctor
        'licenseUrl': licenseUrl, // NOW CORRECT
        'profileUrl': profileUrl, // NOW CORRECT
        'specialization': specialization,
        'status': doctorType, // pending / approved
        'isVerified': isVerified,
        'fcmToken': '',
        'createdAt': DateTime.now().toIso8601String(),
      });

      /// Save FCM token specifically for doctors
      Future<void> saveDoctorToken(String uid) async {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseDatabase.instance.ref("doctors/$uid").update({
            "fcmToken": token,
          });
        }
      }

      // Save token correctly for doctors
      await saveDoctorToken(uid);

      return true;
    } catch (e) {
      developer.log("Register error", error: e);
      return false;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      DataSnapshot snapshot;

      // First check in "doctors" node
      snapshot = await _db.child("doctors").child(result.user!.uid).get();

      if (snapshot.exists) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          snapshot.value as Map,
        );

        if (data['isVerified'] == false) {
          return null; // Doctor must be verified
        }

        await saveUserToken();
        return data['role'] as String?;
      }

      // Otherwise check in "users" node
      snapshot = await _db.child("users").child(result.user!.uid).get();

      if (!snapshot.exists) return null;

      final Map<String, dynamic> data = Map<String, dynamic>.from(
        snapshot.value as Map,
      );

      await saveUserToken();
      return data['role'] as String?;
    } catch (e) {
      developer.log("Login error", error: e);
      return null;
    }
  }

  Future<void> saveUserToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseDatabase.instance.ref("users/${user.uid}").update({
        "fcmToken": token,
      });
      developer.log("🔑 Saved FCM Token: $token");
    }
  }

  void setupFCMListeners(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }
}

/// ------------------------ FCM BACKGROUND HANDLER ------------------------
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  developer.log("🔔 Handling background message: ${message.messageId}");
  _showLocalNotification(message);
}

/// ------------------------ LOCAL NOTIFICATION HELPER ------------------------
Future<void> _showLocalNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  if (notification != null && Platform.isAndroid) {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
    );
  }
}

/// ------------------------ MAIN FUNCTION ------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}
