import 'package:dr_shahin_uk/screens/lib/screens/lab_appointment_listpage.dart';
import 'package:dr_shahin_uk/screens/upload_document_screen.dart';
import 'package:dr_shahin_uk/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'doctor/Doctor Module Exports/doctor_chatlist_page.dart';

class LabDoctorDashboard extends StatefulWidget {
  const LabDoctorDashboard({super.key});

  @override
  State<LabDoctorDashboard> createState() => _LabDoctorDashboardState();
}

class _LabDoctorDashboardState extends State<LabDoctorDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String _doctorName = "Lab Doctor";
  List<Map<String, String>> _patients = [];
  Map<String, List<Map<String, String>>> _patientReports = {};
  List<Map<String, String>> _appointments = [];
  bool _loadingPatients = true;
  bool _loadingAppointments = true;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    await _fetchDoctorData();
    await _fetchAppointments();
    await _fetchPatients();

    NotificationService.initialize();
    NotificationService.setupFCM();
  }

  Future<void> _fetchDoctorData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _db.child("users/${user.uid}").get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        _doctorName = data['name'] ?? "Lab Doctor";
      });
    }
  }

  Future<void> _fetchAppointments() async {
    setState(() => _loadingAppointments = true);
    final doctorId = _auth.currentUser!.uid;

    final snapshot = await _db
        .child('appointments')
        .orderByChild('labDoctorId')
        .equalTo(doctorId)
        .get();

    final List<Map<String, String>> loadedAppointments = [];

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        final appt = Map<String, dynamic>.from(value);
        loadedAppointments.add({
          "id": key,
          "date": appt['date'] ?? '',
          "time": appt['time'] ?? '',
          "patientId": appt['patientId'] ?? '',
          "status": appt['status'] ?? 'Pending',
          "requestingDoctorId": appt['requestingDoctorId'] ?? '',
        });
      });
    }

    setState(() {
      _appointments = loadedAppointments;
      _loadingAppointments = false;
    });
  }

  Future<void> _fetchPatients() async {
    setState(() => _loadingPatients = true);

    final List<Map<String, String>> loadedPatients = [];
    final Map<String, List<Map<String, String>>> loadedReports = {};

    for (var appt in _appointments) {
      final pid = appt['patientId']!;
      if (pid.isEmpty) continue;

      if (!loadedPatients.any((p) => p['uid'] == pid)) {
        final patientSnapshot = await _db.child("users/$pid").get();
        if (patientSnapshot.exists) {
          final pData = Map<String, dynamic>.from(patientSnapshot.value as Map);
          loadedPatients.add({'uid': pid, 'name': pData['name'] ?? 'Patient'});

          final patientReports = <Map<String, String>>[];
          if (pData['reports'] != null) {
            final Map<dynamic, dynamic> reportsMap = Map<String, dynamic>.from(
              pData['reports'],
            );
            reportsMap.forEach((key, report) {
              final reportData = Map<String, dynamic>.from(report);
              patientReports.add({
                'name': reportData['reportName'] ?? 'Report',
                'url': reportData['reportUrl'] ?? '',
                'doctorId': reportData['doctorId'] ?? '',
              });
            });
          }
          loadedReports[pid] = patientReports;
        }
      }
    }

    setState(() {
      _patients = loadedPatients;
      _patientReports = loadedReports;
      _loadingPatients = false;
    });
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout ?? false) {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _pickPatientAndUpload() {
    if (_patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No patients with appointments assigned."),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Select Patient to Upload Document"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _patients.length,
              itemBuilder: (context, index) {
                final patient = _patients[index];
                return ListTile(
                  title: Text(patient['name']!),
                  subtitle:
                      _patientReports[patient['uid']!]?.isNotEmpty ?? false
                      ? Text(
                          "Reports: ${_patientReports[patient['uid']!]?.length ?? 0}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    final labDoctorId = _auth.currentUser!.uid;
                    final appt = _appointments.firstWhere(
                      (a) => a['patientId'] == patient['uid'],
                    );
                    final requestingDoctorId =
                        appt['requestingDoctorId'] ?? labDoctorId;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UploadDocumentScreen(
                          patientId: patient['uid']!,
                          patientName: patient['name']!,
                          doctorId: requestingDoctorId,
                        ),
                      ),
                    ).then((_) => _fetchPatients());
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _viewAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabAppointmentListPage(
          patientId: '',
          patientName: '',
          doctorId: '',
          doctorName: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("Lab Doctor Dashboard - $_doctorName"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF64B5F6), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
          ],
        ),
        body: (_loadingPatients || _loadingAppointments)
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _dashboardCard(
                      icon: Icons.upload_file,
                      title: "Upload Reports",
                      gradientColors: [Colors.pinkAccent, Colors.redAccent],
                      badgeCount: _patients.length,
                      onTap: _pickPatientAndUpload,
                    ),
                    _dashboardCard(
                      icon: Icons.chat_bubble_outline,
                      title: "Chats",
                      gradientColors: [Colors.cyan, Colors.teal],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DoctorChatlistPage(),
                          ),
                        );
                      },
                    ),
                    _dashboardCard(
                      icon: Icons.event,
                      title: "Lab Appointments",
                      gradientColors: [Colors.orangeAccent, Colors.deepOrange],
                      badgeCount: _appointments.length,
                      onTap: _viewAppointments,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _dashboardCard({
    required IconData icon,
    required String title,
    required List<Color> gradientColors,
    VoidCallback? onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: gradientColors.last.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(3, 3),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 45, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.yellow, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
