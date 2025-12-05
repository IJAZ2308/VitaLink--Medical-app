import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogoutHelper {
  static Future<void> logout(BuildContext context) async {
    if (!context.mounted) return;

    // Logout confirmation dialog
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dContext) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dContext).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dContext).pop(true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();

        // Navigate safely after logout
        if (context.mounted) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamedAndRemoveUntil('/login', (_) => false);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
        }
      }
    }
  }
}
