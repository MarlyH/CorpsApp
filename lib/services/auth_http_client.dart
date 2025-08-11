import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

import 'token_service.dart';
import '../models/location.dart';

class AuthHttpClient {
  AuthHttpClient._();
  static final http.Client _client = http.Client();
  static final String _baseUrl =
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';

  // ─────────────────────────────────────────────────────────────── Generic ───
  static Future<http.Response> get(String endpoint,
    {Map<String, String>? extraHeaders}) async {
        await _ensureValidToken();
        final token = await TokenService.getAccessToken();

    final resp = await _client.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, extraHeaders),
    );
    _checkForErrors(resp);
    return resp;
  }

  static Future<http.Response> getNoAuth(String endpoint, {Map<String, String>? extraHeaders}) async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: extraHeaders,
    );
    _checkForErrors(resp);
    return resp;
  }

  static Future<http.Response> post(String endpoint,
      {Map<String, String>? extraHeaders, dynamic body}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final resp = await _client.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, extraHeaders),
      body: jsonEncode(body),
    );
    _checkForErrors(resp);
    return resp;
  }

  static Future<http.Response> patch(String endpoint,
      {Map<String, String>? extraHeaders, dynamic body}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final resp = await _client.patch(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, extraHeaders),
      body: jsonEncode(body),
    );
    _checkForErrors(resp);
    return resp;
  }

  static Future<http.Response> put(String endpoint,
      {Map<String, String>? extraHeaders, dynamic body}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final resp = await _client.put(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, extraHeaders),
      body: jsonEncode(body),
    );
    _checkForErrors(resp);
    return resp;
  }

  static Future<http.Response> delete(String endpoint,
      {Map<String, String>? extraHeaders}) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final resp = await _client.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: _buildHeaders(token, extraHeaders),
    );
    _checkForErrors(resp);
    return resp;
  }

  // ───────────────────────────────────────────────────────── Profile & Auth ───

  /// Send a change-email request
  static Future<http.Response> requestEmailChange(String newEmail) {
    return post(
      '/api/email/request-email-change',
      body: {'newEmail': newEmail},
    );
  }

  /// Patch your own profile (username / names)
  static Future<void> updateProfile({
    String? newUserName,
    String? newFirstName,
    String? newLastName,
  }) async {
    final body = <String, String>{
      if (newUserName != null) 'newUserName': newUserName,
      if (newFirstName != null) 'newFirstName': newFirstName,
      if (newLastName != null) 'newLastName': newLastName,
    };
    final resp = await patch(
      '/api/profile',  // ← **use** `/api/profile` not `/api/profile/profile`
      body: body,
    );
    if (resp.statusCode != 200) {
      throw Exception('Update failed (${resp.statusCode}): ${resp.body}');
    }
  }

  /// Delete your own account (cancels bookings, removes children, then deletes user)
  static Future<void> deleteProfile() async {
    final resp = await delete('/api/profile/me');
    if (resp.statusCode != 200) {
      throw Exception('Delete failed (${resp.statusCode}): ${resp.body}');
    }
  }

  /// Admin-only: change another user’s role
  static Future<http.Response> changeUserRole({
    required String email,
    required String role,
  }) {
    return post(
      '/api/userManagement/change-role',
      body: {'email': email, 'role': role},
    );
  }

  // ───────────────────────────────────────────────────────────── Child ───

  static Future<http.Response> fetchChildren() => get('/api/child');
  static Future<http.Response> fetchChildById(int id) => get('/api/child/$id');
  static Future<http.Response> createChild(Map<String, dynamic> data) =>
      post('/api/child', body: data);
  static Future<http.Response> updateChild(int id, Map<String, dynamic> data) =>
      put('/api/child/$id', body: data);
  static Future<http.Response> deleteChild(int id) =>
      delete('/api/child/$id');

  // ───────────────────────────────────────────────────────────── Event ───

  static Future<List<Location>> fetchLocations() async {
    final resp = await get('/api/locations');
    final List<dynamic> data = jsonDecode(resp.body);
    return data
        .cast<Map<String, dynamic>>()
        .map((m) => Location.fromJson(m))
        .toList();
  }

  // ───────────────────────────────────────────────────────────── Internal ───

  static Map<String, String> _buildHeaders(
    String? token, [
    Map<String, String>? extra,
  ]) {
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
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refresh}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      await TokenService.saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
    } else {
      await TokenService.clearTokens();
      throw Exception(
        'Refresh failed (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  static void _checkForErrors(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
  /// GET /api/Locations
  static Future<http.Response> getLocations() {
    return get('/api/Locations');
  }

  /// GET /api/Locations/{id}
  static Future<http.Response> getLocation(int id) {
    return get('/api/Locations/$id');
  }

  /// POST /api/Locations  (multipart/form-data)
  static Future<http.Response> createLocation({
    required String name,
    File? imageFile,
  }) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();

    final uri = Uri.parse('$_baseUrl/api/Locations');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['name'] = name;

    if (imageFile != null) {
      final mimeType = lookupMimeType(imageFile.path) ?? 'application/octet-stream';
      final parts    = mimeType.split('/');
      req.files.add(
        await http.MultipartFile.fromPath(
          'mascotImage',
          imageFile.path,
          contentType: MediaType(parts[0], parts[1]),
        ),
      );
    }

    final streamed = await req.send();
    final res      = await http.Response.fromStream(streamed);
    _checkForErrors(res);
    return res;
  }

  /// PUT /api/Locations/{id}  (multipart/form-data)
  static Future<http.Response> updateLocation({
    required int    id,
    required String name,
    File? imageFile,
  }) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();

    final uri = Uri.parse('$_baseUrl/api/Locations/$id');
    final req = http.MultipartRequest('PUT', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['name'] = name;

    if (imageFile != null) {
      final mimeType = lookupMimeType(imageFile.path) ?? 'application/octet-stream';
      final parts    = mimeType.split('/');
      req.files.add(
        await http.MultipartFile.fromPath(
          'mascotImage',
          imageFile.path,
          contentType: MediaType(parts[0], parts[1]),
        ),
      );
    }

    final streamed = await req.send();
    final res      = await http.Response.fromStream(streamed);
    _checkForErrors(res);
    return res;
  }

  /// DELETE /api/Locations/{id}
  static Future<http.Response> deleteLocation(int id) {
    return delete('/api/Locations/$id');
  }

  /// POST /api/events  (multipart/form-data)
  static Future<http.Response> createEvent({
    required int    locationId,
    required String sessionType,
    required String startDate,
    required String startTime,
    required String endTime,
    required String availableDate,
    required int    totalSeats,
    String?         description,
    String?         address,
    File?           seatingMapImage,
  }) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    final uri = Uri.parse('$_baseUrl/api/events');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll({
        'locationId':    locationId.toString(),
        'sessionType':   sessionType,
        'startDate':     startDate,
        'startTime':     startTime,
        'endTime':       endTime,
        'availableDate': availableDate,
        'totalSeats':    totalSeats.toString(),
        if (description != null) 'description': description,
        if (address     != null) 'address':     address,
      });

    if (seatingMapImage != null) {
      final mimeType = lookupMimeType(seatingMapImage.path) ?? 'application/octet-stream';
      final parts    = mimeType.split('/');
      req.files.add(await http.MultipartFile.fromPath(
        'seatingMapImage',
        seatingMapImage.path,
        contentType: MediaType(parts[0], parts[1]),
      ));
    }

    final streamed = await req.send();
    final res      = await http.Response.fromStream(streamed);
    _checkForErrors(res);
    return res;
  }

  /// PUT /api/events/{id}/cancel
  static Future<http.Response> cancelEvent(int id, {String? cancellationMessage}) {
    return put(
      '/api/events/$id/cancel',
      body: {
        if (cancellationMessage != null) 'cancellationMessage': cancellationMessage,
      },
    );
  }

  /// GET /api/events/{eventId}/waitlist
  static Future<http.Response> getWaitlist(int eventId) {
    return get('/api/events/$eventId/waitlist');
  }

  /// POST /api/events/{eventId}/waitlist
  static Future<http.Response> addToWaitlist(int eventId) {
    return post('/api/events/$eventId/waitlist');
  }

  /// DELETE /api/events/{eventId}/waitlist
  static Future<http.Response> removeFromWaitlist(int eventId) {
    return delete('/api/events/$eventId/waitlist');
  }

  static Future<void> registerDeviceToken(String deviceToken) async {
    final platform = Platform.isAndroid ? 'Android' : 'iOS';

    final body = {
      'deviceToken': deviceToken,
      'platform': platform,
    };

    final resp = await post('/api/notification', body: body);
    if (resp.statusCode != 200) {
      throw Exception('Failed to register device token: ${resp.body}');
    }
  }
}
