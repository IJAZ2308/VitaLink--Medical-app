import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../chat/chat_screen.dart';
import '../../models/patient.dart';

class DoctorChatlistPage extends StatefulWidget {
  const DoctorChatlistPage({super.key});

  @override
  State<DoctorChatlistPage> createState() => _DoctorChatlistPageState();
}

class _DoctorChatlistPageState extends State<DoctorChatlistPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _chatListDb = FirebaseDatabase.instance.ref().child(
    'ChatList',
  );
  final DatabaseReference _patientsDb = FirebaseDatabase.instance.ref().child(
    'users',
  );

  List<Patient> _chatList = [];
  bool _isLoading = true;
  late String doctorId;

  @override
  void initState() {
    super.initState();
    doctorId = _auth.currentUser?.uid ?? '';
    _fetchChatList();
  }

  Future<void> _fetchChatList() async {
    if (doctorId.isEmpty) return;

    try {
      final DataSnapshot snapshot = await _chatListDb.child(doctorId).get();
      List<Patient> tempChatList = [];

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> chatMap =
            snapshot.value as Map<dynamic, dynamic>;

        for (var patientId in chatMap.keys) {
          final patientSnapshot = await _patientsDb.child(patientId).get();

          if (patientSnapshot.exists && patientSnapshot.value != null) {
            final patientData = Map<String, dynamic>.from(
              patientSnapshot.value as Map,
            );

            // Only include patients whose consulting doctor exists
            if (patientData.containsKey('consultingDoctorId') &&
                (patientData['consultingDoctorId'] as String).isNotEmpty) {
              // Optionally, you can also check if the consulting doctor is approved/verified
              final consultingDoctorId =
                  patientData['consultingDoctorId'] as String;
              final consultingDoctorSnapshot = await _patientsDb
                  .child(consultingDoctorId)
                  .get();

              if (consultingDoctorSnapshot.exists &&
                  consultingDoctorSnapshot.value != null) {
                final doctorData = Map<String, dynamic>.from(
                  consultingDoctorSnapshot.value as Map,
                );
                if (doctorData['doctorRole'] == 'consultingDoctor') {
                  tempChatList.add(Patient.fromMap(patientData));
                }
              }
            }
          }
        }
      }

      setState(() {
        _chatList = tempChatList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error fetching chat list: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats with Patients'),
        backgroundColor: const Color(0xff0064FA),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatList.isEmpty
          ? const Center(
              child: Text('No chats available', style: TextStyle(fontSize: 16)),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _chatList.length,
              itemBuilder: (context, index) {
                final patient = _chatList[index];
                final patientName = '${patient.firstName} ${patient.lastName}';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade100,
                      child: const Icon(Icons.person, color: Colors.deepPurple),
                    ),
                    title: Text(
                      patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    trailing: const Icon(Icons.chat, color: Colors.blue),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            doctorId: doctorId,
                            patientId: patient.uid,
                            patientName: patientName,
                            doctorName: '', // optional
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
