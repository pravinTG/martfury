import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../utils/custom_snackbar.dart';
import '../screens/phone_login_screen.dart';

/// Helper for logout functionality
class LogoutHelper {
  /// Logout user and navigate to login screen
  static Future<void> logout(BuildContext context) async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      // Clear session (Firebase + Local)
      await SessionManager.clearSession();

      // Navigate to login
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const PhoneLoginScreen(),
          ),
          (route) => false,
        );
        CustomSnackBar.show(context, 'Logged out successfully', isError: false);
      }
    }
  }
}


