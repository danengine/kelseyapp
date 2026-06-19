import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../firebase_options.dart';
import 'auth_session.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isConfigured) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Registers FCM tokens with the backend and handles incoming notifications.
class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;
  static String? _currentToken;
  static bool _loggedApnsUnavailable = false;
  static Future<void>? _tokenSyncInFlight;

  static bool get isAvailable => _initialized;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint('PushNotificationService: Firebase not configured — run flutterfire configure');
      return;
    }

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _requestPermission();

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      _messaging.onTokenRefresh.listen((token) {
        _registerTokenWithBackend(token);
      });

      _initialized = true;
      await syncTokenIfLoggedIn();
    } catch (error, stack) {
      debugPrint('PushNotificationService init failed: $error\n$stack');
    }
  }

  static Future<void> syncTokenIfLoggedIn() async {
    if (!_initialized || !AuthSession.isLoggedIn) return;

    _tokenSyncInFlight ??= _syncTokenIfLoggedInImpl();
    try {
      await _tokenSyncInFlight;
    } finally {
      _tokenSyncInFlight = null;
    }
  }

  static Future<void> _syncTokenIfLoggedInImpl() async {
    final token = await _safeGetFcmToken();
    if (token != null && token.isNotEmpty) {
      await _registerTokenWithBackend(token);
    }
  }

  static Future<void> unregisterCurrentToken() async {
    if (!_initialized) return;

    try {
      final token = _currentToken ?? await _safeGetFcmToken();
      if (token == null || token.isEmpty) return;

      final accessToken = AuthSession.accessToken;
      if (accessToken == null || accessToken.isEmpty) return;

      await http
          .delete(
            Uri.parse(ApiConfig.deviceTokenUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('PushNotificationService unregister failed: $error');
    } finally {
      _currentToken = null;
    }
  }

  /// iOS requires an APNS token before FCM can issue a device token.
  static Future<String?> _safeGetFcmToken() async {
    try {
      if (Platform.isIOS) {
        var apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          for (var attempt = 0; attempt < 6; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            apnsToken = await _messaging.getAPNSToken();
            if (apnsToken != null) break;
          }
        }
        if (apnsToken == null) {
          if (!_loggedApnsUnavailable) {
            _loggedApnsUnavailable = true;
            debugPrint(
              'PushNotificationService: APNS token not available — '
              'rebuild the app after adding push entitlements, or test on a physical iPhone.',
            );
          }
          return null;
        }
      }

      return await _messaging.getToken();
    } catch (error) {
      if (_isApnsNotReadyError(error)) {
        debugPrint('PushNotificationService: push not ready on this device yet.');
        return null;
      }
      debugPrint('PushNotificationService getToken failed: $error');
      return null;
    }
  }

  static bool _isApnsNotReadyError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('apns-token-not-set') ||
        message.contains('apns token has not been set');
  }

  static Future<void> _requestPermission() async {
    if (Platform.isIOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (Platform.isAndroid) {
      await _messaging.requestPermission();
    }
  }

  static Future<void> _registerTokenWithBackend(String token) async {
    final accessToken = AuthSession.accessToken;
    if (accessToken == null || accessToken.isEmpty) return;

    final platform = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
            ? 'android'
            : 'unknown';

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.deviceTokenUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({'token': token, 'platform': platform}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _currentToken = token;
      }
    } catch (error) {
      debugPrint('PushNotificationService register failed: $error');
    }
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final context = _navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notification.body ?? notification.title ?? 'New notification'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('Notification opened: ${message.data}');
  }

  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
}
