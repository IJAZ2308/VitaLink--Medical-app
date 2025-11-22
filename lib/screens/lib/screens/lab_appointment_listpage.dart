import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LabAppointmentListPage extends StatefulWidget {
  const LabAppointmentListPage({super.key});

  @override
  State<LabAppointmentListPage> createState() => _LabAppointmentListPageState();
}

class _LabAppointmentListPageState extends State<LabAppointmentListPage> {
  final DatabaseReference _appointmentsRef = FirebaseDatabase.instance
      .ref()
      .child('labAppointments');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child(
    'users',
  );

  final String labDoctorId = FirebaseAuth.instance.currentUser!.uid;
  bool _loading = true;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _listenForLabAppointments();
  }

  void _listenForLabAppointments() {
    _appointmentsRef.onValue.listen((event) async {
      final snapshot = event.snapshot;
      List<Map<String, dynamic>> loadedAppointments = [];

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        for (var entry in data.entries) {
          final appointment = Map<String, dynamic>.from(entry.value);

          // Filter appointments assigned to this lab doctor
          if (appointment['labDoctorId'] == labDoctorId ||
              appointment['labDoctorId'] == null) {
            String patientName = "Unknown";
            String requestingDoctorName = "Unknown";

            // Fetch patient name
            if (appointment['patientId'] != null) {
              final patientSnap = await _usersRef
                  .child(appointment['patientId'])
                  .get();
              if (patientSnap.exists) {
                final pdata = Map<String, dynamic>.from(
                  patientSnap.value as Map,
                );
                patientName = pdata['name'] ?? "Unknown";
              }
            }

            // Fetch requesting doctor name
            if (appointment['doctorId'] != null) {
              final doctorSnap = await _usersRef
                  .child(appointment['doctorId'])
                  .get();
              if (doctorSnap.exists) {
                final ddata = Map<String, dynamic>.from(
                  doctorSnap.value as Map,
                );
                requestingDoctorName = ddata['name'] ?? "Unknown";
              }
            }

            loadedAppointments.add({
              'id': entry.key,
              'patientName': patientName,
              'requestingDoctorName': requestingDoctorName,
              'date': appointment['appointmentDate'] ?? '',
              'time': appointment['timeSlot'] ?? '',
              'testType': appointment['reason'] ?? 'Lab Test',
              'status': appointment['status'] ?? 'Pending',
            });
          }
        }
      }

      setState(() {
        _appointments = loadedAppointments;
        _loading = false;
      });
    });
  }

  void _updateStatus(String appointmentId, String newStatus) async {
    await _appointmentsRef.child(appointmentId).update({'status': newStatus});
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Status updated to $newStatus")));
  }

  void _showStatusDialog(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Update Status"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["Pending", "In Progress", "Completed", "Cancelled"]
              .map(
                (status) => ListTile(
                  title: Text(status),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateStatus(appointment['id'], status);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lab Appointments"),
        backgroundColor: Colors.deepPurple,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
          ? const Center(child: Text("No lab appointments available."))
          : ListView.builder(
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
                final appt = _appointments[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.biotech_rounded,
                      color: Colors.deepPurple,
                    ),
                    title: Text(
                      appt['patientName']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        "Requested by: ${appt['requestingDoctorName']}\n"
                        "Test: ${appt['testType']}\n"
                        "Date: ${appt['date']} at ${appt['time']}\n"
                        "Status: ${appt['status']}",
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.deepPurple),
                      tooltip: "Update Status",
                      onPressed: () => _showStatusDialog(appt),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
