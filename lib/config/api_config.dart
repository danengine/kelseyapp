import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend API host and port — change these to match how you run kelseybackend.
class ApiConfig {
  ApiConfig._();

  /// Physical iPhone: Mac LAN IP. Simulator: use `127.0.0.1`.
  static const String host = '192.168.1.167';

  /// Docker compose (`docker compose up`) uses **3001**. Match this to your running backend.
  static const int port = 3001;

  /// Rewards service (`kelseybackend/rewards`) default port.
  static const int rewardsPort = 3002;

  static String get baseUrl => 'http://$host:$port';

  static String get rewardsBaseUrl => 'http://$host:$rewardsPort';

  static String get authLoginUrl => '$baseUrl/api/auth/login';

  static String get authRegisterUrl => '$baseUrl/api/auth/register';

  static String get authUserInfoUrl => '$baseUrl/api/auth/userinfo';

  static String get unitsUrl => '$baseUrl/api/units';

  static String unitUrl(String id) => '$baseUrl/api/units/$id';

  static String get bookingsMyUrl => '$baseUrl/api/bookings/my';

  static String get bookingsUrl => '$baseUrl/api/bookings';

  static String bookingsForUnitUrl(String unitId) =>
      '$baseUrl/api/bookings?listingId=${Uri.encodeComponent(unitId)}';

  static String bookingUrl(String idOrRef) => '$baseUrl/api/bookings/$idOrRef';

  static String get bookingsAllUrl => '$baseUrl/api/bookings/all';

  static String bookingConfirmUrl(String id) => '$baseUrl/api/bookings/$id/confirm';

  static String bookingDeclineUrl(String id) => '$baseUrl/api/bookings/$id/decline';

  static String get deviceTokenUrl => '$baseUrl/api/notifications/device-token';

  /// AI chatbot service (`kelseybackend/chatbot`) default port.
  static const int chatbotPort = 3003;

  static String get chatbotBaseUrl => 'http://$host:$chatbotPort';

  static String get chatbotChatUrl => '$chatbotBaseUrl/api/chat';

  /// Facebook scraper service (`kelseybackend/datascraping`) default port.
  static const int scraperPort = 3004;

  static String get scraperBaseUrl => 'http://$host:$scraperPort';

  static String get facebookPostsUrl => '$scraperBaseUrl/api/facebook/posts';

  static String facebookPostUrl(String id) =>
      '$scraperBaseUrl/api/facebook/posts/${Uri.encodeComponent(id)}';

  static String get facebookPostsDeleteUrl => '$scraperBaseUrl/api/facebook/posts/delete';

  static String get rewardsMeUrl => '$rewardsBaseUrl/api/rewards/me';

  static String get rewardsLeaderboardUrl => '$rewardsBaseUrl/api/rewards/leaderboard';

  /// Relative paths and backend `localhost:PORT/...` URLs → app [baseUrl].
  static String resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    var resolved = url.trim();

    // e.g. http://localhost:3001/uploads/foo.png → http://127.0.0.1:3001/uploads/foo.png
    final localhost = RegExp(r'^https?://localhost(?::\d+)?', caseSensitive: false);
    if (localhost.hasMatch(resolved)) {
      final uri = Uri.parse(resolved);
      resolved = '$baseUrl${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
      return resolved;
    }

    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return resolved;
    }
    if (resolved.startsWith('/')) return '$baseUrl$resolved';
    return '$baseUrl/$resolved';
  }

  static String get connectivityHint {
    if (kIsWeb) return 'Ensure kelseybackend is running on port $port.';
    if (!kIsWeb && Platform.isAndroid) {
      return 'Android emulator: try host 10.0.2.2. Physical device: use your Mac LAN IP.';
    }
    return 'Ensure kelseybackend is running on port $port (docker compose up). '
        'Physical iPhone: set ApiConfig.host to your Mac LAN IP.';
  }
}
