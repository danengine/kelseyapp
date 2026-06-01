import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_profile.dart';
import 'auth_session.dart';
import 'auth_storage.dart';

class AuthLoginResult {
  const AuthLoginResult({required this.profile, required this.accessToken});

  final UserProfile profile;
  final String accessToken;
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  const AuthService();

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? gender,
    String? birthDate,
    String? street,
    String? barangay,
    String? city,
    String? zipCode,
  }) async {
    final uri = Uri.parse(ApiConfig.authRegisterUrl);
    http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firstName': firstName.trim(),
              'lastName': lastName.trim(),
              'email': email.trim(),
              'password': password,
              if (gender != null) 'gender': gender,
              if (birthDate != null) 'birthDate': birthDate,
              if (street != null) 'street': street.trim(),
              if (barangay != null) 'barangay': barangay.trim(),
              if (city != null) 'city': city.trim(),
              if (zipCode != null) 'zipCode': zipCode.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException(
        'Could not reach the server at ${ApiConfig.baseUrl}. ${ApiConfig.connectivityHint}',
      );
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      body = null;
    }

    if (response.statusCode == 201) return;

    final message = body?['error'] as String? ?? 'Registration failed (${response.statusCode}).';
    throw AuthException(message);
  }

  Future<AuthLoginResult> login({
    required String email,
    required String password,
    bool persist = true,
  }) async {
    final uri = Uri.parse(ApiConfig.authLoginUrl);
    http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException(
        'Could not reach the server at ${ApiConfig.baseUrl}. ${ApiConfig.connectivityHint}',
      );
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      body = null;
    }

    if (response.statusCode == 200) {
      final token = body?['accessToken'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthException('Login succeeded but no access token was returned.');
      }

      final profile = await _fetchUserProfile(token);
      final resolvedProfile = profile ??
          UserProfile(email: email.trim(), roles: const ['Guest']);

      if (persist) {
        await AuthStorage.saveSession(token: token, profile: resolvedProfile);
      } else {
        AuthSession.setSession(token: token, userProfile: resolvedProfile);
        await AuthStorage.clearPersistedCredentials();
      }

      return AuthLoginResult(profile: resolvedProfile, accessToken: token);
    }

    final message = body?['error'] as String? ?? 'Login failed (${response.statusCode}).';
    throw AuthException(message);
  }

  Future<UserProfile?> refreshProfileIfOnline() async {
    final token = AuthSession.accessToken;
    if (token == null || token.isEmpty) return null;

    final profile = await _fetchUserProfile(token);
    if (profile == null) return null;

    await AuthStorage.saveSession(token: token, profile: profile);
    return profile;
  }

  Future<UserProfile?> _fetchUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.authUserInfoUrl),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return UserProfile.fromJson(body);
    } catch (_) {
      return null;
    }
  }
}
