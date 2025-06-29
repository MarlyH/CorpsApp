import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'token_service.dart';
import '../providers/auth_provider.dart';

class AuthHttpClient {
  static final _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';

  static Future<http.Response> get(String endpoint) async {
    await _ensureValidToken();
    final token = await TokenService.getAccessToken();
    return http.get(Uri.parse('$_baseUrl$endpoint'), headers: {
      'Authorization': 'Bearer $token',
    });
  }

  static Future<void> _ensureValidToken() async {
    final token = await TokenService.getAccessToken();
    if (token == null || JwtDecoder.isExpired(token)) {
      await _refreshToken();
    }
  }

  static Future<void> _refreshToken() async {
    final refreshToken = await TokenService.getRefreshToken();
    if (refreshToken == null) throw Exception('No refresh token available.');

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
}
