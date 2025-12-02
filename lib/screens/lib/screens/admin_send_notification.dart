// lib/screens/admin_send_notification.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminSendNotification extends StatefulWidget {
  const AdminSendNotification({super.key});

  @override
  State<AdminSendNotification> createState() => _AdminSendNotificationState();
}

class _AdminSendNotificationState extends State<AdminSendNotification> {
  String selectedRole = "patient"; // "patient" or "doctor" or "all"
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();

  final dbRef = FirebaseDatabase.instance.ref();

  final Map<String, Map<String, String>> presetMessages = {
    "Bed Booked": {
      "title": "Bed Booking Confirmed",
      "msg": "A bed has been successfully booked for the patient.",
    },
    "Bed Available": {
      "title": "Bed Now Available",
      "msg": "A bed is now available for booking.",
    },
    "Patient Booked Doctor": {
      "title": "New Appointment Booked",
      "msg": "A patient has booked an appointment with you.",
    },
    "Doctor Confirmed Appointment": {
      "title": "Appointment Confirmed",
      "msg": "Doctor has confirmed your appointment.",
    },
    "Lab Appointment Booked": {
      "title": "Lab Appointment Booked",
      "msg": "A new lab appointment has been scheduled.",
    },
    "Lab Report Sent": {
      "title": "Lab Report Ready",
      "msg": "A new lab report has been uploaded by the lab doctor.",
    },
  };

  @override
  void dispose() {
    _titleController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void applyPreset(String key) {
    _titleController.text = presetMessages[key]!['title']!;
    _msgController.text = presetMessages[key]!['msg']!;
    setState(() {});
  }

  Future<void> sendNotification() async {
    final title = _titleController.text.trim();
    final body = _msgController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title & message required')));
      return;
    }

    // determine node to read tokens from
    final node = (selectedRole == 'doctor') ? 'doctors' : 'users';

    final snapshot = await dbRef.child(node).once();
    if (!snapshot.snapshot.exists) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(const SnackBar(content: Text('No users found')));
      return;
    }

    // gather tokens
    final List<Map<String, dynamic>> payloads = [];
    for (var child in snapshot.snapshot.children) {
      final Map? data = child.value as Map?;
      if (data != null && data['fcmToken'] != null) {
        payloads.add({
          'token': data['fcmToken'],
          'title': title,
          'body': body,
          'type': data['role'] == 'doctor' ? 'doctor_confirmed' : 'general',
        });
      }
    }

    // push each payload into manualNotifications node — Cloud Function will read & send
    for (var p in payloads) {
      await dbRef.child('manualNotifications').push().set({
        'token': p['token'],
        'title': p['title'],
        'body': p['body'],
        'type': p['type'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    _titleController.clear();
    _msgController.clear();

    ScaffoldMessenger.of(
      // ignore: use_build_context_synchronously
      context,
    ).showSnackBar(const SnackBar(content: Text('Notifications queued')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Send Notification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(labelText: 'Send to'),
              items: const [
                DropdownMenuItem(value: 'patient', child: Text('Patients')),
                DropdownMenuItem(value: 'doctor', child: Text('Doctors')),
                DropdownMenuItem(value: 'all', child: Text('All Users')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => selectedRole = v);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presetMessages.keys.map((k) {
                return OutlinedButton(
                  onPressed: () => applyPreset(k),
                  child: Text(k),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgController,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendNotification,
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
