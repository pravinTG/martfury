import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'api_endpoints.dart';
import '../services/session_manager.dart';
import '../utils/safe_print.dart';

/// ApiService handles all API requests (GET, POST, PUT, DELETE)
/// Uses environment variables from .env.dev or .env.prod file
class ApiService {
  // Get values from environment variables
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'https://goodiesworld.techgigs.in/wp-json/wc/v3';
  static String get consumerKey => dotenv.env['CONSUMER_KEY'] ?? '';
  static String get consumerSecret => dotenv.env['CONSUMER_SECRET'] ?? '';
  /// 🔑 Returns headers with session token (for WordPress APIs)
  static Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      // 'x-user-token': '${FirebaseAuthSessionManager.getValidIdToken()}'
    };
  }

  /// 🔑 Generate Basic Auth header (for WooCommerce APIs)
  static String get _authHeader {
    final creds = "$consumerKey:$consumerSecret";
    final bytes = utf8.encode(creds);
    return "Basic ${base64Encode(bytes)}";
  }

  /// 🔑 Default headers with Basic Auth
  static Map<String, String> getHeader() {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": _authHeader,
    };
  }

  static Map<String, String> getAuthHeader() {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": _authHeader,
    };
  }

  /// Headers with Bearer token
  static Map<String, String> getHeaderWithToken(String token) {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": " Bearer $token", // 👈 add Bearer if JWT
    };
  }

  /// ✅ GET request
  static Future<http.Response> gets(
    String endpoint, {
    String? token,
    Map<String, String>? queryParams,
  }) async {
    var uri = Uri.parse('$baseUrl$endpoint');
    
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    
    final headers = token != null ? getHeaderWithToken(token) : getHeader();

    safePrint('GET → $uri');
    safePrint('Headers: $headers');
    return await http.get(uri, headers: headers);
  }

  /// ✅ POST request
  static Future<http.Response> posts(String endpoint,
      Map<String, dynamic> body,
      {
        String? token, // <-- optional & named now
      }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    safePrint('POST → $url');
    safePrint('body: $body');
    safePrint('token: $token');
    final headers = token != null ? getHeaderWithToken(token) : getHeader();
    print('prrrrrrrrrrr $headers');
    return await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
  }

  /// ✅ PUT request
  static Future<http.Response> puts(
      String endpoint, Map<String, dynamic> body,{
        String? token, // <-- optional & named now
      }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    safePrint('PUT → $url');
    safePrint('Body: $body');
    final headers = token != null ? getHeaderWithToken(token) : getHeader();

    return await http.put(
      url,
      headers:headers,
      body: jsonEncode(body),
    );
  }

  /// ✅ DELETE request
  static Future<http.Response> deletes(
      String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    safePrint('DELETE → $url');
    safePrint('Body: $body');
    return await http.delete(
      url,
      headers: getHeader(),
      body: jsonEncode(body),
    );
  }
}
