import 'dart:convert'; // for JSON encoding
import 'package:dr_shahin_uk/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class ManageHospitalsScreen extends StatefulWidget {
  const ManageHospitalsScreen({super.key});

  @override
  State<ManageHospitalsScreen> createState() => _ManageHospitalsScreenState();
}

class _ManageHospitalsScreenState extends State<ManageHospitalsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'hospitals',
  );

  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child(
    'users',
  );

  @override
  void initState() {
    super.initState();
    _migrateHospitals();
  }

  Future<void> _migrateHospitals() async {
    final snapshot = await _dbRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map<dynamic, dynamic>;
    for (var entry in data.entries) {
      final hospitalId = entry.key;
      final hospitalData = Map<String, dynamic>.from(entry.value);
      final Map<String, dynamic> updates = {};

      if (!hospitalData.containsKey('availableBeds')) {
        updates['availableBeds'] = 0;
      }
      if (!hospitalData.containsKey('phone')) updates['phone'] = "N/A";
      if (!hospitalData.containsKey('website')) updates['website'] = "";

      if (updates.isNotEmpty) {
        await _dbRef.child(hospitalId).update(updates);
      }
    }
  }

  Future<void> _deleteHospital(String hospitalId) async {
    final hospitalSnapshot = await _dbRef.child(hospitalId).get();
    if (hospitalSnapshot.exists) {
      final hospitalData = Map<String, dynamic>.from(
        hospitalSnapshot.value as Map,
      );
      final name = hospitalData['name'] ?? 'a hospital';

      await _dbRef.child(hospitalId).remove();

      await _notifyLSOUsers(
        title: 'Hospital Removed',
        body: 'The hospital "$name" has been removed from the system.',
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // 🔥 FIXED: Geocoding with error handling (no more freezing)
  Future<Map<String, double>> _getLatLng(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      return {
        "lat": locations.first.latitude,
        "lng": locations.first.longitude,
      };
    } catch (e) {
      if (kDebugMode) {
        print("Geocoding Error: $e");
      }
      return {"lat": 0.0, "lng": 0.0};
    }
  }

  void _showAddHospitalDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final websiteController = TextEditingController();
    final bedsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Hospital"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Hospital Name"),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: "Address"),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone"),
              ),
              TextField(
                controller: websiteController,
                decoration: const InputDecoration(labelText: "Website"),
              ),
              TextField(
                controller: bedsController,
                decoration: const InputDecoration(labelText: "Available Beds"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                final name = nameController.text.trim();
                final address = addressController.text.trim();
                final phone = phoneController.text.trim();
                final website = websiteController.text.trim();
                final beds = int.tryParse(bedsController.text.trim()) ?? 0;

                if (name.isEmpty || address.isEmpty) return;

                final latlng = await _getLatLng(address);

                final hospitalData = {
                  "name": name,
                  "address": address,
                  "phone": phone.isNotEmpty ? phone : "N/A",
                  "website": website,
                  "availableBeds": beds,
                  "lat": latlng["lat"],
                  "lng": latlng["lng"],
                };

                await _dbRef.push().set(hospitalData);

                await _notifyLSOUsers(
                  title: 'New Hospital Added',
                  body: json.encode({
                    'message':
                        'The hospital "$name" has been added successfully.',
                  }),
                );

                // ignore: use_build_context_synchronously
                Navigator.of(ctx).pop();
              } catch (e) {
                if (kDebugMode) {
                  print("Save Error: $e");
                }
              }
            },
            child: const Text("Save"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Future<void> _notifyLSOUsers({
    required String title,
    required String body,
  }) async {
    final snapshot = await _usersRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map<dynamic, dynamic>;
    for (var userEntry in data.entries) {
      final user = userEntry.value as Map<dynamic, dynamic>;

      if (user['role'] == 'LSO' && user['fcmToken'] != null) {
        final token = user['fcmToken'].toString();

        await NotificationService.sendPushNotification(
          fcmToken: token,
          title: title,
          body: body,
          data: {
            'payload': json.encode({'title': title, 'body': body}),
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Hospitals")),
      body: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("No hospitals found"));
          }

          final Map<dynamic, dynamic> hospitalsMap =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          final List<Map<dynamic, dynamic>> hospitals = hospitalsMap.entries
              .map((e) {
                final data = Map<String, dynamic>.from(e.value);
                data['hospitalId'] = e.key;
                return data;
              })
              .toList();

          return ListView.builder(
            itemCount: hospitals.length,
            itemBuilder: (context, index) {
              final data = hospitals[index];
              final beds = data['availableBeds']?.toString() ?? "N/A";
              final phone = data['phone']?.toString() ?? "N/A";
              final website = data['website']?.toString() ?? "";
              final lat = data['lat'];
              final lng = data['lng'];

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: data['imageUrl'] != null
                      ? Image.network(
                          data['imageUrl'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.local_hospital, color: Colors.red),
                  title: Text(data['name'] ?? "Unknown"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Available Beds: $beds"),
                      Text("Phone: $phone"),
                      if (website.isNotEmpty)
                        TextButton(
                          onPressed: () => _openUrl(website),
                          child: const Text(
                            "Visit Website",
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      if (lat != null && lng != null)
                        Text("Location: $lat, $lng"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => _deleteHospital(data['hospitalId']),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHospitalDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
