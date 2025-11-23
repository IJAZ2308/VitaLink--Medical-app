/*// lib/screens/manage_appointments_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ManageAppointmentsScreen extends StatefulWidget {
  const ManageAppointmentsScreen({super.key});

  @override
  State<ManageAppointmentsScreen> createState() =>
      _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends State<ManageAppointmentsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'appointments',
  );

  final Map<String, bool> _expandedMap = {}; // Track which cards are expanded

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open URL")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Appointments")),
      body: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("No appointments found"));
          }

          final Map<dynamic, dynamic> appointmentsMap =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          // Only show appointments approved by doctor
          final List<Map<String, dynamic>> approvedAppointments =
              appointmentsMap.entries
                  .map((e) {
                    final data = Map<String, dynamic>.from(e.value);
                    data['appointmentId'] = e.key;
                    return data;
                  })
                  .where(
                    (data) =>
                        data['status'] != null &&
                        data['status'].toString().toLowerCase() == 'approved',
                  )
                  .toList()
                ..sort((a, b) {
                  final dateA =
                      DateTime.tryParse("${a['date']} ${a['time']}") ??
                      DateTime.now();
                  final dateB =
                      DateTime.tryParse("${b['date']} ${b['time']}") ??
                      DateTime.now();
                  return dateA.compareTo(dateB);
                });

          if (approvedAppointments.isEmpty) {
            return const Center(child: Text("No approved appointments yet"));
          }

          return ListView.builder(
            itemCount: approvedAppointments.length,
            itemBuilder: (context, index) {
              final data = approvedAppointments[index];
              final appointmentId = data['appointmentId'];
              final isExpanded = _expandedMap[appointmentId] ?? false;

              final formattedDate = data['date'] != null && data['time'] != null
                  ? DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(DateTime.parse("${data['date']} ${data['time']}"))
                  : 'N/A';

              final dateTime =
                  DateTime.tryParse("${data['date']} ${data['time']}") ??
                  DateTime.now();
              final isUpcoming = dateTime.isAfter(DateTime.now());

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 3,
                color: isUpcoming ? Colors.white : Colors.grey[200],
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _expandedMap[appointmentId] = !isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "${data['doctorName']} → ${data['patientName']}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isUpcoming
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Date & Time: $formattedDate",
                          style: TextStyle(
                            fontSize: 14,
                            color: isUpcoming ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        Text(
                          "Status: ${data['status'].toString().toUpperCase()}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                          ),
                        ),
                        if (isExpanded) ...[
                          const Divider(),
                          if (data['hospitalId'] != null)
                            Row(
                              children: [
                                const Icon(Icons.local_hospital, size: 16),
                                const SizedBox(width: 4),
                                Text("Hospital: ${data['hospitalId']}"),
                              ],
                            ),
                          if (data['specialty'] != null)
                            Row(
                              children: [
                                const Icon(Icons.medical_services, size: 16),
                                const SizedBox(width: 4),
                                Text("Specialty: ${data['specialty']}"),
                              ],
                            ),
                          if (data['website'] != null && data['website'] != '')
                            TextButton.icon(
                              onPressed: () => _openUrl(data['website']),
                              icon: const Icon(Icons.link),
                              label: const Text("Visit Hospital Website"),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
*/

// lib/screens/manage_appointments_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ManageAppointmentsScreen extends StatefulWidget {
  const ManageAppointmentsScreen({super.key});

  @override
  State<ManageAppointmentsScreen> createState() =>
      _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends State<ManageAppointmentsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'appointments',
  );

  final Map<String, bool> _expandedMap = {};

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open URL")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Appointments")),
      body: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("No appointments found"));
          }

          final Map<dynamic, dynamic> appointmentsMap =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          final List<Map<String, dynamic>> approvedAppointments =
              appointmentsMap.entries
                  .map((e) {
                    final data = Map<String, dynamic>.from(e.value);
                    data['appointmentId'] = e.key;
                    return data;
                  })
                  .where(
                    (data) =>
                        data['status'] != null &&
                        data['status'].toString().toLowerCase() == 'approved',
                  )
                  .toList()
                ..sort((a, b) {
                  final dateA =
                      DateTime.tryParse(a['dateTime'] ?? '') ?? DateTime.now();
                  final dateB =
                      DateTime.tryParse(b['dateTime'] ?? '') ?? DateTime.now();
                  return dateA.compareTo(dateB);
                });

          if (approvedAppointments.isEmpty) {
            return const Center(child: Text("No approved appointments yet"));
          }

          return ListView.builder(
            itemCount: approvedAppointments.length,
            itemBuilder: (context, index) {
              final data = approvedAppointments[index];
              final id = data['appointmentId'];
              final isExpanded = _expandedMap[id] ?? false;

              final dt = DateTime.tryParse(data['dateTime'] ?? '');
              final formattedDate = dt != null
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(dt)
                  : 'N/A';

              final isUpcoming = dt != null && dt.isAfter(DateTime.now());

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 3,
                color: isUpcoming ? Colors.white : Colors.grey[200],
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _expandedMap[id] = !isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "${data['doctorName']} → ${data['patientName']}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isUpcoming
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Date & Time: $formattedDate",
                          style: TextStyle(
                            fontSize: 14,
                            color: isUpcoming ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        Text(
                          "Status: ${data['status'].toString().toUpperCase()}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                          ),
                        ),
                        if (isExpanded) ...[
                          const Divider(),
                          if (data['hospitalId'] != null)
                            Row(
                              children: [
                                const Icon(Icons.local_hospital, size: 16),
                                const SizedBox(width: 4),
                                Text("Hospital: ${data['hospitalId']}"),
                              ],
                            ),
                          if (data['specialty'] != null)
                            Row(
                              children: [
                                const Icon(Icons.medical_services, size: 16),
                                const SizedBox(width: 4),
                                Text("Specialty: ${data['specialty']}"),
                              ],
                            ),
                          if (data['website'] != null &&
                              data['website'].toString().trim() != '')
                            TextButton.icon(
                              onPressed: () => _openUrl(data['website']),
                              icon: const Icon(Icons.link),
                              label: const Text("Visit Hospital Website"),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
