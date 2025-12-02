import 'package:dr_shahin_uk/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class AdminDoctorApprovalScreen extends StatefulWidget {
  const AdminDoctorApprovalScreen({super.key});

  @override
  State<AdminDoctorApprovalScreen> createState() =>
      _AdminDoctorApprovalScreenState();
}

class _AdminDoctorApprovalScreenState extends State<AdminDoctorApprovalScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'doctors',
  );
  late TabController _tabController;
  bool _isLoading = true;

  List<Map<String, dynamic>> pendingDoctors = [];
  List<Map<String, dynamic>> approvedDoctors = [];
  List<Map<String, dynamic>> rejectedDoctors = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    final snapshot = await _dbRef.get();
    final data = snapshot.value as Map<dynamic, dynamic>?;

    List<Map<String, dynamic>> tempPending = [];
    List<Map<String, dynamic>> tempApproved = [];
    List<Map<String, dynamic>> tempRejected = [];

    if (data != null) {
      data.forEach((key, value) {
        if (value is Map) {
          final role = value['role'] ?? '';
          final status = value['status'] ?? 'pending'; // default pending
          if (role == 'labDoctor' || role == 'consultingDoctor') {
            final doctor = {
              'id': key,
              'firstName': value['firstName'] ?? '',
              'lastName': value['lastName'] ?? '',
              'email': value['email'] ?? '',
              'phoneNumber': value['phoneNumber'] ?? '',
              'license': value['license'] ?? '',
              'resumeUrl': value['resumeUrl'] ?? '',
              'address': value['address'] ?? '',
              'createdAt': value['createdAt'],
              'role': role,
              'status': status,
              'fcmToken': value['fcmToken'] ?? '',
            };
            if (status == 'pending') tempPending.add(doctor);
            if (status == 'approved') tempApproved.add(doctor);
            if (status == 'rejected') tempRejected.add(doctor);
          }
        }
      });
    }

    setState(() {
      pendingDoctors = tempPending;
      approvedDoctors = tempApproved;
      rejectedDoctors = tempRejected;
      _isLoading = false;
    });
  }

  /// 🔹 Update status + send notification
  Future<void> _updateDoctorStatus(
    String doctorId,
    String status,
    bool verified,
  ) async {
    await _dbRef.child(doctorId).update({
      'status': status,
      'isVerified': verified,
    });
    await _sendNotification(doctorId, status);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Doctor marked as $status')));
    _loadDoctors();
  }

  /// 🔹 Delete doctor record
  Future<void> _deleteDoctor(String doctorId) async {
    final confirm = await _showDeleteConfirmDialog();
    if (confirm) {
      await _dbRef.child(doctorId).remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor deleted successfully')),
      );
      _loadDoctors();
    }
  }

  Future<bool> _showDeleteConfirmDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Type CONFIRM to delete this doctor"),
              TextField(controller: controller),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context, false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete"),
              onPressed: () {
                if (controller.text.trim().toUpperCase() == "CONFIRM") {
                  Navigator.pop(context, true);
                }
              },
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// 🔔 Send push notification
  Future<void> _sendNotification(String doctorId, String status) async {
    final snapshot = await _dbRef.child(doctorId).get();
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final name = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
    final token = data['fcmToken'] ?? '';
    if (token.isNotEmpty) {
      await PushNotificationService.sendPushNotification(
        fcmToken: token,
        title: 'Doctor Account $status',
        body: 'Hello $name, your account has been $status by the admin.',
        data: {},
      );
    }
  }

  void _openDoctorDetail(Map<String, dynamic> doctor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorDetailRealtimePage(doctorData: doctor),
      ),
    ).then((_) => _loadDoctors());
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final status = doctor['status'] ?? 'pending';
    final color = status == 'approved'
        ? Colors.green
        : status == 'rejected'
        ? Colors.red
        : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          "${doctor['firstName']} ${doctor['lastName']}".trim().isEmpty
              ? "Unnamed Doctor"
              : "${doctor['firstName']} ${doctor['lastName']}".trim(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("Email: ${doctor['email']}"),
        trailing: Chip(
          label: Text(status.toUpperCase(), style: TextStyle(color: color)),
          // ignore: deprecated_member_use
          backgroundColor: color.withOpacity(0.1),
          side: BorderSide(color: color),
        ),
        onTap: () => _openDoctorDetail(doctor),
      ),
    );
  }

  Widget _buildDoctorList(List<Map<String, dynamic>> list) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) return const Center(child: Text("No doctors found."));
    return RefreshIndicator(
      onRefresh: _loadDoctors,
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) => _buildDoctorCard(list[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Doctor Verification Dashboard"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Approved"),
            Tab(text: "Rejected"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDoctorList(pendingDoctors),
          _buildDoctorList(approvedDoctors),
          _buildDoctorList(rejectedDoctors),
        ],
      ),
    );
  }
}

/// ✅ Doctor Detail Page (Realtime DB)
class DoctorDetailRealtimePage extends StatelessWidget {
  final Map<String, dynamic> doctorData;

  const DoctorDetailRealtimePage({super.key, required this.doctorData});

  @override
  Widget build(BuildContext context) {
    final name =
        "${doctorData['firstName'] ?? ''} ${doctorData['lastName'] ?? ''}"
            .trim();
    final createdAt = doctorData['createdAt'];
    String formattedDate = "Not Available";
    if (createdAt != null && createdAt.toString().isNotEmpty) {
      try {
        final date = DateTime.fromMillisecondsSinceEpoch(
          int.parse(createdAt.toString()),
        );
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? "Doctor Details" : name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _detail("Name", name),
            _detail("Email", doctorData['email'] ?? ""),
            _detail("Phone", doctorData['phoneNumber'] ?? ""),
            _detail("License", doctorData['license'] ?? ""),
            _detail("Role", doctorData['role'] ?? ""),
            _detail("Address", doctorData['address'] ?? ""),
            _detail("Account Created", formattedDate),
            _resumeSection(context),
            const SizedBox(height: 20),
            _actionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _resumeSection(BuildContext context) {
    final resumeUrl = doctorData['resumeUrl'] ?? '';
    if (resumeUrl.isEmpty) {
      return const Text(
        "Resume: No Resume Uploaded",
        style: TextStyle(fontSize: 16),
      );
    }
    return Row(
      children: [
        const Text("Resume: ", style: TextStyle(fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: () async {
            final uri = Uri.parse(resumeUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: const Text("View Resume"),
        ),
      ],
    );
  }

  Widget _actionButtons(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text("Approve Doctor"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () {
            Navigator.pop(context);
            final parentState = context
                .findAncestorStateOfType<_AdminDoctorApprovalScreenState>();
            parentState?._updateDoctorStatus(
              doctorData['id'],
              'approved',
              true,
            );
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.close),
          label: const Text("Reject Doctor"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: () {
            Navigator.pop(context);
            final parentState = context
                .findAncestorStateOfType<_AdminDoctorApprovalScreenState>();
            parentState?._updateDoctorStatus(
              doctorData['id'],
              'rejected',
              false,
            );
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.delete),
          label: const Text("Delete Doctor"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            Navigator.pop(context);
            final parentState = context
                .findAncestorStateOfType<_AdminDoctorApprovalScreenState>();
            parentState?._deleteDoctor(doctorData['id']);
          },
        ),
      ],
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextSpan(text: value, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
