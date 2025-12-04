import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PatLabAppointment extends StatefulWidget {
  const PatLabAppointment({super.key});

  @override
  State<PatLabAppointment> createState() => _PatLabAppointmentState();
}

class _PatLabAppointmentState extends State<PatLabAppointment> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _labTestsDb =
      FirebaseDatabase.instance.ref().child('labAppointment');
  final DatabaseReference _usersDb =
      FirebaseDatabase.instance.ref().child('users');

  List<Map<String, String>> _labAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatientLabAppointments();
  }

  Future<void> _fetchPatientLabAppointments() async {
    setState(() => _isLoading = true);
    final patientId = _auth.currentUser!.uid;

    try {
      // Fetch lab appointments for this patient
      final snapshot =
          await _labTestsDb.orderByChild('patientId').equalTo(patientId).get();

      final List<Map<String, String>> loadedAppointments = [];

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        for (var key in data.keys) {
          final test = Map<String, dynamic>.from(data[key]);

          final requestingDoctorId = test['requestingDoctorId'] ?? '';
          final labDoctorId = test['labDoctorId'] ?? '';

          if (requestingDoctorId.isEmpty) continue;

          // Fetch requesting doctor info
          final docSnap = await _usersDb.child(requestingDoctorId).get();
          if (!docSnap.exists) continue;

          final docData = Map<String, dynamic>.from(docSnap.value as Map);

          // Only include if requesting doctor is consultingDoctor
          if (docData['doctorRole'] != 'consultingDoctor') continue;

          final requestingDoctorName = docData['name'] ?? 'Doctor';

          // Fetch lab doctor info
          String labDoctorName = 'Unknown';
          if (labDoctorId.isNotEmpty) {
            final labSnap = await _usersDb.child(labDoctorId).get();
            if (labSnap.exists) {
              final labData = Map<String, dynamic>.from(labSnap.value as Map);
              labDoctorName = labData['name'] ?? 'Lab Doctor';
            }
          }

          loadedAppointments.add({
            'labDoctorName': labDoctorName,
            'requestingDoctorName': requestingDoctorName,
            'status': test['status'] ?? 'Pending',
            'date': test['date'] ?? '',
            'time': test['time'] ?? '',
            'testType': test['testType'] ?? '',
          });
        }
      }

      setState(() {
        _labAppointments = loadedAppointments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Optionally show an error
      debugPrint("Error fetching lab appointments: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Lab Appointments"),
        backgroundColor: const Color(0xff0064FA),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _labAppointments.isEmpty
              ? const Center(child: Text("No lab appointments booked"))
              : ListView.builder(
                  itemCount: _labAppointments.length,
                  itemBuilder: (context, index) {
                    final appt = _labAppointments[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: ListTile(
                        title: Text(
                          "Lab Doctor: ${appt['labDoctorName']} (${appt['testType']})",
                        ),
                        subtitle: Text(
                          "Requested by: ${appt['requestingDoctorName']}\n"
                          "Date: ${appt['date']} ${appt['time']}\n"
                          "Status: ${appt['status']}",
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
