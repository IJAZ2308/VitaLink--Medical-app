import 'package:dr_shahin_uk/screens/lib/screens/logout_helper.dart';
import 'package:dr_shahin_uk/screens/lib/screens/patlabappointmentpage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dr_shahin_uk/screens/lib/screens/doctor/Doctor%20Module%20Exports/doctor_list_page.dart';
import 'package:dr_shahin_uk/screens/lib/screens/patient/appointment_list_page.dart';
import 'package:dr_shahin_uk/screens/lib/screens/doctor/chat/chat_screen.dart';
import 'package:dr_shahin_uk/screens/lib/screens/shared_reports_screen.dart';
import 'bed_list_screen.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ------------------------ LOCAL NOTIFICATIONS ------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // name
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Save FCM token
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null && user != null) {
      await FirebaseDatabase.instance.ref("users/${user!.uid}").update({
        "fcmToken": token,
      });
      debugPrint("🔑 Saved FCM Token: $token");
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final userEmail = user?.email ?? 'Patient';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Patient Dashboard"),
        backgroundColor: const Color(0xff0064FA),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              LogoutHelper.logout(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👋 Greeting Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff0064FA), Color(0xff00B4FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      color: Color(0xff0064FA),
                      size: 35,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Welcome back, 👋\n$userEmail",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "Your Health Services",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _animatedDashboardCard(
                  context,
                  icon: Icons.local_hospital,
                  title: "Doctors & Appointments",
                  color1: Colors.blueAccent,
                  color2: Colors.lightBlue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DoctorListPage(selectMode: false),
                      ),
                    );
                  },
                ),
                _animatedDashboardCard(
                  context,
                  icon: Icons.event,
                  title: "Your Appointments",
                  color1: Colors.green,
                  color2: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppointmentListPage(),
                      ),
                    );
                  },
                ),
                _animatedDashboardCard(
                  context,
                  icon: Icons.bed,
                  title: "Bed Availability",
                  color1: Colors.orange,
                  color2: Colors.deepOrangeAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BedListScreen()),
                    );
                  },
                ),
                _animatedDashboardCard(
                  context,
                  icon: Icons.chat_bubble_outline,
                  title: "Chat with Doctor",
                  color1: Colors.purple,
                  color2: Colors.deepPurpleAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatScreen(
                          doctorId: '',
                          doctorName: '',
                          patientId: '',
                          patientName: '',
                        ),
                      ),
                    );
                  },
                ),
                _animatedDashboardCard(
                  context,
                  icon: Icons.folder_shared,
                  title: "Shared Reports",
                  color1: Colors.teal,
                  color2: Colors.cyan,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SharedReportsScreen(),
                      ),
                    );
                  },
                ),
                _animatedDashboardCard(
                  context,
                  icon: Icons.science,
                  title: "Lab Appointments",
                  color1: Colors.pink,
                  color2: Colors.redAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PatLabAppointment(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedDashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // ignore: deprecated_member_use
            colors: [color1.withOpacity(0.85), color2.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: color1.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 45, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
