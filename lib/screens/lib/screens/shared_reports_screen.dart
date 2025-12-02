// lib/screens/patient/shared_reports_screen.dart

// lib/screens/shared_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class SharedReportsScreen extends StatefulWidget {
  const SharedReportsScreen({super.key});

  @override
  State<SharedReportsScreen> createState() => _SharedReportsScreenState();
}

class _SharedReportsScreenState extends State<SharedReportsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> _filteredReports = [];
  String _role = "";
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoleAndReports();
  }

  Future<void> _loadRoleAndReports() async {
    final uid = _auth.currentUser!.uid;

    /// 1️⃣ Get User Role
    final userSnap = await _db.child("users/$uid").get();
    if (userSnap.exists) {
      final data = Map<String, dynamic>.from(userSnap.value as Map);
      _role = data["role"] ?? "";
    }

    /// 2️⃣ Fetch all reports
    await _fetchReportsForRole(uid);
  }

  Future<void> _fetchReportsForRole(String uid) async {
    final reportSnap = await _db.child("reports").get();

    if (!reportSnap.exists || reportSnap.value == null) {
      setState(() {
        _filteredReports = [];
        _loading = false;
      });
      return;
    }

    final allReports = Map<String, dynamic>.from(reportSnap.value as Map);
    List<Map<String, dynamic>> list = [];

    /// 3️⃣ Role-based report filtering
    allReports.forEach((key, value) {
      final report = Map<String, dynamic>.from(value);
      report['id'] = key;

      if (_role == "patient") {
        /// Only their own reports
        if (report["patientId"] == uid) list.add(report);
      }

      if (_role == "doctor") {
        /// Only reports shared with this doctor
        if (report["sharedWith"] != null &&
            (report["sharedWith"] as List).contains(uid)) {
          list.add(report);
        }
      }

      if (_role == "admin") {
        /// Admin sees ALL reports
        list.add(report);
      }
    });

    /// Sort latest first
    list.sort((a, b) {
      return DateTime.parse(
        b['uploadedOn'],
      ).compareTo(DateTime.parse(a['uploadedOn']));
    });

    if (!mounted) return;

    setState(() {
      _filteredReports = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _role == "patient"
              ? "My Shared Reports"
              : _role == "doctor"
              ? "Patient Reports Shared With You"
              : "All Reports (Admin)",
        ),
        backgroundColor: const Color(0xff0064FA),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReports.isEmpty
          ? const Center(child: Text("No reports found"))
          : ListView.builder(
              itemCount: _filteredReports.length,
              itemBuilder: (context, index) {
                final report = _filteredReports[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                      report['reportName'] ?? "Medical Report",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Date: ${report['uploadedOn']}"),
                        if (_role != "patient")
                          Text("Patient: ${report['patientName'] ?? ''}"),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () async {
                        final url = report['reportUrl'];
                        if (url != null && await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
