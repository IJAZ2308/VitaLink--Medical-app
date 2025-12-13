import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogoutHelper {
  static Future<void> logout(BuildContext context) async {
    // Prevent calling when widget is already disposed
    if (!context.mounted) return;

    // Show confirmation dialog
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    // If user cancels or dialog dismissed
    if (shouldLogout != true) return;

    try {
      // Sign out safely
      await FirebaseAuth.instance.signOut();

      // Navigate only if context is still valid
      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      // Handle errors safely
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout failed: ${e.toString()}"),
        ),
      );
    }
  }
}
