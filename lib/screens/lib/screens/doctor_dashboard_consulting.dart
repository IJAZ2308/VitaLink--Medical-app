import 'package:dr_shahin_uk/screens/lib/screens/lab_appointment_book.dart';
import 'package:dr_shahin_uk/screens/lib/screens/lab_appointment_listpage.dart';
import 'package:dr_shahin_uk/screens/lib/screens/shared_reports_screen.dart';
import 'package:dr_shahin_uk/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:dr_shahin_uk/screens/lib/screens/doctor/doctor_appointments_screen.dart';
import 'doctor/Doctor Module Exports/doctor_chatlist_page.dart';

class ConsultingDoctorDashboard extends StatefulWidget {
  const ConsultingDoctorDashboard({super.key});

  @override
  State<ConsultingDoctorDashboard> createState() =>
      _ConsultingDoctorDashboardState();
}

class _ConsultingDoctorDashboardState extends State<ConsultingDoctorDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('users');

  String _doctorName = "Consulting Doctor";
  List<Map<String, String>> _patients = [];
  List<Map<String, String>> _appointments = [];
  bool _loadingAppointments = true;

  @override
  void initState() {
    super.initState();
    _initDoctor();
    NotificationService.initialize();
    NotificationService.setupFCMListeners(context);
  }

  Future<void> _initDoctor() async {
    await _fetchDoctorData();
    await _fetchAppointments();
    await _fetchDoctorPatients();
  }

  Future<void> _fetchDoctorData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _db.child(user.uid).get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _doctorName = data['name'] ?? "Consulting Doctor";
        });
      }
    }
  }

  Future<void> _fetchAppointments() async {
    setState(() => _loadingAppointments = true);
    final doctorId = _auth.currentUser!.uid;
    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child('appointments')
        .orderByChild('doctorId')
        .equalTo(doctorId)
        .get();

    final List<Map<String, String>> loadedAppointments = [];

    if (snapshot.exists) {
      final Map<dynamic, dynamic> dataMap =
          snapshot.value as Map<dynamic, dynamic>;

      for (var entry in dataMap.entries) {
        final appt = Map<String, dynamic>.from(entry.value);
        String patientName = "Unknown";

        if (appt['patientId'] != null) {
          final patientSnapshot = await _db.child(appt['patientId']).get();
          if (patientSnapshot.exists) {
            final patientData = Map<String, dynamic>.from(
              patientSnapshot.value as Map,
            );
            patientName = patientData['name'] ?? "Unknown";
          }
        }

        loadedAppointments.add({
          'id': entry.key,
          'patientId': appt['patientId'] ?? '',
          'patientName': patientName,
          'date': appt['date'] ?? '',
          'time': appt['time'] ?? '',
        });
      }
    }

    setState(() {
      _appointments = loadedAppointments;
      _loadingAppointments = false;
    });
  }

  Future<void> _fetchDoctorPatients() async {
    final doctorId = _auth.currentUser!.uid;
    final appointmentSnapshot = await FirebaseDatabase.instance
        .ref()
        .child('appointments')
        .orderByChild('doctorId')
        .equalTo(doctorId)
        .get();

    final Set<String> patientIds = {};

    if (appointmentSnapshot.exists) {
      final Map<dynamic, dynamic> apptMap =
          appointmentSnapshot.value as Map<dynamic, dynamic>;
      for (var entry in apptMap.entries) {
        final appt = Map<String, dynamic>.from(entry.value);
        if (appt['patientId'] != null) {
          patientIds.add(appt['patientId']);
        }
      }
    }

    final List<Map<String, String>> loadedPatients = [];
    for (var id in patientIds) {
      final patientSnapshot = await _db.child(id).get();
      if (patientSnapshot.exists) {
        final data = Map<String, dynamic>.from(patientSnapshot.value as Map);
        loadedPatients.add({'uid': id, 'name': data['name'] ?? 'Patient'});
      }
    }

    setState(() => _patients = loadedPatients);
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: const Text("Logout"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _pickPatientAndUpload() {
    if (_patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No patients assigned yet.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Lab Appointment Booking"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _patients.length,
              itemBuilder: (context, index) {
                final patient = _patients[index];
                return ListTile(
                  title: Text(patient['name']!),
                  onTap: () {
                    Navigator.pop(context);
                    final doctorId = _auth.currentUser!.uid;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LabAppointmentPage(
                          patientId: patient['uid']!,
                          patientName: patient['name']!,
                          doctorId: doctorId,
                          doctorName: '',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _pickPatientToViewDocuments() {
    if (_patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No patients assigned yet.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("View Lab Appointments for Patient"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _patients.length,
              itemBuilder: (context, index) {
                final patient = _patients[index];
                return ListTile(
                  title: Text(patient['name']!),
                  onTap: () {
                    Navigator.pop(context);
                    final doctorId = _auth.currentUser!.uid;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LabAppointmentListPage(
                          patientId: patient['uid']!,
                          patientName: patient['name']!,
                          doctorId: doctorId,
                          doctorName: _doctorName,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openSharedReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SharedReportsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff0064FA), Color(0xff00C6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text("Welcome, $_doctorName"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient Header
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff0064FA), Color(0xff00C6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Consulting Doctor Dashboard",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _doctorName,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Gradient Grid Menu
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _dashboardCard(
                  Icons.event,
                  "Appointments",
                  [Colors.green, Colors.lightGreen],
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DoctorAppointmentsRealtimePage(),
                      ),
                    );
                  },
                ),
                _dashboardCard(Icons.upload_file, "Upload Reports", [
                  Colors.red,
                  Colors.orange,
                ], _pickPatientAndUpload),
                _dashboardCard(Icons.folder_open, "View Documents", [
                  Colors.orange,
                  Colors.deepOrange,
                ], _pickPatientToViewDocuments),
                _dashboardCard(Icons.share, "Shared Reports", [
                  Colors.teal,
                  Colors.cyan,
                ], _openSharedReports),
                _dashboardCard(
                  Icons.chat,
                  "Chats",
                  [Colors.blue, Colors.lightBlueAccent],
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DoctorChatlistPage(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),
            const Text(
              "Upcoming Appointments",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _loadingAppointments
                ? const Center(child: CircularProgressIndicator())
                : _appointments.isEmpty
                ? const Text("No upcoming appointments.")
                : Column(
                    children: _appointments.map((appt) {
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                // ignore: deprecated_member_use
                                Colors.blue.withOpacity(0.1),
                            child: const Icon(
                              Icons.person,
                              color: Colors.black87,
                            ),
                          ),
                          title: Text(appt['patientName']!),
                          subtitle: Text("${appt['date']} at ${appt['time']}"),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardCard(
    IconData icon,
    String title,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
