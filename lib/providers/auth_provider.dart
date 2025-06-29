import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../services/token_service.dart';
import '../services/auth_http_client.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _userProfile;

  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoggedIn => _userProfile != null;

  // Role checks
  bool get isAdmin => _hasRole('Admin');
  bool get isUser => _hasRole('User');
  bool get isEventManager => _hasRole('Event Manager');
  bool get isStaff => _hasRole('Staff');

  /// Private helper for role checks
  bool _hasRole(String role) {
    final roles = _userProfile?['roles'];
    if (roles is List<String>) {
      return roles.contains(role);
    }
    return false;
  }

  /// Loads the authenticated user's profile and extracts roles from the token.
  Future<void> loadUser() async {
    final token = await TokenService.getAccessToken();
    if (token == null) return;

    try {
      final response = await AuthHttpClient.get('/api/auth/profile');
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        // Decode JWT and extract roles
        final decodedToken = JwtDecoder.decode(token);
        final rawRoles = decodedToken['role'] ??
            decodedToken['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'];

        // Normalize roles into a list of strings
        final List<String> roles = switch (rawRoles) {
          String r => [r],
          List l => l.map((r) => r.toString()).toList(),
          _ => [],
        };

        _userProfile = {
          ...userData,
          'roles': roles,
        };

        notifyListeners();
      } else {
        await logout();
      }
    } catch (e) {
      await logout();
    }
  }

  /// Clears user session and tokens
  Future<void> logout() async {
    _userProfile = null;
    await TokenService.clearTokens();
    notifyListeners();
  }
}
