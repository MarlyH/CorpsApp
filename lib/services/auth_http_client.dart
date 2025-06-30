import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'token_service.dart';

class AuthHttpClient {
  static final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';

  // Public methods
  static Future<http.Response> get(String endpoint, {Map<String, String>? headers}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, headers),
    );
    _checkForErrors(response);
    return response;
  }

  static Future<http.Response> post(String endpoint, {Map<String, String>? headers, dynamic body}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final response = await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, headers),
      body: jsonEncode(body),
    );
    _checkForErrors(response);
    return response;
  }

  static Future<http.Response> patch(String endpoint, {Map<String, String>? headers, dynamic body}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final response = await http.patch(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, headers),
      body: jsonEncode(body),
    );
    _checkForErrors(response);
    return response;
  }

  static Future<http.Response> delete(String endpoint, {Map<String, String>? headers}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, headers),
    );
    _checkForErrors(response);
    return response;
  }

  // Internal methods
  static Map<String, String> _buildHeaders(String? token, Map<String, String>? extraHeaders) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      if (extraHeaders != null) ...extraHeaders,
    };
  }

  static Future<void> _ensureValidToken() async {
    final token = await TokenService.getAccessToken();
    if (token == null || JwtDecoder.isExpired(token)) {
      await _refreshToken();
    }
  }

  static Future<void> _refreshToken() async {
    final refreshToken = await TokenService.getRefreshToken();
    if (refreshToken == null) {
      await TokenService.clearTokens();
      throw Exception('No refresh token available');
    }

    final url = Uri.parse('$_baseUrl/api/auth/refresh');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await TokenService.saveTokens(data['accessToken'], data['refreshToken']);
    } else {
      await TokenService.clearTokens();
      throw Exception('Token refresh failed');
    }
  }

  static void _checkForErrors(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception('HTTP Error ${response.statusCode}: ${response.body}');
    }
  }
  static Future<void> requestEmailChange(String newEmail) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();

    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/request-email-change'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'newEmail': newEmail}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to request email change.');
    }
  }

  static Future<void> updateProfile({
    String? newUserName,
    String? newFirstName,
    String? newLastName,
  }) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();

    final body = {
      if (newUserName != null) 'newUserName': newUserName,
      if (newFirstName != null) 'newFirstName': newFirstName,
      if (newLastName != null) 'newLastName': newLastName,
    };

    final response = await http.patch(
      Uri.parse('$_baseUrl/api/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to update profile.');
    }
  }

  static Future<void> deleteProfile() async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();

    final response = await http.delete(
      Uri.parse('$_baseUrl/api/auth/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to delete profile.');
    }
  }
}
