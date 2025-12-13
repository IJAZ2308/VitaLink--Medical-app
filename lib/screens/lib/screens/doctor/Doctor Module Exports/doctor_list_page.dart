import 'package:dr_shahin_uk/screens/lib/screens/book_appointment_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/doctor.dart';

class DoctorListPage extends StatefulWidget {
  const DoctorListPage({super.key, required bool selectMode});

  @override
  State<DoctorListPage> createState() => _DoctorListPageState();
}

class _DoctorListPageState extends State<DoctorListPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    "doctors",
  );

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  List<Doctor> _doctors = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  final List<Map<String, String>> _categories = [
    {'name': 'All', 'image': 'assets/images/grid.png'},
    {'name': 'Child', 'image': 'assets/images/child.png'},
    {'name': 'Dental', 'image': 'assets/images/dental.png'},
    {'name': 'ENT', 'image': 'assets/images/ent.png'},
    {'name': 'Eye', 'image': 'assets/images/eye.png'},
    {'name': 'Heart', 'image': 'assets/images/heart.png'},
    {'name': 'Neuro', 'image': 'assets/images/neuro.png'},
    {'name': 'Surgery', 'image': 'assets/images/surgery.png'},
    {'name': 'Ortho', 'image': 'assets/images/ortho.png'},
    {'name': 'Plastic', 'image': 'assets/images/plastic.png'},
    {'name': 'Gyn', 'image': 'assets/images/gyn.png'},
    {'name': 'Onco', 'image': 'assets/images/onco.png'},
    {'name': 'Urology', 'image': 'assets/images/urology.png'},
    {'name': 'Public', 'image': 'assets/images/publichealth.png'},
    {'name': 'Work', 'image': 'assets/images/work.png'},
    {'name': 'Vascular', 'image': 'assets/images/vascular.png'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  /// 🔥 REAL-TIME DOCTOR FETCH (FIXED)
  void _fetchDoctors() {
    _dbRef.onValue.listen((event) {
      List<Doctor> tmpDoctors = [];

      if (event.snapshot.value != null) {
        final values = event.snapshot.value as Map<dynamic, dynamic>;

        values.forEach((key, value) {
          if (value['status'] == 'approved') {
            tmpDoctors.add(Doctor.fromMap(value, key, id: null));
          }
        });
      }

      setState(() {
        _doctors = tmpDoctors;
        _isLoading = false;
      });
    });
  }

  void _openAppointmentScreen(Doctor doctor) {
    if (_currentUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BookAppointmentScreen(doctors: [doctor], doctor: doctor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredDoctors = _selectedCategory == 'All'
        ? _doctors
        : _doctors
              .where(
                (d) => d.specialization.any(
                  (s) =>
                      s.toLowerCase().contains(_selectedCategory.toLowerCase()),
                ),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Appointment"),
        backgroundColor: const Color(0xff0064FA),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a specialization',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),

                  // Horizontal Category Scroll
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = cat['name']!;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                Container(
                                  height: 60,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: _selectedCategory == cat['name']
                                        ? Colors.blue[50]
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedCategory == cat['name']
                                          ? Colors.blue
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.asset(
                                      cat['image']!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  cat['name']!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: filteredDoctors.isEmpty
                        ? const Center(child: Text("No doctors available"))
                        : ListView.builder(
                            itemCount: filteredDoctors.length,
                            itemBuilder: (context, index) {
                              final doctor = filteredDoctors[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundImage: AssetImage(
                                      'assets/images/doctor_avatar.png',
                                    ),
                                  ),
                                  title: Text(
                                    '${doctor.firstName} ${doctor.lastName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    doctor.specialization.join(', '),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xff0064FA),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _openAppointmentScreen(doctor),
                                    child: const Text("Book"),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
