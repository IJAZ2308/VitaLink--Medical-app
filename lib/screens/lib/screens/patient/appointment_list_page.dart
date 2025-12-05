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

  String _selectedFilter = "Present"; // Today / Past / Future

  DateTime _safeParseDateTime(Map<dynamic, dynamic> data) {
    final dateStr = data['appointmentDate'] ?? '';
    final timeStr = data['timeSlot'] ?? '10:00 AM';
    DateTime date;
    try {
      date = DateFormat('yyyy-MM-dd').parse(dateStr);
    } catch (_) {
      date = DateTime.now();
    }

    DateTime time;
    try {
      time = DateFormat.jm().parse(timeStr);
    } catch (_) {
      time = DateTime(date.year, date.month, date.day, 10, 0);
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

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

  void _pickNewDateTime(String appointmentId) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate == null) return;

    TimeOfDay? pickedTime = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (pickedTime == null) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final formattedDate = DateFormat('yyyy-MM-dd').format(newDateTime);
    final formattedTime = DateFormat.jm().format(newDateTime);

    await _dbRef.child(appointmentId).update({
      'appointmentDate': formattedDate,
      'timeSlot': formattedTime,
      'status': 'pending',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Appointment rescheduled")));
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
                if (value != null) {
                  setState(() => _selectedFilter = value);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _dbRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text("No appointments found."));
                }

                final Map<dynamic, dynamic> data =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final List<Map<String, dynamic>> appointments = [];

                data.forEach((key, value) {
                  final appt = Map<String, dynamic>.from(value);
                  if (appt['patientId'] == _currentUser.uid) {
                    appt['id'] = key;
                    appointments.add(appt);
                  }
                });

                final today = DateTime.now();
                appointments.retainWhere((appt) {
                  final dt = _safeParseDateTime(appt);
                  final apptDay = DateTime(dt.year, dt.month, dt.day);
                  final todayDay = DateTime(today.year, today.month, today.day);
                  if (_selectedFilter == "Present") return apptDay == todayDay;
                  if (_selectedFilter == "Past") {
                    return apptDay.isBefore(todayDay);
                  }
                  if (_selectedFilter == "Future") {
                    return apptDay.isAfter(todayDay);
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
                    final formattedDate = DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(apptDateTime);
                    final status = _getStatus(appt, apptDateTime);
                    final statusColor = _getStatusColor(appt, apptDateTime);

                    final canReschedule = apptDateTime.isAfter(
                      DateTime.now().add(const Duration(hours: 1)),
                    );
                    final canCancel = apptDateTime.isAfter(DateTime.now());

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(appt['doctorName'] ?? 'Unknown Doctor'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Patient: ${appt['patientName']}"),
                            Text("Reason: ${appt['reason'] ?? 'N/A'}"),
                            Text("Date & Time: $formattedDate"),
                            Text(
                              "Status: $status",
                              style: TextStyle(color: statusColor),
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 96,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit_calendar,
                                  color: canReschedule
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                onPressed: canReschedule
                                    ? () => _pickNewDateTime(appt['id'])
                                    : null,
                                tooltip: "Reschedule",
                              ),
                              if (canCancel)
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _cancelAppointment(appt['id']),
                                  tooltip: "Cancel",
                                ),
                            ],
                          ),
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
