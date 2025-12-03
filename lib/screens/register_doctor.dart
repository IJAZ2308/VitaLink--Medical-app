// lib/screens/register_doctor_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dr_shahin_uk/main.dart'; // AuthService
import 'package:dr_shahin_uk/screens/shared/verify_pending.dart';

class RegisterDoctorScreen extends StatefulWidget {
  const RegisterDoctorScreen({super.key});

  @override
  State<RegisterDoctorScreen> createState() => _RegisterDoctorScreenState();
}

class _RegisterDoctorScreenState extends State<RegisterDoctorScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  File? _licenseImage;
  File? _profileImage;
  String error = '';
  bool loading = false;

  String? _selectedDoctorRole; // labDoctor or consultingDoctor
  String? _selectedCategory; // specialization

  final List<String> _categories = [
    "General Surgery",
    "Orthopaedics",
    "Neurosurgery",
    "Cardiothoracic",
    "Vascular Surgery",
    "ENT",
    "Ophthalmology",
    "Urology",
    "Plastic Surgery",
    "Paediatric Surgery",
    "Neonatology",
    "Obstetrics & Gynaecology (O&G)",
    "Oncology",
    "General Practice",
    "Radiology & Imaging",
    "Emergency service",
    "Public Health",
    "Occupational Health",
  ];

  /// Pick license image
  Future<void> _pickLicenseImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) setState(() => _licenseImage = File(picked.path));
    } catch (e) {
      setState(() => error = 'Failed to pick license image: $e');
    }
  }

  /// Pick profile image
  Future<void> _pickProfileImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) setState(() => _profileImage = File(picked.path));
    } catch (e) {
      setState(() => error = 'Failed to pick profile image: $e');
    }
  }

  /// Register doctor
  Future<void> _registerDoctor() async {
    if (_selectedDoctorRole == null) {
      setState(() => error = "Please select your doctor role.");
      return;
    }
    if (_licenseImage == null) {
      setState(() => error = "Please upload your license image.");
      return;
    }
    if (_profileImage == null) {
      setState(() => error = "Please upload your profile image.");
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      setState(() => error = "Please select your specialization category.");
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      // Upload both images
      final String? licenseUrl = await _authService.uploadLicense(
        _licenseImage!,
      );
      final String? profileUrl = await _authService.uploadProfileImage(
        _profileImage!,
      );

      if (licenseUrl == null || profileUrl == null) {
        setState(() {
          loading = false;
          error = "Image upload failed. Please try again.";
        });
        return;
      }

      // Register doctor (now stored under /doctors/)
      final bool success = await _authService.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        role: "doctor",
        s: _selectedDoctorRole!,
        licenseFileUrl: licenseUrl, // <-- pass uploaded URL
        profileFileUrl: profileUrl, // <-- pass uploaded URL
        specialization: _selectedCategory!,
        isVerified: false,
        doctorType: "pending",
        licenseFile: null,
        licenseUrl: '',
        profileUrl: '',
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VerifyPending()),
        );
      } else {
        setState(() => error = 'Registration failed. Please try again.');
      }
    } catch (e) {
      setState(() => error = 'Error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register as Doctor")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error.isNotEmpty)
                Text(error, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name"),
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Select Specialization Category",
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map(
                      (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _selectedDoctorRole,
                decoration: const InputDecoration(
                  labelText: "Select Doctor Role",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "labDoctor",
                    child: Text("Lab Doctor"),
                  ),
                  DropdownMenuItem(
                    value: "consultingDoctor",
                    child: Text("Consulting Doctor"),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedDoctorRole = value),
              ),
              const SizedBox(height: 20),

              // Profile Image Upload Section
              const Text("Profile Image"),
              const SizedBox(height: 5),
              _profileImage != null
                  ? Image.file(_profileImage!, height: 100)
                  : const Text("No profile image uploaded"),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _pickProfileImage,
                child: const Text("Upload Profile Image"),
              ),
              const SizedBox(height: 20),

              // License Upload Section
              const Text("License Image"),
              const SizedBox(height: 5),
              _licenseImage != null
                  ? Image.file(_licenseImage!, height: 100)
                  : const Text("No license uploaded"),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _pickLicenseImage,
                child: const Text("Upload License Image"),
              ),
              const SizedBox(height: 20),

              loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _registerDoctor,
                      child: const Text("Register"),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
