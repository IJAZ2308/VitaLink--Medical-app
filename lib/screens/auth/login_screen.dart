import 'package:dr_shahin_uk/screens/auth/register_selection.dart';
import 'package:dr_shahin_uk/screens/lib/screens/admin_dashboard.dart';
import 'package:dr_shahin_uk/screens/lib/screens/doctor_dashboard_lab.dart';
import 'package:dr_shahin_uk/screens/lib/screens/doctor_dashboard_consulting.dart';
import 'package:dr_shahin_uk/screens/lib/screens/patient_dashboard.dart';
import 'package:dr_shahin_uk/screens/shared/verify_pending.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dr_shahin_uk/services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool _isLoading = false;
  bool _obscureText = true;
  String error = "";

  /// -------------------- LOGIN --------------------
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      error = "";
    });

    try {
      // Firebase Auth sign in
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        setState(() => error = "Login failed. UID not found.");
        return;
      }

      /// ------------------ DOCTOR CHECK ------------------
      final doctorSnapshot = await _db.child("doctors").child(uid).get();
      if (doctorSnapshot.exists) {
        final doctorData = Map<String, dynamic>.from(
          doctorSnapshot.value as Map,
        );

        final doctorType = doctorData['doctorType'] ?? '';
        final bool isVerified = doctorData['isVerified'] == true;

        // If not verified, show pending screen
        if (!isVerified) {
          // ignore: use_build_context_synchronously
          await _onLoginSuccess(context);
          Navigator.pushReplacement(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(builder: (_) => const VerifyPending()),
          );
          return;
        }

        // Determine doctor dashboard
        final Map<String, Widget> dashboardMap = {
          'labDoctor': const LabDoctorDashboard(),
          'consultingDoctor': const ConsultingDoctorDashboard(),
        };

        final role = doctorType;
        if (dashboardMap.containsKey(role)) {
          // ignore: use_build_context_synchronously
          await _onLoginSuccess(context);
          Navigator.pushReplacement(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(builder: (_) => dashboardMap[role]!),
          );
          return;
        } else {
          setState(() => error = 'Unknown doctor type. Contact admin.');
          return;
        }
      }

      /// ------------------ PATIENT / ADMIN ------------------
      final snapshot = await _db.child("users").child(uid).get();
      if (!snapshot.exists) {
        setState(() => error = "User not found in database.");
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final String role = data['role'] ?? '';
      final bool isVerified = data['isVerified'] == true;

      // Optional: block unverified patients/admins if needed
      if (!isVerified) {
        // ignore: use_build_context_synchronously
        await _onLoginSuccess(context);
        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(builder: (_) => const VerifyPending()),
        );
        return;
      }

      final Map<String, Widget> dashboardMap = {
        'patient': const PatientDashboard(),
        'admin': const AdminDashboard(),
      };

      if (dashboardMap.containsKey(role)) {
        // ignore: use_build_context_synchronously
        await _onLoginSuccess(context);
        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(builder: (_) => dashboardMap[role]!),
        );
      } else {
        setState(() => error = 'Unknown role. Contact admin.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'Login failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// -------------------- SAVE TOKEN & FCM --------------------
  Future<void> _onLoginSuccess(BuildContext context) async {
    await NotificationService.saveUserToken();
    // ignore: use_build_context_synchronously
    NotificationService.setupFCMListeners(context);
  }

  /// -------------------- RESET PASSWORD --------------------
  Future<void> _resetPassword() async {
    if (email.isEmpty) {
      setState(() {
        error = "Please enter your email above first.";
      });
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset email sent! Check your inbox."),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? "Failed to send reset email.";
      });
    }
  }

  /// -------------------- BUILD --------------------
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xffF8F2FF),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/login1.png', height: 120),
                          const SizedBox(height: 20),
                          const Text(
                            'Welcome!',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Login first',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 30),

                          if (error.isNotEmpty)
                            Text(
                              error,
                              style: const TextStyle(color: Colors.red),
                            ),

                          const SizedBox(height: 10),

                          // EMAIL FIELD
                          SizedBox(
                            height: 50,
                            child: TextFormField(
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xffF0EFFF),
                                labelText: 'Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (val) {
                                email = val;
                                if (error.isNotEmpty) {
                                  setState(() => error = "");
                                }
                              },
                              validator: (val) =>
                                  val!.isEmpty ? 'Enter an email' : null,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // PASSWORD FIELD
                          SizedBox(
                            height: 50,
                            child: TextFormField(
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xffF0EFFF),
                                labelText: 'Password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureText
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey.shade400,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureText = !_obscureText;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscureText,
                              onChanged: (val) {
                                password = val;
                                if (error.isNotEmpty) {
                                  setState(() => error = "");
                                }
                              },
                              validator: (val) => val!.length < 6
                                  ? 'Password must be at least 6 characters'
                                  : null,
                            ),
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _resetPassword,
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // LOGIN BUTTON
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff0064FA),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RegisterSelectionScreen(),
                              ),
                            ),
                            child: const Text(
                              'Don’t have an account? Register',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
