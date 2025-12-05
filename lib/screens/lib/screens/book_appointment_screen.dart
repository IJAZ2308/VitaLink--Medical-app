import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'models/doctor.dart';
import 'package:intl/intl.dart';

class BookAppointmentScreen extends StatefulWidget {
  final Doctor doctor;

  const BookAppointmentScreen({
    super.key,
    required this.doctor,
    required List<Doctor> doctors,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  List<DateTime> _bookedSlots = [];

  @override
  void initState() {
    super.initState();
    _fetchBookedSlots();
  }

  Future<void> _fetchBookedSlots() async {
    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child('appointments')
        .orderByChild('doctorId')
        .equalTo(widget.doctor.uid)
        .get();

    List<DateTime> slots = [];
    if (snapshot.exists) {
      Map<dynamic, dynamic> appointments =
          snapshot.value as Map<dynamic, dynamic>;
      appointments.forEach((key, value) {
        if (value['dateTime'] != null) {
          slots.add(DateTime.parse(value['dateTime']));
        }
      });
    }

    if (!mounted) return;
    setState(() {
      _bookedSlots = slots;
    });
  }

  // -------------------------------
  // Convert String -> TimeOfDay
  // -------------------------------
  TimeOfDay _parseTime(String formatted) {
    final parts = formatted.split(" ");
    final hm = parts[0].split(":");

    int hour = int.parse(hm[0]);
    int minute = int.parse(hm[1]);
    final period = parts[1];

    if (period == "PM" && hour != 12) hour += 12;
    if (period == "AM" && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  List<String> _generateTimeSlots() {
    List<String> slots = [];
    for (int hour = 0; hour < 24; hour++) {
      final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final period = hour < 12 ? "AM" : "PM";
      slots.add('$formattedHour:00 $period');
    }
    return slots;
  }

  // -------------------------------
  // Correct slot check
  // -------------------------------
  bool _isSlotBooked(TimeOfDay time) {
    return _bookedSlots.any(
      (slot) =>
          slot.year == _selectedDate.year &&
          slot.month == _selectedDate.month &&
          slot.day == _selectedDate.day &&
          slot.hour == time.hour &&
          slot.minute == time.minute,
    );
  }

  Future<void> _bookAppointment() async {
    if (!_formKey.currentState!.validate() || _selectedTime == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appointmentRef = FirebaseDatabase.instance
          .ref()
          .child("appointments")
          .push();
      final appointmentId = appointmentRef.key;

      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (_isSlotBooked(_selectedTime!)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This slot is already booked!")),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      await appointmentRef.set({
        "id": appointmentId,
        "patientId": user.uid,
        "doctorId": widget.doctor.uid,
        "doctorName": "${widget.doctor.firstName} ${widget.doctor.lastName}",
        "specialization": widget.doctor.category,
        "reason": _reasonController.text.trim(),
        "dateTime": dateTime.toIso8601String(),
        "status": "pending",
        "createdAt": DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment booked successfully!")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final timeSlots = _generateTimeSlots();

    return Scaffold(
      appBar: AppBar(title: const Text("Book Appointment")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(doctor.profileImageUrl),
                    radius: 25,
                  ),
                  title: Text("${doctor.firstName} ${doctor.lastName}"),
                  subtitle: Text(
                    "${doctor.category} • ${doctor.qualification}",
                  ),
                  trailing: doctor.isVerified
                      ? const Icon(Icons.verified, color: Colors.green)
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: "Reason for Appointment",
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? "Enter a reason" : null,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Selected Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}",
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          _selectedDate = picked;
                          _selectedTime = null;
                        });
                      }
                    },
                    child: const Text("Pick Date"),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: timeSlots.length,
                  itemBuilder: (context, index) {
                    final timeString = timeSlots[index];
                    final slotTime = _parseTime(timeString);

                    final isBooked = _isSlotBooked(slotTime);
                    final isSelected = _selectedTime == slotTime;

                    return GestureDetector(
                      onTap: isBooked
                          ? null
                          : () {
                              if (!mounted) return;
                              setState(() {
                                _selectedTime = slotTime;
                              });
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isBooked
                              ? Colors.red[300]
                              : isSelected
                              ? Colors.blue
                              : Colors.green[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          timeString,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _bookAppointment,
                        child: const Text("Book Appointment"),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
