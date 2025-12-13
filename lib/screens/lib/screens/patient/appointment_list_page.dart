import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AppointmentListPage extends StatefulWidget {
  const AppointmentListPage({super.key});

  @override
  State<AppointmentListPage> createState() => _AppointmentListPageState();
}

class _AppointmentListPageState extends State<AppointmentListPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'appointments',
  );
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String _selectedFilter = "Present"; // Present / Past / Future

  /// Safely parse appointment date & time
  DateTime _safeParseDateTime(Map<dynamic, dynamic> data) {
    final dateStr = data['appointmentDate'] ?? '';
    final timeStr = data['timeSlot'] ?? '10:00 AM';

    DateTime date;
    try {
      date = DateFormat('yyyy-MM-dd').parse(dateStr);
    } catch (_) {
      try {
        date = DateFormat('dd MMM yyyy').parse(dateStr);
      } catch (_) {
        date = DateTime(2000); // fallback very old
      }
    }

    DateTime time;
    try {
      time = DateFormat.jm().parse(timeStr);
    } catch (_) {
      time = DateTime(date.year, date.month, date.day, 10, 0);
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Status for patient view
  String _getStatus(Map<dynamic, dynamic> data, DateTime apptDateTime) {
    if (data['visited'] == true) return "Visited";
    if (DateTime.now().isBefore(apptDateTime)) return "Pending";
    return "Not Visited";
  }

  Color _getStatusColor(Map<dynamic, dynamic> data, DateTime apptDateTime) {
    if (data['visited'] == true) return Colors.green;
    if (DateTime.now().isBefore(apptDateTime)) return Colors.orange;
    return Colors.red;
  }

  /// Cancel appointment
  Future<void> _cancelAppointment(String appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Appointment"),
        content: const Text(
          "Are you sure you want to cancel this appointment?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbRef.child(appointmentId).remove();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Appointment cancelled")));
      }
    }
  }

  /// Edit appointment: date/time + reason
  Future<void> _editAppointment(String appointmentId, Map apptData) async {
    DateTime currentDateTime = _safeParseDateTime(apptData);
    TextEditingController reasonController = TextEditingController(
      text: apptData['reason'] ?? '',
    );

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (pickedDate == null) return;

    TimeOfDay? pickedTime = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: TimeOfDay(
        hour: currentDateTime.hour,
        minute: currentDateTime.minute,
      ),
    );

    if (pickedTime == null) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Ask for reason
    bool reasonUpdated =
        await showDialog<bool>(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Update Reason"),
            content: TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: "Reason for appointment",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Save"),
              ),
            ],
          ),
        ) ??
        false;

    if (!reasonUpdated) return;

    await _dbRef.child(appointmentId).update({
      'appointmentDate': DateFormat('yyyy-MM-dd').format(newDateTime),
      'timeSlot': DateFormat.jm().format(newDateTime),
      'reason': reasonController.text.trim(),
      'visited': false,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment updated successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Appointments"),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedFilter,
              decoration: InputDecoration(
                labelText: "Filter Appointments",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: "Present",
                  child: Text("Today's Appointments"),
                ),
                DropdownMenuItem(
                  value: "Past",
                  child: Text("Past Appointments"),
                ),
                DropdownMenuItem(
                  value: "Future",
                  child: Text("Future Appointments"),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedFilter = value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Appointment list
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _dbRef.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text("No appointments found."));
                }

                final rawData =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final List<Map<String, dynamic>> appointments = [];

                rawData.forEach((key, value) {
                  final appt = Map<String, dynamic>.from(value);
                  if (appt['patientId'] == _currentUser.uid) {
                    appt['id'] = key;
                    appointments.add(appt);
                  }
                });

                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                appointments.retainWhere((appt) {
                  final dt = _safeParseDateTime(appt);
                  final apptDay = DateTime(dt.year, dt.month, dt.day);
                  if (_selectedFilter == "Present") return apptDay == today;
                  if (_selectedFilter == "Past") return apptDay.isBefore(today);
                  if (_selectedFilter == "Future") {
                    return apptDay.isAfter(today);
                  }
                  return true;
                });

                if (appointments.isEmpty) {
                  return const Center(
                    child: Text("No appointments for this selection."),
                  );
                }

                appointments.sort(
                  (a, b) =>
                      _safeParseDateTime(a).compareTo(_safeParseDateTime(b)),
                );

                return ListView.builder(
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final appt = appointments[index];
                    final apptDateTime = _safeParseDateTime(appt);

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(appt['doctorName'] ?? "Unknown Doctor"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Patient: ${appt['patientName'] ?? 'N/A'}"),
                            Text("Reason: ${appt['reason'] ?? 'N/A'}"),
                            Text(
                              "Date & Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(apptDateTime)}",
                            ),
                            Text(
                              "Status: ${_getStatus(appt, apptDateTime)}",
                              style: TextStyle(
                                color: _getStatusColor(appt, apptDateTime),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (apptDateTime.isAfter(
                              DateTime.now().add(const Duration(hours: 1)),
                            ))
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_calendar,
                                  color: Colors.green,
                                ),
                                onPressed: () =>
                                    _editAppointment(appt['id'], appt),
                                tooltip: "Edit Appointment",
                              ),
                            if (apptDateTime.isAfter(DateTime.now()))
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                onPressed: () => _cancelAppointment(appt['id']),
                                tooltip: "Cancel Appointment",
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
