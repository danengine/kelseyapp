import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/admin_booking_item.dart';
import 'auth_service.dart';
import 'auth_session.dart';

class AdminBookingsService {
  const AdminBookingsService();

  Map<String, String> _authHeaders() {
    final token = AuthSession.accessToken;
    if (token == null || token.isEmpty) {
      throw AuthException('Please log in to continue.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<AdminBookingItem>> fetchAllBookings({int limit = 100}) async {
    final uri = Uri.parse(ApiConfig.bookingsAllUrl).replace(
      queryParameters: {'limit': '$limit', 'page': '1'},
    );

    http.Response response;
    try {
      response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 20));
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

    if (response.statusCode == 403) {
      throw AuthException('Admin access required to manage bookings.');
    }

    if (response.statusCode != 200 || body == null) {
      throw AuthException(
        body?['error'] as String? ?? 'Failed to load bookings (${response.statusCode}).',
      );
    }

    final data = body['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(AdminBookingItem.fromJson)
        .where((b) => b.id.isNotEmpty)
        .toList();
  }

  Future<void> confirmBooking(String id) async {
    await _patchAction(ApiConfig.bookingConfirmUrl(id), 'confirm');
  }

  Future<void> declineBooking(String id) async {
    await _patchAction(ApiConfig.bookingDeclineUrl(id), 'decline');
  }

  Future<void> _patchAction(String url, String action) async {
    http.Response response;
    try {
      response = await http
          .patch(Uri.parse(url), headers: _authHeaders(), body: '{}')
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

    if (response.statusCode == 200) return;

    throw AuthException(
      body?['error'] as String? ?? 'Failed to $action booking (${response.statusCode}).',
    );
  }
}
