// lib/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:dr_shahin_uk/main.dart'; // Import AuthService from main.dart

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  String role = "patient"; // Default role
  File? licenseFile;
  String error = '';

  Future<void> pickLicense() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        licenseFile = File(picked.path);
      });
    }
  }

  void registerUser() async {
    final success = await AuthService().registerUser(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      name: nameController.text.trim(),
      role: role,
      licenseFile: role == 'doctor' ? licenseFile : null,
      specialization: '',
      isVerified: false,
      doctorType: '',
      s: '',
      licenseFileUrl: '',
      licenseUrl: '',
      profileUrl: '',
      profileFileUrl: '', // only for doctors
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context); // go back to login or previous screen
    } else {
      setState(() {
        error = 'Registration failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 10),

            // Role selection (patient / doctor / admin)
            DropdownButtonFormField<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: "patient", child: Text("Patient")),
                DropdownMenuItem(value: "doctor", child: Text("Doctor")),
                DropdownMenuItem(value: "admin", child: Text("Admin")),
              ],
              onChanged: (val) => setState(() => role = val!),
              decoration: const InputDecoration(labelText: "Role"),
            ),
            const SizedBox(height: 10),

            // License upload only for doctors
            if (role == 'doctor')
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: pickLicense,
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Upload License"),
                  ),
                  if (licenseFile != null)
                    Text(
                      "License selected: ${licenseFile!.path.split('/').last}",
                    ),
                ],
              ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: registerUser,
              child: const Text("Register"),
            ),

            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
