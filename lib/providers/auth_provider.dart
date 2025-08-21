import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/token_service.dart';
import '../services/auth_http_client.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _userProfile;

  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoggedIn => _userProfile != null;

  int  get attendanceStrikeCount => (_userProfile?['attendanceStrikeCount'] as int?) ?? 0;
  bool get isSuspended => (_userProfile?['isSuspended'] as bool?) ?? false;

  // Role checks
  bool get isAdmin => _hasRole('Admin');
  bool get isUser => _hasRole('User');
  bool get isEventManager => _hasRole('Event Manager');
  bool get isStaff => _hasRole('Staff');
  bool get isGuest => !isAdmin && !isUser && !isEventManager && !isStaff;

  bool _hasRole(String role) {
    final roles = _userProfile?['roles'];
    if (roles is List) {
      return roles.map((e) => e.toString()).contains(role);
    }
    return false;
  }

  Future<void> loadUser() async {
    final token = await TokenService.getAccessToken();
    if (token == null) return;

    try {
      final response = await AuthHttpClient.get('/api/profile');
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        // Decode JWT and extract roles
        final decodedToken = JwtDecoder.decode(token);
        final rawRoles = decodedToken['role'] ??
            decodedToken['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'];

        final List<String> roles = switch (rawRoles) {
          String r => [r],
          List l   => l.map((r) => r.toString()).toList(),
          _ => [],
        };

        _userProfile = {
          'userName': userData['userName'],
          'firstName': userData['firstName'],
          'lastName': userData['lastName'],
          'email': userData['email'],
          'roles': roles,
          'age': userData['age'],
          'attendanceStrikeCount': userData['attendanceStrikeCount'] ?? 0,
          'isSuspended': userData['isSuspended'] ?? false,
        };

        notifyListeners();
      } else {
        await logout();
      }
    } catch (_) {
      await logout();
    }
  }

  Future<void> logout() async {
    _userProfile = null;
    await TokenService.clearTokens();
    notifyListeners();
  }
}
