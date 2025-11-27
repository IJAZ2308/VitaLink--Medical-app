import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dr_shahin_uk/services/notification_service.dart';

class ManageBedScreen extends StatefulWidget {
  const ManageBedScreen({super.key});

  @override
  State<ManageBedScreen> createState() => _ManageBedScreenState();
}

class _ManageBedScreenState extends State<ManageBedScreen> {
  final DatabaseReference _bedRef = FirebaseDatabase.instance.ref().child(
    'bedBookings',
  );

  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child(
    'users',
  );

  Future<void> _updateStatus(
    String bookingId,
    String newStatus,
    Map data,
  ) async {
    await _bedRef.child(bookingId).update({"status": newStatus});

    // Send notification to patient
    await _notifyPatient(
      patientUid: data['patientUid'],
      title: "Bed Booking Update",
      body: "Your bed booking for ${data['hospital']} is now: $newStatus",
    );
  }

  Future<void> _notifyPatient({
    required String patientUid,
    required String title,
    required String body,
  }) async {
    final snapshot = await _usersRef.child(patientUid).get();
    if (!snapshot.exists) return;

    final user = snapshot.value as Map<dynamic, dynamic>;
    final token = user["fcmToken"];

    if (token != null) {
      await NotificationService.sendPushNotification(
        fcmToken: token,
        title: title,
        body: body,
        data: {"type": "bed_update"},
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Approved":
        return Colors.green;
      case "Rejected":
        return Colors.red;
      case "Cancelled":
        return Colors.grey;
      default:
        return Colors.orange; // Pending
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Bed Bookings")),
      body: StreamBuilder(
        stream: _bedRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("No bed bookings found"));
          }

          final data = snapshot.data!.snapshot.value as Map;
          final bookings = data.entries.map((entry) {
            final bookingData = Map<String, dynamic>.from(entry.value);
            bookingData["id"] = entry.key;
            return bookingData;
          }).toList();

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final b = bookings[index];
              final status = b["status"] ?? "Pending";

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b["hospital"] ?? "Unknown Hospital",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text("Patient: ${b['patientName']}"),
                      Text("Bed Type: ${b['bedType']}"),
                      Text("Notes: ${b['notes']}"),
                      Text("Booking Date: ${b['bookingDate']}"),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text("Status: "),
                          Text(
                            status,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _statusColor(status),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),

                      /// ACTION BUTTONS
                      if (status == "Pending") ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () {
                                _updateStatus(b["id"], "Approved", b);
                              },
                              child: const Text("Approve"),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () {
                                _updateStatus(b["id"], "Rejected", b);
                              },
                              child: const Text("Reject"),
                            ),
                          ],
                        ),
                      ],

                      if (status == "Approved")
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                            onPressed: () {
                              _updateStatus(b["id"], "Cancelled", b);
                            },
                            child: const Text("Cancel Booking"),
                          ),
                        ),
                    ],
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
