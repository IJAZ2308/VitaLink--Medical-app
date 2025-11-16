// lib/screens/register_admin.dart

import 'package:flutter/material.dart';
import 'package:dr_shahin_uk/main.dart'; // Import AuthService from main.dart

class RegisterAdminScreen extends StatefulWidget {
  const RegisterAdminScreen({super.key});

  @override
  State<RegisterAdminScreen> createState() => _RegisterAdminScreenState();
}

class _RegisterAdminScreenState extends State<RegisterAdminScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  String error = '';

  void registerAdmin() async {
    final success = await AuthService().registerUser(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      name: nameController.text.trim(),
      role: 'admin',
      licenseFile: null,
      specialization: '',
      isVerified: true,
      doctorType: '',
      s: '',
      licenseFileUrl: '',
      licenseUrl: '',
      profileUrl: '',
      profileFileUrl: '', // Admin doesn’t need license
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context); // back to login or previous screen
    } else {
      setState(() {
        error = 'Registration failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Admin")),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: registerAdmin,
              child: const Text("Register Admin"),
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
