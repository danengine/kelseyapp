import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../booking_models.dart';

class BookingsCache {
  BookingsCache._();

  static const _key = 'cached_my_bookings_v1';

  static Future<List<BookingRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(BookingRecord.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<BookingRecord> bookings) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = bookings.map((b) => b.toJson()).toList();
    await prefs.setString(_key, jsonEncode(payload));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
