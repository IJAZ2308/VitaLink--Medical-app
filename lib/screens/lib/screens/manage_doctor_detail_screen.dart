// lib/screens/manage_doctor_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dr_shahin_uk/services/notification_service.dart';

class ManageDoctorDetailScreen extends StatefulWidget {
  final String doctorId;

  const ManageDoctorDetailScreen({super.key, required this.doctorId});

  @override
  State<ManageDoctorDetailScreen> createState() => _ManageDoctorDetailScreenState();
}

class _ManageDoctorDetailScreenState extends State<ManageDoctorDetailScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('doctors');
  Map<String, dynamic>? doctorData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDoctorDetails();
  }

  Future<void> _fetchDoctorDetails() async {
    final snapshot = await _dbRef.child(widget.doctorId).get();
    if (snapshot.exists) {
      setState(() {
        doctorData = Map<String, dynamic>.from(snapshot.value as Map);
        isLoading = false;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Doctor not found")),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _updateStatus(String status) async {
    if (doctorData == null) return;

    try {
      bool isVerified = status.toLowerCase() == 'approved';
      await _dbRef.child(widget.doctorId).update({
        'status': status,
        'isVerified': isVerified,
      });

      await _sendNotification(status);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Doctor status updated to $status")),
      );

      setState(() {
        doctorData!['status'] = status;
        doctorData!['isVerified'] = isVerified;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating status: $e")),
      );
    }
  }

  Future<void> _deleteDoctor() async {
    if (doctorData == null) return;

    try {
      await _dbRef.child(widget.doctorId).remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Doctor deleted successfully")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting doctor: $e")),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Cannot launch URL';
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or unreachable license URL')),
      );
    }
  }

  Future<void> _sendNotification(String status) async {
    if (doctorData == null) return;

    final name = doctorData!['name'] ?? doctorData!['email'] ?? 'Doctor';
    final fcmToken = doctorData!['fcmToken'] ?? '';

    if (fcmToken.isNotEmpty) {
      await PushNotificationService.sendPushNotification(
        fcmToken: fcmToken,
        title: 'Doctor Account $status',
        body: 'Hello $name, your account has been $status by the admin.',
        data: {},
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final name = doctorData!['name'] ?? doctorData!['email'] ?? 'Unknown Doctor';
    final email = doctorData!['email'] ?? 'Not provided';
    final specialty = doctorData!['specialty'] ?? 'Not specified';
    final status = doctorData!['status'] ?? 'pending';
    final licenseUrl = doctorData!['licenseUrl'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text("Doctor Details"), backgroundColor: Colors.teal, centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 28, backgroundColor: Colors.teal.shade100, child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.teal, fontSize: 24))),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(email, style: const TextStyle(fontSize: 16))])
          ]),
          const SizedBox(height: 16),
          Text("Specialty: $specialty", style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Row(children: [
            const Text("Status: ", style: TextStyle(fontSize: 16)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _getStatusColor(status), borderRadius: BorderRadius.circular(12)),
              child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 16),
          if (licenseUrl.isNotEmpty) TextButton.icon(onPressed: () => _openUrl(licenseUrl), icon: const Icon(Icons.description, size: 20, color: Colors.blue), label: const Text("View License", style: TextStyle(color: Colors.blue))),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            ElevatedButton.icon(onPressed: () => _updateStatus("approved"), icon: const Icon(Icons.check), label: const Text("Approve"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)),
            ElevatedButton.icon(onPressed: () => _updateStatus("rejected"), icon: const Icon(Icons.close), label: const Text("Reject"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange)),
            ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Doctor?'),
                    content: const Text('Are you sure you want to delete this doctor?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) _deleteDoctor();
              },
              icon: const Icon(Icons.delete),
              label: const Text("Delete"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ])
        ]),
      ),
    );
  }
}
