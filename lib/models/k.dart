import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthSessionManager {
  /// Returns a fresh Firebase ID token (refreshes automatically if expired)
  static Future<String?> getValidIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return await user.getIdToken(true);
  }
}
