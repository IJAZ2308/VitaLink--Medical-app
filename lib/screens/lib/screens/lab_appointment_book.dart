import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:dr_shahin_uk/services/notification_service.dart'; // ✅ ADDED

class LabAppointmentPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const LabAppointmentPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required String doctorId,
    required String doctorName,
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

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedTest;
  String? _selectedLabDoctorId;
  String? _selectedLabDoctorName;

  final TextEditingController _reasonController = TextEditingController();

  final List<String> _labTests = [
    "Blood's Imaging Emitting Sound Effects",
    "X-Ray",
    "MRI",
    "Ultrasound",
    "CT Scan",
    "Other",
  ];

  List<Map<String, String>> _labDoctors = [];

  @override
  void initState() {
    super.initState();
    _fetchLabDoctors();
  }

  void _fetchLabDoctors() async {
    final snapshot = await _doctorsRef.get();

    List<Map<String, String>> loadedDoctors = [];

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value['type'] == 'lab') {
          loadedDoctors.add({'id': key, 'name': value['name'] ?? 'Unknown'});
        }
      });
    }

    setState(() {
      _labDoctors = loadedDoctors;
    });
  }

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  void _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  void _bookLabAppointment() async {
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
        const SnackBar(
          content: Text("Please provide a reason or select a lab test"),
        ),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final timeStr = _selectedTime!.format(context);

    final newApptRef = _dbRef.push();
    await newApptRef.set({
      'patientId': widget.patientId,
      'patientName': widget.patientName,
      'doctorId': _selectedLabDoctorId,
      'doctorName': _selectedLabDoctorName,
      'appointmentDate': dateStr,
      'timeSlot': timeStr,
      'testType': _selectedTest ?? "Lab Test",
      'reason': _reasonController.text,
      'status': 'Pending',
      'createdAt': DateTime.now().toIso8601String(),
    });

    // -----------------------------------------------------------
    // 🔔 PUSH NOTIFICATION BLOCK ADDED (NO STRUCTURE CHANGED)
    // -----------------------------------------------------------
    final doctorTokenSnapshot = await FirebaseDatabase.instance
        .ref()
        .child("doctors/$_selectedLabDoctorId/fcmToken")
        .get();

    if (doctorTokenSnapshot.exists) {
      final doctorToken = doctorTokenSnapshot.value.toString();

      await PushNotificationService.sendPushMessage(
        doctorToken,
        "New Lab Appointment",
        "${widget.patientName} booked a lab appointment on $dateStr at $timeStr.",
      );
    }
    // -----------------------------------------------------------

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Lab appointment booked successfully")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Book Lab Appointment")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(title: Text("Patient: ${widget.patientName}")),
            const SizedBox(height: 16),

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
