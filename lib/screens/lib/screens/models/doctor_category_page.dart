import 'package:dr_shahin_uk/screens/lib/screens/models/doctor.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DoctorCategoryPage extends StatefulWidget {
  final String specialization;

  const DoctorCategoryPage({super.key, required this.specialization});

  @override
  State<DoctorCategoryPage> createState() => _DoctorCategoryPageState();
}

class _DoctorCategoryPageState extends State<DoctorCategoryPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'users',
  );
  List<Doctor> doctors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDoctorsBySpecialization();
  }

  Future<void> fetchDoctorsBySpecialization() async {
    try {
      final snapshot = await _dbRef.get();

      if (snapshot.value != null) {
        final allData = snapshot.value as Map<dynamic, dynamic>;
        final allDoctors = allData.entries
            .map(
              (entry) => Doctor.fromMap(entry.value, entry.key, id: entry.key),
            )
            .where(
              (doctor) =>
                  doctor.specialization.contains(widget.specialization) &&
                  doctor.isVerified &&
                  doctor.status == 'approved' &&
                  (doctor.category.isNotEmpty),
            )
            .toList();

        setState(() {
          doctors = allDoctors;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching doctors: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.specialization),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : doctors.isEmpty
          ? const Center(
              child: Text(
                'No doctors available for this specialization',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                final doctor = doctors[index];
                return DoctorCard(
                  doctor: doctor,
                  onTap: () {
                    // Navigate to Doctor Detail / Booking page
                  },
                );
              },
            ),
    );
  }
}

class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback? onTap;

  const DoctorCard({super.key, required this.doctor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundImage: doctor.profileImageUrl.isNotEmpty
              ? NetworkImage(doctor.profileImageUrl)
              : const AssetImage('assets/images/default_doctor.png')
                    as ImageProvider,
          radius: 26,
        ),
        title: Text(
          doctor.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${doctor.qualification} • ${doctor.yearsOfExperience} yrs exp',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            Text(
              '${doctor.workingAt}, ${doctor.city}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: doctor.averageRating > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  Text(
                    doctor.averageRating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              )
            : const SizedBox(),
      ),
    );
  }
}
