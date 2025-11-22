import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class LabAppointmentPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;

  const LabAppointmentPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<LabAppointmentPage> createState() => _LabAppointmentPageState();
}

class _LabAppointmentPageState extends State<LabAppointmentPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'labAppointments',
  );

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedTest;

  final TextEditingController _reasonController = TextEditingController();

  final List<String> _labTests = [
    "Blood Test",
    "X-Ray",
    "MRI",
    "Ultrasound",
    "CT Scan",
    "Other",
  ];

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
      'doctorId': widget.doctorId,
      'doctorName': widget.doctorName,
      'appointmentDate': dateStr,
      'timeSlot': timeStr,
      'testType': _selectedTest ?? "Lab Test",
      'reason': _reasonController.text,
      'status': 'Pending',
      'createdAt': DateTime.now().toIso8601String(),
    });

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
            ListTile(
              title: Text("Patient: ${widget.patientName}"),
              subtitle: Text("Doctor: ${widget.doctorName}"),
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
