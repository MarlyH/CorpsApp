import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'token_service.dart';

class AuthHttpClient {
  static final http.Client _client = http.Client();
  static final String _baseUrl =
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';

  // Performs a GET against [endpoint], refreshing tokens if needed.
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

  // Performs a POST against [endpoint], refreshing tokens if needed.
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

  // Performs a PATCH against [endpoint], refreshing tokens if needed.
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

  // Performs a DELETE against [endpoint], refreshing tokens if needed.
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

  // Sends the email-change request, returning the raw response so the UI
  // can inspect statusCode and JSON body.
  static Future<http.Response> requestEmailChange(String newEmail) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final uri = Uri.parse('$_baseUrl/api/auth/request-email-change');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'newEmail': newEmail}),
    );
    // do not throw here
    return response;
  }

  // Updates the profile; throws on non-200.
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
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
  }

  // Deletes the profile; throws on non-200.
  static Future<void> deleteProfile() async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final uri = Uri.parse('$_baseUrl/api/auth/profile');
    final response = await _client.delete(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    _ensureSuccess(response);
  }

  // these below are internal Helpers

  // Builds standard JSON + Bearer headers.
  static Map<String, String> _buildHeaders(
      String? token, Map<String, String>? extra) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    if (extra != null) h.addAll(extra);
    return h;
  }

  // Ensures tokens are valid, and attempts to refresh if missing/expired.
  static Future<void> _ensureValidToken() async {
    final access = await TokenService.getAccessToken();
    if (access == null || JwtDecoder.isExpired(access)) {
      await _refreshToken();
    }
  }

  // Calls the backend `/refresh` endpoint; on success saves new tokens,
  // on failure clears and throws.
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

  // Throws if status code >=400.
  static void _checkForErrors(http.Response resp) {
    if (resp.statusCode >= 400) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  // Similar to _checkForErrors but allows 200 only.
  static void _ensureSuccess(http.Response resp) {
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }
}
