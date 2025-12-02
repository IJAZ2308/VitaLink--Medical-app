import 'dart:convert';
import 'package:dr_shahin_uk/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ManagePatientsScreen extends StatefulWidget {
  const ManagePatientsScreen({super.key});

  @override
  State<ManagePatientsScreen> createState() => _ManagePatientsScreenState();
}

class _ManagePatientsScreenState extends State<ManagePatientsScreen> {
  final DatabaseReference _patientsRef = FirebaseDatabase.instance.ref().child(
    'users',
  );
  final DatabaseReference _appointmentsRef = FirebaseDatabase.instance
      .ref()
      .child('appointments');

  // ---------------- NOTIFICATION SERVICE ----------------
  Future<void> _sendNotification(
    String patientId,
    String title,
    String body,
  ) async {
    try {
      final tokenSnap = await _patientsRef
          .child(patientId)
          .child('fcmToken')
          .get();
      if (!tokenSnap.exists) {
        if (kDebugMode) print("❌ No FCM token found for $patientId");
        return;
      }

      final fcmToken = tokenSnap.value.toString();

      // ---------------- Using dart:convert and http ----------------
      final payload = json.encode({
        'to': fcmToken,
        'notification': {'title': title, 'body': body},
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'screen': 'patient_dashboard',
        },
      });

      // Dummy POST request to FCM endpoint (replace YOUR_SERVER_KEY with real key)
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=YOUR_SERVER_KEY',
        },
        body: payload,
      );

      // ---------------- Use NotificationService directly ----------------
      await PushNotificationService.sendPushNotification(
        fcmToken: fcmToken,
        title: title,
        body: body,
        data: {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'screen': 'patient_dashboard',
        },
      );

      if (kDebugMode) print("✅ Notification sent to $patientId");
    } catch (e) {
      if (kDebugMode) print("Notification Error: $e");
    }
  }

  // ---------------- VERIFY / DELETE PATIENT ----------------
  void _updateVerification(String patientId, bool isVerified) async {
    await _patientsRef.child(patientId).update({'verified': isVerified});

    String statusText = isVerified ? 'verified' : 'rejected';
    await _sendNotification(
      patientId,
      "Account $statusText",
      "Your patient account has been $statusText by the admin.",
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Patient $statusText successfully!')),
      );
    }
  }

  void _deletePatient(String patientId) async {
    await _patientsRef.child(patientId).remove();

    await _sendNotification(
      patientId,
      "Account Deleted",
      "Your patient account has been deleted by the admin.",
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient deleted successfully!')),
      );
    }
  }

  // ---------------- FETCH PATIENTS ----------------
  Future<List<Map<String, dynamic>>> _fetchPatients() async {
    final patientsSnapshot = await _patientsRef.get();
    final appointmentsSnapshot = await _appointmentsRef.get();

    Map<dynamic, dynamic> patientsMap = {};
    if (patientsSnapshot.value != null) {
      patientsMap = patientsSnapshot.value as Map<dynamic, dynamic>;
    }

    Map<dynamic, dynamic> appointmentsMap = {};
    if (appointmentsSnapshot.value != null) {
      appointmentsMap = appointmentsSnapshot.value as Map<dynamic, dynamic>;
    }

    List<Map<String, dynamic>> patientsList = [];

    for (var entry in patientsMap.entries) {
      final data = Map<String, dynamic>.from(entry.value as Map);

      // ✅ Only include patients
      if ((data['role'] ?? 'patient') != 'patient') continue;

      data['patientId'] = entry.key;

      if (data['name'] == "Unknown") {
        for (var appt in appointmentsMap.values) {
          final apptData = Map<String, dynamic>.from(appt);
          if (apptData['patientId'] == entry.key &&
              apptData['patientName'] != null) {
            data['name'] = apptData['patientName'];
            break;
          }
        }
      }

      patientsList.add(data);
    }

    return patientsList;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Patients')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchPatients(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No patients found"));
          }

          final patients = snapshot.data!;

          return ListView.builder(
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final data = patients[index];

              double averageRating = 0;
              if (data['numberOfReviews'] != null &&
                  data['numberOfReviews'] > 0 &&
                  data['totalReviews'] != null) {
                averageRating = data['totalReviews'] / data['numberOfReviews'];
              }

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(data['name'] ?? "Unknown"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Email: ${data['email'] ?? 'N/A'}"),
                      Text("Verified: ${data['verified'] ?? false}"),
                      if (averageRating > 0)
                        Text("Rating: ${averageRating.toStringAsFixed(1)}"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () =>
                            _updateVerification(data['patientId'], true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () =>
                            _updateVerification(data['patientId'], false),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        onPressed: () => _deletePatient(data['patientId']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
