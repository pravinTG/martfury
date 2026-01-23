import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

/// SessionManager handles local storage of user session data and session validation
class SessionManager {
  static const String _keyIdToken = 'id_token';
  static const String _keyBackendUserId = 'backend_user_id';
  static const String _keyIsLoggedIn = 'is_logged_in';
  
  static final AuthService _authService = AuthService();

  /// Store login session data
  static Future<void> loginFromWordPress({
    required int userId,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIdToken, token);
    await prefs.setInt(_keyBackendUserId, userId);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  /// Get stored ID token
  static Future<String?> getIdToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIdToken);
  }

  /// Get stored backend user ID
  static Future<int?> getBackendUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBackendUserId);
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Clear all session data (logout)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIdToken);
    await prefs.remove(_keyBackendUserId);
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  /// Get all session data
  static Future<Map<String, dynamic>> getSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'idToken': prefs.getString(_keyIdToken),
      'backendUserId': prefs.getInt(_keyBackendUserId),
      'isLoggedIn': prefs.getBool(_keyIsLoggedIn) ?? false,
    };
  }

  /// Check if session is valid (Firebase + Local)
  static Future<bool> isSessionValid() async {
    try {
      // Check Firebase Auth
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        await logout();
        return false;
      }

      // Check local session
      final isLoggedIn = await SessionManager.isLoggedIn();
      final idToken = await SessionManager.getIdToken();
      final backendUserId = await SessionManager.getBackendUserId();

      if (!isLoggedIn || idToken == null || backendUserId == null) {
        await logout();
        return false;
      }

      // Verify token is still valid
      try {
        await firebaseUser.getIdToken();
        return true;
      } catch (e) {
        await logout();
        return false;
      }
    } catch (e) {
      await logout();
      return false;
    }
  }

  /// Get valid Firebase ID token (refreshes if needed)
  static Future<String?> getValidFirebaseToken() async {
    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        await logout();
        return null;
      }

      final token = await firebaseUser.getIdToken();
      
      // Update stored token
      final backendUserId = await getBackendUserId();
      if (backendUserId != null && token != null) {
        await loginFromWordPress(
          userId: backendUserId,
          token: token,
        );
      }
      
      return token;
    } catch (e) {
      await logout();
      return null;
    }
  }

  /// Clear session and Firebase Auth (complete logout)
  static Future<void> clearSession() async {
    await _authService.signOut();
    await logout();
  }
}

