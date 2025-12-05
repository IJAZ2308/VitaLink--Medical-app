import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:dr_shahin_uk/services/notification_service.dart';

class LabAppointmentPage extends StatefulWidget {
  final String doctorId; // Doctor who is booking
  final String doctorName; // Doctor who is booking

  const LabAppointmentPage({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required patientId,
    required String patientName,
  });

  @override
  State<LabAppointmentPage> createState() => _LabAppointmentPageState();
}

class _LabAppointmentPageState extends State<LabAppointmentPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'labAppointments',
  );

  final DatabaseReference _doctorsRef = FirebaseDatabase.instance.ref().child(
    'doctors',
  );

  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child(
    'users',
  );

  // -------------------------------------------------------------------
  // Variables
  // -------------------------------------------------------------------
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedTest;

  String? _selectedLabDoctorId;
  String? _selectedLabDoctorName;

  String? _selectedPatientId;
  String? _selectedPatientName;

  final TextEditingController _reasonController = TextEditingController();

  // Lab Test Types
  final List<String> _labTests = [
    "Blood's Imaging Emitting Sound Effects",
    "X-Ray",
    "MRI",
    "Ultrasound",
    "CT Scan",
    "Other",
  ];

  List<Map<String, String>> _labDoctors = [];
  List<Map<String, String>> _patients = [];

  @override
  void initState() {
    super.initState();
    _fetchLabDoctors();
    _fetchPatients();
  }

  // -------------------------------------------------------------------
  // Fetch lab doctors where doctorRole = labdoctor
  // -------------------------------------------------------------------
  void _fetchLabDoctors() async {
    final snapshot = await _doctorsRef.get();

    List<Map<String, String>> loadedDoctors = [];

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      data.forEach((key, value) {
        final role = value['doctorRole']?.toString().toLowerCase();

        if (role == 'labdoctor') {
          loadedDoctors.add({
            'id': key,
            'name': value['firstName'] ?? 'Unknown',
          });
        }
      });
    }

    setState(() {
      _labDoctors = loadedDoctors;
    });
  }

  // -------------------------------------------------------------------
  // Fetch only users with role = patient
  // -------------------------------------------------------------------
  void _fetchPatients() async {
    final snapshot = await _usersRef.get();

    List<Map<String, String>> loadedPatients = [];

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      data.forEach((key, value) {
        final role = value['role']?.toString().toLowerCase();

        if (role == 'patient') {
          loadedPatients.add({
            'id': key,
            'name': value['name'] ?? 'Unnamed Patient',
          });
        }
      });
    }

    setState(() {
      _patients = loadedPatients;
    });
  }

  // -------------------------------------------------------------------
  // Date Picker
  // -------------------------------------------------------------------
  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  // -------------------------------------------------------------------
  // Time Picker
  // -------------------------------------------------------------------
  void _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  // -------------------------------------------------------------------
  // BOOK APPOINTMENT
  // -------------------------------------------------------------------
  void _bookLabAppointment() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a patient")));
      return;
    }

    if (_selectedLabDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Lab Doctor")),
      );
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select date and time")),
      );
      return;
    }

    if ((_reasonController.text.isEmpty) && (_selectedTest == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Provide a reason or select a test type")),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final timeStr = _selectedTime!.format(context);

    final newApptRef = _dbRef.push();

    // -------------------------------------------------------------------
    // Save appointment
    // -------------------------------------------------------------------
    await newApptRef.set({
      'patientId': _selectedPatientId,
      'patientName': _selectedPatientName,

      'bookedByDoctorId': widget.doctorId,
      'bookedByDoctorName': widget.doctorName,

      'labDoctorId': _selectedLabDoctorId,
      'labDoctorName': _selectedLabDoctorName,

      'appointmentDate': dateStr,
      'timeSlot': timeStr,
      'testType': _selectedTest ?? "Lab Test",
      'reason': _reasonController.text,
      'status': 'Pending',
      'createdAt': DateTime.now().toIso8601String(),
    });

    // -------------------------------------------------------------------
    // Send push notification to Lab Doctor
    // -------------------------------------------------------------------
    final doctorTokenSnapshot = await FirebaseDatabase.instance
        .ref()
        .child("doctors/$_selectedLabDoctorId/fcmToken")
        .get();

    if (doctorTokenSnapshot.exists) {
      final doctorToken = doctorTokenSnapshot.value.toString();

      await PushNotificationService.sendPushMessage(
        doctorToken,
        "New Lab Appointment",
        "$_selectedPatientName has a lab appointment on $dateStr at $timeStr.",
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Lab appointment booked successfully")),
    );

    Navigator.pop(context);
  }

  // -------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Book Lab Appointment")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ------------------------------------------------------------
            // PATIENT DROPDOWN
            // ------------------------------------------------------------
            DropdownButtonFormField<String>(
              value: _selectedPatientId,
              hint: const Text("Select Patient"),
              items: _patients.map((p) {
                return DropdownMenuItem(
                  value: p['id'],
                  child: Text(p['name']!),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedPatientId = val;
                  _selectedPatientName = _patients.firstWhere(
                    (p) => p['id'] == val,
                  )['name'];
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 16),

            // ------------------------------------------------------------
            // LAB DOCTOR DROPDOWN
            // ------------------------------------------------------------
            DropdownButtonFormField<String>(
              value: _selectedLabDoctorId,
              hint: const Text("Select Lab Doctor"),
              items: _labDoctors.map((doc) {
                return DropdownMenuItem(
                  value: doc['id'],
                  child: Text(doc['name']!),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedLabDoctorId = val;
                  _selectedLabDoctorName = _labDoctors.firstWhere(
                    (doc) => doc['id'] == val,
                  )['name'];
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 16),

            // ------------------------------------------------------------
            // LAB TEST DROPDOWN
            // ------------------------------------------------------------
            DropdownButtonFormField<String>(
              value: _selectedTest,
              hint: const Text("Select Lab Test (optional)"),
              items: _labTests.map((test) {
                return DropdownMenuItem(value: test, child: Text(test));
              }).toList(),
              onChanged: (val) => setState(() => _selectedTest = val),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 16),

            // ------------------------------------------------------------
            // REASON FIELD
            // ------------------------------------------------------------
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Reason for Lab Test (optional)",
                border: OutlineInputBorder(),
                hintText: "Enter details if any",
              ),
            ),

            const SizedBox(height: 16),

            // ------------------------------------------------------------
            // DATE & TIME PICKERS
            // ------------------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickDate,
                    child: Text(
                      _selectedDate != null
                          ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                          : "Select Date",
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickTime,
                    child: Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : "Select Time",
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ------------------------------------------------------------
            // SUBMIT BUTTON
            // ------------------------------------------------------------
            ElevatedButton(
              onPressed: _bookLabAppointment,
              child: const Text("Book Lab Appointment"),
            ),
          ],
        ),
      ),
    );
  }
}
