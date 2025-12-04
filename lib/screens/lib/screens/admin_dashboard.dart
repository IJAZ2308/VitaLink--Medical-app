import 'package:dr_shahin_uk/screens/lib/screens/admin_doctor_approval_screen.dart';
import 'package:dr_shahin_uk/screens/lib/screens/logout_helper.dart';
import 'package:dr_shahin_uk/screens/lib/screens/manage_bed_screen.dart';
import 'package:dr_shahin_uk/screens/lib/screens/shared_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'manage_doctors_screen.dart';
import 'manage_patients_screen.dart';
import 'manage_hospitals_screen.dart';
import 'manage_appointments_screen.dart';

import 'verify_doctors_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  // ignore: unused_field
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int totalDoctors = 0;
  int consultingDoctors = 0;
  int labDoctors = 0;
  int pendingDoctors = 0;
  int totalPatients = 0;
  int totalHospitals = 0;
  int totalAppointments = 0;

  Map<String, dynamic> hospitals = {};
  List<Map<String, dynamic>> appointments = [];

  bool _isLoadingAppointments = true;
  final int _selectedFilter = 0;
  final String _searchQuery = "";
  String _doctorFilter = "all";

  StreamSubscription<DatabaseEvent>? _pendingDoctorsSubscription;
  final List<String> _pendingDoctorUids = [];

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _loadAppointments();
    _listenPendingDoctors();
  }

  @override
  void dispose() {
    _pendingDoctorsSubscription?.cancel();
    super.dispose();
  }

  // 🔹 Logout

  // ✅ Load Counts
  Future<void> _loadCounts() async {
    final usersSnap = await _dbRef.child('users').get();
    final hospitalsSnap = await _dbRef.child('hospitals').get();
    final appointmentsSnap = await _dbRef.child('appointments').get();

    int docCount = 0,
        patientCount = 0,
        consultingCount = 0,
        labCount = 0,
        pendingCount = 0;

    if (usersSnap.value != null) {
      final map = Map<String, dynamic>.from(usersSnap.value as Map);
      map.forEach((key, value) {
        final user = Map<String, dynamic>.from(value);
        final role = (user['role'] ?? '').toString().toLowerCase();
        final status = (user['status'] ?? '').toString().toLowerCase();
        final category =
            (user['category'] ?? user['specialization'] ?? user['type'] ?? '')
                .toString()
                .toLowerCase()
                .trim();

        if (role == 'patient') {
          patientCount++;
        } else if (role == 'doctor') {
          docCount++;
          if (status == 'pending') pendingCount++;

          // 🩺 Categorize doctors
          if (category.contains('consult')) {
            consultingCount++;
          } else if (category.contains('lab')) {
            labCount++;
          } else {
            consultingCount++; // Default to consulting if not specified
          }
        }
      });
    }

    setState(() {
      totalDoctors = docCount;
      totalPatients = patientCount;
      consultingDoctors = consultingCount;
      labDoctors = labCount;
      pendingDoctors = pendingCount;
      totalHospitals = hospitalsSnap.value != null
          ? (hospitalsSnap.value as Map).length
          : 0;
      totalAppointments = appointmentsSnap.value != null
          ? (appointmentsSnap.value as Map).length
          : 0;
      hospitals = hospitalsSnap.value != null
          ? Map<String, dynamic>.from(hospitalsSnap.value as Map)
          : {};
    });
  }

  // 🔹 Load Appointments
  Future<void> _loadAppointments() async {
    setState(() => _isLoadingAppointments = true);
    final snapshot = await _dbRef.child('appointments').get();

    List<Map<String, dynamic>> tmp = [];
    if (snapshot.value != null) {
      final map = snapshot.value as Map<dynamic, dynamic>;
      map.forEach((key, value) {
        tmp.add({
          'id': key,
          'doctorName': value['doctorName'] ?? '',
          'patientName': value['patientName'] ?? '',
          'specialty': value['specialization'] ?? '',
          'dateTime': value['dateTime'] ?? '',
          'status': value['status'] ?? 'pending',
          'cancelReason': value['cancelReason'] ?? '',
          'website': value['website'] ?? '',
        });
      });
    }

    if (!mounted) return;
    setState(() {
      appointments = tmp;
      _isLoadingAppointments = false;
    });
  }

  // 🔹 Open external URLs
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open URL")));
    }
  }

  // 🔹 Send test FCM (stub)
  Future<void> sendTestNotification(String token) async {
    try {
      await http.post(
        Uri.parse("https://fcm.googleapis.com/fcm/send"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "key=YOUR_SERVER_KEY_HERE",
        },
        body: jsonEncode({
          "to": token,
          "notification": {
            "title": "Test Notification",
            "body": "Hello from AdminDashboard",
          },
        }),
      );
    } catch (e) {
      debugPrint("❌ FCM Error: $e");
    }
  }

  // 🎨 Count Card Widget (clickable)
  Widget _buildCountCard(
    String title,
    int count,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // ignore: deprecated_member_use
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 10),
            Text(
              "$count",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 Navigation Cards
  Widget _buildNavigationCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // ignore: deprecated_member_use
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          leading: CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: badgeCount > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                )
              : const Icon(Icons.arrow_forward_ios, color: Colors.white),
        ),
      ),
    );
  }

  void _showDoctorFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Filter Doctors"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("All"),
              onTap: () {
                setState(() => _doctorFilter = "all");
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text("Consulting Doctors"),
              onTap: () {
                setState(() => _doctorFilter = "consulting");
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text("Lab Doctors"),
              onTap: () {
                setState(() => _doctorFilter = "lab");
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Real-time pending doctor listener
  void _listenPendingDoctors() {
    _pendingDoctorsSubscription = _dbRef
        .child('users')
        .orderByChild('status')
        .equalTo('pending')
        .onChildAdded
        .listen((event) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data != null) {
            final doctorName = data['name'] ?? 'New Doctor';
            final doctorUid = event.snapshot.key!;
            if (!_pendingDoctorUids.contains(doctorUid)) {
              _pendingDoctorUids.add(doctorUid);
              _showNewDoctorPopup(doctorName);
              _loadCounts();
            }
          }
        });
  }

  // 🔹 Popup for new pending doctor
  void _showNewDoctorPopup(String doctorName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Doctor Registration"),
        content: Text(
          "$doctorName has registered and is pending verification.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VerifyPending()),
              );
            },
            child: const Text("Verify Now"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAppointments = appointments.where((appt) {
      final status = (appt['status'] ?? '').toString().toLowerCase();
      final dt = DateTime.tryParse(appt['dateTime'] ?? '');
      bool matchesFilter = true;
      switch (_selectedFilter) {
        case 1:
          matchesFilter =
              (status == 'pending' || status == 'confirmed') &&
              dt != null &&
              dt.isAfter(DateTime.now());
          break;
        case 2:
          matchesFilter = status == 'cancelled';
          break;
        case 3:
          matchesFilter = status == 'completed';
          break;
      }
      bool matchesSearch =
          appt['doctorName'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          appt['patientName'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchesFilter && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showDoctorFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              LogoutHelper.logout(context);
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Overview",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  if (_doctorFilter == "all" || _doctorFilter == "consulting")
                    _buildCountCard(
                      "Consulting Doctors",
                      consultingDoctors,
                      Icons.medical_services_outlined,
                      Colors.blue,
                    ),
                  if (_doctorFilter == "all" || _doctorFilter == "lab")
                    _buildCountCard(
                      "Lab Doctors",
                      labDoctors,
                      Icons.biotech_rounded,
                      Colors.purple,
                    ),
                  if (_doctorFilter == "all")
                    _buildCountCard(
                      "Total Doctors",
                      totalDoctors,
                      Icons.local_hospital,
                      Colors.teal,
                    ),
                  _buildCountCard(
                    "Patients",
                    totalPatients,
                    Icons.people,
                    Colors.green,
                  ),
                  _buildCountCard(
                    "Hospitals",
                    totalHospitals,
                    Icons.business,
                    Colors.orange,
                  ),
                  _buildCountCard(
                    "Appointments",
                    totalAppointments,
                    Icons.calendar_month,
                    Colors.pink,
                  ),
                  _buildCountCard(
                    "Pending Doctors",
                    pendingDoctors,
                    Icons.verified_user,
                    Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VerifyPending(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "Admin Controls",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              _buildNavigationCard(
                title: "Manage Doctors",
                icon: Icons.medical_services_rounded,
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageDoctorsScreen(),
                  ),
                ),
              ),
              _buildNavigationCard(
                title: "Manage Patients",
                icon: Icons.people_alt_rounded,
                color: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManagePatientsScreen(
                      patientId: '',
                      patientName: '',
                      doctorId: '',
                    ),
                  ),
                ),
              ),
              _buildNavigationCard(
                title: "Manage Hospitals",
                icon: Icons.local_hospital_rounded,
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageHospitalsScreen(),
                  ),
                ),
              ),
              _buildNavigationCard(
                title: "Manage Appointments",
                icon: Icons.calendar_month_rounded,
                color: Colors.pink,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageAppointmentsScreen(),
                  ),
                ),
              ),
              _buildNavigationCard(
                title: "Manage Reports",
                icon: Icons.analytics_rounded,
                color: Colors.deepPurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SharedReportsScreen(),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ManageBedScreen()),
                  );
                },
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bed, size: 40, color: Colors.pink),
                        SizedBox(height: 10),
                        Text(
                          "Manage Bed Bookings",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              _buildNavigationCard(
                title: "Verify Pending Doctors",
                icon: Icons.verified_user_rounded,
                color: Colors.redAccent,
                badgeCount: pendingDoctors,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminDoctorApprovalScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _isLoadingAppointments
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredAppointments.length,
                      itemBuilder: (context, index) {
                        final appt = filteredAppointments[index];
                        final formattedDate = appt['dateTime'] != ''
                            ? DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(DateTime.parse(appt['dateTime']))
                            : 'N/A';
                        return Card(
                          elevation: 3,
                          child: ListTile(
                            title: Text(
                              "${appt['doctorName']} → ${appt['patientName']}",
                            ),
                            subtitle: Text(
                              "${appt['specialty']} | ${appt['status'].toString().toUpperCase()} | $formattedDate",
                            ),
                            trailing: appt['website'] != ''
                                ? IconButton(
                                    icon: const Icon(Icons.link),
                                    onPressed: () => _openUrl(appt['website']),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
