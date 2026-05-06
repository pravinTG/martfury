import 'package:shared_preferences/shared_preferences.dart';

class TokenStorageService {
  static const String _userIdKey = 'user_id';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _idTokenKey = 'id_token';

  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setBool(_isLoggedInKey, true);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<void> saveIdToken(String idToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idTokenKey, idToken);
  }

  static Future<String?> getIdToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_idTokenKey);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_idTokenKey);
    await prefs.setBool(_isLoggedInKey, false);
  }
}
