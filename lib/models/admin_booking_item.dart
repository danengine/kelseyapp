import '../booking_models.dart';
import '../config/api_config.dart';

/// Admin list row from `GET /api/bookings/all`.
class AdminBookingItem {
  const AdminBookingItem({
    required this.id,
    required this.referenceCode,
    required this.listingTitle,
    required this.location,
    required this.imageUrl,
    required this.checkIn,
    required this.checkOut,
    required this.totalGuests,
    required this.totalAmount,
    required this.status,
    required this.rawStatus,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    this.agentName,
    this.paymentMethod,
    this.paymentStatus,
    this.penciledAt,
    this.nights,
  });

  final String id;
  final String referenceCode;
  final String listingTitle;
  final String location;
  final String imageUrl;
  final DateTime checkIn;
  final DateTime checkOut;
  final int totalGuests;
  final double totalAmount;
  final BookingStatus status;
  final String rawStatus;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final String? agentName;
  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime? penciledAt;
  final int? nights;

  bool get canApproveOrDecline => status == BookingStatus.pending;

  String get statusLabel {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.booked:
        return 'Booked';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Declined';
    }
  }

  factory AdminBookingItem.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'] as Map<String, dynamic>? ?? {};
    final client = json['client'] as Map<String, dynamic>? ?? {};
    final agent = json['agent'] as Map<String, dynamic>? ?? {};
    final payment = json['payment'] as Map<String, dynamic>?;

    final first = client['first_name'] as String? ?? '';
    final last = client['last_name'] as String? ?? '';
    final clientName = [first, last].where((p) => p.trim().isNotEmpty).join(' ').trim();

    final agentFirst = agent['first_name'] as String? ?? '';
    final agentLast = agent['last_name'] as String? ?? '';
    final agentName = [agentFirst, agentLast].where((p) => p.trim().isNotEmpty).join(' ').trim();

    final raw = json['raw_status']?.toString() ?? json['status']?.toString() ?? 'penciled';
    final checkIn = DateTime.parse(json['check_in_date'] as String);
    final checkOut = DateTime.parse(json['check_out_date'] as String);

    return AdminBookingItem(
      id: json['id']?.toString() ?? '',
      referenceCode: json['reference_code'] as String? ?? '',
      listingTitle: listing['title'] as String? ?? 'Stay',
      location: listing['location'] as String? ?? '',
      imageUrl: ApiConfig.resolveMediaUrl(listing['main_image_url'] as String?),
      checkIn: checkIn,
      checkOut: checkOut,
      totalGuests: json['total_guests'] as int? ?? 1,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      status: _statusFromRaw(raw),
      rawStatus: raw,
      clientName: clientName.isEmpty ? 'Guest' : clientName,
      clientEmail: client['email'] as String? ?? '',
      clientPhone: client['contact_number'] as String? ?? '',
      agentName: agentName.isEmpty ? null : agentName,
      paymentMethod: payment?['payment_method'] as String?,
      paymentStatus: payment?['status'] as String?,
      penciledAt: json['penciled_at'] != null ? DateTime.tryParse(json['penciled_at'].toString()) : null,
      nights: json['nights'] as int?,
    );
  }

  static BookingStatus _statusFromRaw(String raw) {
    switch (raw.toLowerCase()) {
      case 'confirmed':
        return BookingStatus.booked;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'penciled':
      default:
        return BookingStatus.pending;
    }
  }
}

enum AdminBookingFilter { all, pending, booked, declined }

extension AdminBookingFilterX on AdminBookingFilter {
  String get label {
    switch (this) {
      case AdminBookingFilter.all:
        return 'All';
      case AdminBookingFilter.pending:
        return 'Pending';
      case AdminBookingFilter.booked:
        return 'Booked';
      case AdminBookingFilter.declined:
        return 'Declined';
    }
  }

  bool matches(AdminBookingItem item) {
    switch (this) {
      case AdminBookingFilter.all:
        return true;
      case AdminBookingFilter.pending:
        return item.status == BookingStatus.pending;
      case AdminBookingFilter.booked:
        return item.status == BookingStatus.booked || item.status == BookingStatus.completed;
      case AdminBookingFilter.declined:
        return item.status == BookingStatus.cancelled;
    }
  }
}
