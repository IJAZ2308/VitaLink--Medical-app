// lib/appointments/doctor_appointments_realtime.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class DoctorAppointmentsRealtimePage extends StatefulWidget {
  const DoctorAppointmentsRealtimePage({super.key});

  @override
  State<DoctorAppointmentsRealtimePage> createState() =>
      _DoctorAppointmentsRealtimePageState();
}

class _DoctorAppointmentsRealtimePageState
    extends State<DoctorAppointmentsRealtimePage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'appointments',
  );
  final User? _currentDoctor = FirebaseAuth.instance.currentUser;

  String _selectedFilter = "Present"; // Present / Past / Future

  /// Safely parse the stored dateTime (ISO string) into DateTime
  DateTime _safeParseDateTime(String? iso) {
    try {
      return DateTime.parse(iso!).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  /// Update status in Realtime DB (Pending, Completed, Cancelled)
  Future<void> _updateStatus(String appointmentId, String newStatus) async {
    if (newStatus == 'Confirmed') {
      // For Confirmed, update confirmedByDoctor as well
      await _dbRef.child(appointmentId).update({
        'status': 'Confirmed',
        'confirmedByDoctor': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } else {
      await _dbRef.child(appointmentId).update({
        'status': newStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Status updated to $newStatus")));
    }
  }

  /// Reschedule: pick new date/time then update the appointment's dateTime
  Future<void> _rescheduleAppointment(String appointmentId) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    await _dbRef.child(appointmentId).update({
      'dateTime': newDateTime.toIso8601String(),
      'status': 'Pending',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Appointment rescheduled")));
    }
  }

  /// Cancel appointment (delete node)
  Future<void> _cancelAppointment(String appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Appointment"),
        content: const Text(
          "Are you sure you want to cancel this appointment?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbRef.child(appointmentId).update({
        'status': 'Cancelled',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Appointment cancelled")));
      }
    }
  }

  /// Build list of status action choices
  List<PopupMenuEntry<String>> _statusMenuItems() {
    return const [
      PopupMenuItem(value: 'Pending', child: Text('Pending')),
      PopupMenuItem(value: 'Confirmed', child: Text('Confirmed')),
      PopupMenuItem(value: 'Completed', child: Text('Completed')),
      PopupMenuItem(value: 'Cancelled', child: Text('Cancelled')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_currentDoctor == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Patients' Appointments")),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Filter dropdown (Present / Past / Future)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedFilter,
              decoration: InputDecoration(
                labelText: "Select Appointment Type",
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
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedFilter = val);
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Stream of appointments from Realtime DB
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _dbRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text("No appointments found"));
                }

                final Map<dynamic, dynamic> raw =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                // Collect only appointments for this doctor
                final List<Map<String, dynamic>> appointments = [];
                raw.forEach((key, value) {
                  final Map<String, dynamic> appt = Map<String, dynamic>.from(
                    value as Map,
                  );
                  final matchesDoctor =
                      (appt['doctorId'] != null &&
                          appt['doctorId'] == _currentDoctor.uid) ||
                      (appt['doctorName'] != null &&
                          appt['doctorName'] == _currentDoctor.displayName);

                  if (matchesDoctor) {
                    appt['id'] = key;
                    appointments.add(appt);
                  }
                });

                if (appointments.isEmpty) {
                  return const Center(
                    child: Text("No appointments for this doctor"),
                  );
                }

                // Filter by Present / Past / Future
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                final filtered = appointments.where((appt) {
                  final dt = _safeParseDateTime(appt['dateTime'] as String?);
                  final day = DateTime(dt.year, dt.month, dt.day);
                  if (_selectedFilter == 'Present') return day == today;
                  if (_selectedFilter == 'Past') return day.isBefore(today);
                  if (_selectedFilter == 'Future') return day.isAfter(today);
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text("No appointments for this selection"),
                  );
                }

                // Sort by date/time ascending
                filtered.sort((a, b) {
                  final da = _safeParseDateTime(a['dateTime'] as String?);
                  final db = _safeParseDateTime(b['dateTime'] as String?);
                  return da.compareTo(db);
                });

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final appt = filtered[index];
                    final id = appt['id'] as String;
                    final dt = _safeParseDateTime(appt['dateTime'] as String?);
                    final formatted = _formatDateTime(dt);
                    final status = (appt['status'] ?? 'Pending') as String;
                    final reason = appt['reason'] ?? '';
                    final patientName =
                        appt['patientName'] ?? 'Unknown Patient';
                    final doctorName = appt['doctorName'] ?? '';

                    // status color mapping
                    Color statusColor;
                    switch (status.toLowerCase()) {
                      case 'completed':
                        statusColor = Colors.green;
                        break;
                      case 'confirmed':
                        statusColor = Colors.blue;
                        break;
                      case 'cancelled':
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.orange;
                    }

                    // Disable actions if cancelled/completed
                    final bool canCancel =
                        dt.isAfter(DateTime.now()) &&
                        status.toLowerCase() != 'cancelled';
                    final bool canReschedule =
                        dt.isAfter(
                          DateTime.now().add(const Duration(hours: 1)),
                        ) &&
                        status.toLowerCase() != 'cancelled' &&
                        status.toLowerCase() != 'completed';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: const Icon(Icons.person, color: Colors.teal),
                        ),
                        title: Text(
                          patientName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              "Reason: $reason",
                              style: const TextStyle(height: 1.3),
                            ),
                            Text(
                              "Doctor: $doctorName",
                              style: const TextStyle(height: 1.3),
                            ),
                            Text(
                              "When: $formatted",
                              style: const TextStyle(height: 1.3),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                "Status: $status",
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 120,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // status menu
                              Align(
                                alignment: Alignment.centerRight,
                                child: PopupMenuButton<String>(
                                  tooltip: "Change status",
                                  onSelected: (value) =>
                                      _updateStatus(id, value),
                                  itemBuilder: (_) => _statusMenuItems(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.more_vert,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // action buttons row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_calendar,
                                      color: canReschedule
                                          ? Colors.green.shade400
                                          : Colors.grey,
                                    ),
                                    onPressed: canReschedule
                                        ? () => _rescheduleAppointment(id)
                                        : null,
                                    tooltip: "Reschedule",
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.cancel,
                                      color: canCancel
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                    onPressed: canCancel
                                        ? () => _cancelAppointment(id)
                                        : null,
                                    tooltip: "Cancel",
                                  ),
                                ],
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
