import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'token_service.dart';

class AuthHttpClient {
  static final http.Client _client = http.Client();
  static final String _baseUrl =
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';

  // Generic HTTP Methods

  static Future<http.Response> get(String endpoint,
      {Map<String, String>? extraHeaders}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final response = await _client.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, extraHeaders),
    );
    _checkForErrors(response);
    return response;
  }

  static Future<http.Response> post(String endpoint,
      {Map<String, String>? extraHeaders, dynamic body}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final response = await _client.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, extraHeaders),
      body: jsonEncode(body),
    );
    _checkForErrors(response);
    return response;
  }

  static Future<http.Response> patch(String endpoint,
      {Map<String, String>? extraHeaders, dynamic body}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final response = await _client.patch(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, extraHeaders),
      body: jsonEncode(body),
    );
    _checkForErrors(response);
    return response;
  }

  static Future<http.Response> put(String endpoint,
      {Map<String, String>? extraHeaders, dynamic body}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final response = await _client.put(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, extraHeaders),
      body: jsonEncode(body),
    );
    _checkForErrors(response);
    return response;
  }

  static Future<http.Response> delete(String endpoint,
      {Map<String, String>? extraHeaders}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final response = await _client.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, extraHeaders),
    );
    _checkForErrors(response);
    return response;
  }

  // Profile & Auth-Specific

  static Future<http.Response> requestEmailChange(String newEmail) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final uri = Uri.parse('$_baseUrl/api/auth/request-email-change');
    final response = await _client.post(
      uri,
      headers: _buildHeaders(token),
      body: jsonEncode({'newEmail': newEmail}),
    );
    return response;
  }

  static Future<void> updateProfile({
    String? newUserName,
    String? newFirstName,
    String? newLastName,
  }) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final uri = Uri.parse('$_baseUrl/api/auth/profile');
    final body = <String, String>{
      if (newUserName != null) 'newUserName': newUserName,
      if (newFirstName != null) 'newFirstName': newFirstName,
      if (newLastName != null) 'newLastName': newLastName,
    };
    final response = await _client.patch(
      uri,
      headers: _buildHeaders(token),
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
  }

  static Future<void> deleteProfile() async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final uri = Uri.parse('$_baseUrl/api/auth/profile');
    final response = await _client.delete(
      uri,
      headers: _buildHeaders(token),
    );
    _ensureSuccess(response);
  }

  // Change a user’s role (Admin only)
  static Future<http.Response> changeUserRole({
    required String email,
    required String role,
  }) {
    return post(
      '/api/auth/change-role',
      body: {
        'email': email,
        'role': role,
      },
    );
  }


  // Child-Specific Endpoints


  static Future<http.Response> fetchChildren() => get('/api/child');

  static Future<http.Response> fetchChildById(int id) =>
      get('/api/child/$id');

  static Future<http.Response> createChild(Map<String, dynamic> data) =>
      post('/api/child', body: data);

  static Future<http.Response> updateChild(int id, Map<String, dynamic> data) =>
      put('/api/child/$id', body: data);

  static Future<http.Response> deleteChild(int id) =>
      delete('/api/child/$id');

  // Internal Helpers

  static Map<String, String> _buildHeaders(
      String? token, [Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  static Future<void> _ensureValidToken() async {
    final access = await TokenService.getAccessToken();
    if (access == null || JwtDecoder.isExpired(access)) {
      await _refreshToken();
    }
  }

  static Future<void> _refreshToken() async {
    final refresh = await TokenService.getRefreshToken();
    if (refresh == null) {
      await TokenService.clearTokens();
      throw Exception('No refresh token available');
    }

    final uri = Uri.parse('$_baseUrl/api/auth/refresh');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refresh}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess != null && newRefresh != null) {
        await TokenService.saveTokens(newAccess, newRefresh);
      } else {
        await TokenService.clearTokens();
        throw Exception('Invalid tokens from refresh');
      }
    } else {
      await TokenService.clearTokens();
      throw Exception(
          'Token refresh failed (${response.statusCode}): ${response.body}');
    }
  }

  static void _checkForErrors(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  static void _ensureSuccess(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}
