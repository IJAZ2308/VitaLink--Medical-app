// lib/patients/doctor_patients_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DoctorPatientsPage extends StatefulWidget {
  const DoctorPatientsPage({
    super.key,
    required String patientId,
    required String patientName,
    required String doctorId,
  });

  @override
  State<DoctorPatientsPage> createState() => _DoctorPatientsPageState();
}

class _DoctorPatientsPageState extends State<DoctorPatientsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'patients',
  );
  final User? _currentDoctor = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentDoctor == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Patients")),
      body: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("No patients found"));
          }

          final Map<dynamic, dynamic> raw =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          // Filter patients for this doctor
          final List<Map<String, dynamic>> patients = [];
          raw.forEach((key, value) {
            final Map<String, dynamic> patient = Map<String, dynamic>.from(
              value as Map,
            );
            if (patient['doctorId'] != null &&
                patient['doctorId'] == _currentDoctor.uid) {
              patient['id'] = key;
              patients.add(patient);
            }
          });

          if (patients.isEmpty) {
            return const Center(child: Text("No patients assigned to you"));
          }

          return ListView.builder(
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index];
              final id = patient['id'] as String;
              final name = patient['name'] ?? 'Unknown';
              final age = patient['age'] ?? '';
              final condition = patient['condition'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (age.isNotEmpty) Text("Age: $age"),
                      if (condition.isNotEmpty) Text("Condition: $condition"),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.green),
                          tooltip: "Edit",
                          onPressed: () => _editPatient(patient),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: "Delete",
                          onPressed: () => _deletePatient(id),
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
    );
  }

  // Edit patient info
  void _editPatient(Map<String, dynamic> patient) {
    final TextEditingController nameController = TextEditingController(
      text: patient['name'],
    );
    final TextEditingController ageController = TextEditingController(
      text: patient['age']?.toString() ?? '',
    );
    final TextEditingController conditionController = TextEditingController(
      text: patient['condition'],
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Patient"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: ageController,
                decoration: const InputDecoration(labelText: "Age"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: conditionController,
                decoration: const InputDecoration(labelText: "Condition"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await _dbRef.child(patient['id']).update({
                'name': nameController.text.trim(),
                'age': ageController.text.trim(),
                'condition': conditionController.text.trim(),
              });
              // ignore: use_build_context_synchronously
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // Delete patient
  void _deletePatient(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Patient"),
        content: const Text("Are you sure you want to delete this patient?"),
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
      await _dbRef.child(id).remove();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Patient deleted")));
      }
    }
  }
}
