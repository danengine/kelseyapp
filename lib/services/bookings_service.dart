import 'dart:convert';

import 'package:http/http.dart' as http;

import '../booking_models.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'auth_session.dart';

class UnitAvailabilityRange {
  const UnitAvailabilityRange({
    required this.checkIn,
    required this.checkOut,
  });

  final DateTime checkIn;
  final DateTime checkOut;

  factory UnitAvailabilityRange.fromJson(Map<String, dynamic> json) {
    return UnitAvailabilityRange(
      checkIn: DateTime.parse(json['check_in_date'] as String),
      checkOut: DateTime.parse(json['check_out_date'] as String),
    );
  }
}

class GuestBookingResult {
  const GuestBookingResult({
    required this.id,
    required this.referenceCode,
    required this.checkIn,
    required this.checkOut,
    required this.totalGuests,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
  });

  final String id;
  final String referenceCode;
  final String checkIn;
  final String checkOut;
  final int totalGuests;
  final double totalAmount;
  final String paymentMethod;
  final String status;
}

class CreateBookingInput {
  const CreateBookingInput({
    required this.unitId,
    required this.checkIn,
    required this.checkOut,
    required this.totalGuests,
    required this.paymentMethod,
    required this.client,
    this.requirePayment = true,
    this.notes,
  });

  final String unitId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int totalGuests;
  final String paymentMethod;
  final Map<String, dynamic> client;
  final bool requirePayment;
  final String? notes;
}

class BookingsService {
  const BookingsService();

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

  Future<List<UnitAvailabilityRange>> fetchUnitAvailability(String unitId) async {
    final uri = Uri.parse(ApiConfig.bookingsForUnitUrl(unitId));
    http.Response response;

    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException(
        'Could not reach the server at ${ApiConfig.baseUrl}. ${ApiConfig.connectivityHint}',
      );
    }

    if (response.statusCode != 200) {
      return const [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(UnitAvailabilityRange.fromJson)
        .toList();
  }

  Future<List<BookingRecord>> fetchMyBookings() async {
    final uri = Uri.parse(ApiConfig.bookingsMyUrl);
    http.Response response;

    try {
      response = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException(
        'Could not reach the server at ${ApiConfig.baseUrl}. ${ApiConfig.connectivityHint}',
      );
    }

    Map<String, dynamic>? errorBody;
    if (response.statusCode != 200) {
      try {
        errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {
        errorBody = null;
      }
      throw AuthException(
        errorBody?['error'] as String? ?? 'Failed to load bookings (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(BookingRecord.fromMyBookingJson)
        .toList();
  }

  Future<BookingRecord> fetchBookingDetail(String idOrRef) async {
    final uri = Uri.parse(ApiConfig.bookingUrl(idOrRef));
    http.Response response;

    try {
      response = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException(
        'Could not reach the server at ${ApiConfig.baseUrl}. ${ApiConfig.connectivityHint}',
      );
    }

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      payload = null;
    }

    if (response.statusCode != 200 || payload == null) {
      throw AuthException(
        payload?['error'] as String? ?? 'Failed to load booking (${response.statusCode}).',
      );
    }

    return BookingRecord.fromBookingDetailJson(payload);
  }

  Future<GuestBookingResult> createBooking(CreateBookingInput input) async {
    final uri = Uri.parse(ApiConfig.bookingsUrl);
    http.Response response;

    final body = {
      'listing_id': input.unitId,
      'check_in_date': _dateOnly(input.checkIn),
      'check_out_date': _dateOnly(input.checkOut),
      'total_guests': input.totalGuests,
      'add_ons': <Map<String, dynamic>>[],
      'payment_method': input.paymentMethod,
      'require_payment': input.requirePayment,
      'client': input.client,
      if (input.notes != null && input.notes!.trim().isNotEmpty) 'notes': input.notes!.trim(),
      if (input.notes != null && input.notes!.trim().isNotEmpty) 'request_description': input.notes!.trim(),
    };

    try {
      response = await http
          .post(uri, headers: _authHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AuthException(
        'Could not reach the server at ${ApiConfig.baseUrl}. ${ApiConfig.connectivityHint}',
      );
    }

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      payload = null;
    }

    if (response.statusCode == 201) {
      return GuestBookingResult(
        id: payload?['id']?.toString() ?? '',
        referenceCode: payload?['reference_code'] as String? ?? '',
        checkIn: payload?['check_in_date'] as String? ?? _dateOnly(input.checkIn),
        checkOut: payload?['check_out_date'] as String? ?? _dateOnly(input.checkOut),
        totalGuests: payload?['total_guests'] as int? ?? input.totalGuests,
        totalAmount: (payload?['total_amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: payload?['payment_method'] as String? ?? input.paymentMethod,
        status: payload?['status'] as String? ?? 'pending-payment',
      );
    }

    throw AuthException(
      payload?['error'] as String? ?? 'Booking failed (${response.statusCode}).',
    );
  }

  String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
