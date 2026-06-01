import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_profile.dart';
import 'auth_session.dart';

/// Persists auth token + profile securely (Keychain on iOS, Keystore on Android).
class AuthStorage {
  AuthStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _tokenKey = 'kelsey_access_token';
  static const _profileKey = 'kelsey_user_profile';

  static bool _isPluginMissing(Object error) {
    return error is MissingPluginException ||
        (error is PlatformException && error.code == 'channel-error');
  }

  static Future<void> saveSession({
    required String token,
    required UserProfile profile,
  }) async {
    AuthSession.setSession(token: token, userProfile: profile);
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _profileKey, value: jsonEncode(profile.toJson()));
    } catch (e) {
      if (!_isPluginMissing(e)) rethrow;
      // Hot restart without full rebuild — session stays in memory only.
    }
  }

  /// Loads saved session into [AuthSession]. Returns true if a token was restored.
  static Future<bool> restoreSession() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) return false;

      UserProfile? profile;
      final profileJson = await _storage.read(key: _profileKey);
      if (profileJson != null && profileJson.isNotEmpty) {
        try {
          profile = UserProfile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>);
        } catch (_) {
          profile = null;
        }
      }

      AuthSession.setSession(
        token: token,
        userProfile: profile ?? UserProfile(email: '', roles: const ['Guest']),
      );
      return true;
    } catch (e) {
      if (_isPluginMissing(e)) return false;
      rethrow;
    }
  }

  static Future<void> clearPersistedCredentials() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _profileKey);
    } catch (e) {
      if (!_isPluginMissing(e)) rethrow;
    }
  }

  static Future<void> clearSession() async {
    await clearPersistedCredentials();
    AuthSession.clear();
  }

  static Future<bool> hasStoredSession() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      if (_isPluginMissing(e)) return false;
      rethrow;
    }
  }
}
