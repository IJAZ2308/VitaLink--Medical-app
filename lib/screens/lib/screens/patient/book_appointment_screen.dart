import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class BookAppointmentScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const BookAppointmentScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  BookAppointmentScreenState createState() => BookAppointmentScreenState();
}

class BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        selectedDate == null ||
        selectedTime == null) {
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    // create dateTime format field
    final fullDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    // get patient name
    final userSnap = await FirebaseDatabase.instance
        .ref()
        .child("users")
        .child(uid)
        .get();

    String patientName = userSnap.child("name").value?.toString() ?? "Unknown";

    final appointmentDate =
        "${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}";
    final appointmentTime = "${selectedTime!.hour}:${selectedTime!.minute}";

    final dbRef = FirebaseDatabase.instance.ref().child("appointments");

    final newAppointmentRef = dbRef.push();

    await newAppointmentRef.set({
      'id': newAppointmentRef.key,
      'patientId': uid,
      'patientName': patientName, // ADDED
      'doctorId': widget.doctorId,
      'doctorName': widget.doctorName,
      'specialization': "", // ADDED
      'date': appointmentDate,
      'time': appointmentTime,
      'dateTime': fullDateTime.toIso8601String(), // ADDED
      'reason': _reasonController.text.trim(),
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Appointment booked!")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Book Appointment with ${widget.doctorName}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: "Reason for visit",
                ),
                validator: (val) =>
                    val!.isEmpty ? 'Please enter a reason' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                child: Text(
                  selectedDate == null
                      ? "Choose Date"
                      : "${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}",
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
              ),
              ElevatedButton(
                child: Text(
                  selectedTime == null
                      ? "Choose Time"
                      : "${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}",
                ),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) setState(() => selectedTime = picked);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _submit, child: const Text("Submit")),
            ],
          ),
        ),
      ),
    );
  }
}
