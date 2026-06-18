import 'config/api_config.dart';
import 'models/unit_listing.dart';

/// Homestay booking / listing row used in the list and detail screens.
enum BookingStatus { pending, booked, completed, cancelled }

class BookingRecord {
  const BookingRecord({
    required this.id,
    required this.listingTitle,
    required this.unitLabel,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    required this.galleryImageUrls,
    required this.rating,
    required this.address,
    required this.guestsSummary,
    required this.bedsSummary,
    required this.pricePerNight,
    required this.latitude,
    required this.longitude,
    this.referenceCode,
    this.totalGuests,
    this.totalAmount,
    this.transactionNumber,
    this.paymentMethod,
    this.paymentStatus,
    this.nights,
    this.clientName,
    this.clientEmail,
    this.notes,
  });

  final String id;
  final String listingTitle;
  final String unitLabel;
  final DateTime checkIn;
  final DateTime checkOut;
  final BookingStatus status;
  final List<String> galleryImageUrls;
  final double rating;
  final String address;
  final String guestsSummary;
  final String bedsSummary;
  final double pricePerNight;
  final double latitude;
  final double longitude;
  final String? referenceCode;
  final int? totalGuests;
  final double? totalAmount;
  final String? transactionNumber;
  final String? paymentMethod;
  final String? paymentStatus;
  final int? nights;
  final String? clientName;
  final String? clientEmail;
  final String? notes;

  String get heroImageUrl => galleryImageUrls.isNotEmpty ? galleryImageUrls.first : '';

  String get statusLabel {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.booked:
        return 'Booked';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  int get stayNights {
    if (nights != null && nights! > 0) return nights!;
    final inDate = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final outDate = DateTime(checkOut.year, checkOut.month, checkOut.day);
    final days = outDate.difference(inDate).inDays;
    return days < 1 ? 1 : days;
  }

  String get bookingKey => referenceCode?.isNotEmpty == true ? referenceCode! : id;

  factory BookingRecord.fromMyBookingJson(Map<String, dynamic> json) {
    final listing = json['listing'] as Map<String, dynamic>? ?? {};
    final imageUrl = ApiConfig.resolveMediaUrl(listing['main_image_url'] as String?);
    final checkInRaw = json['check_in_date'] as String? ?? '';
    final checkOutRaw = json['check_out_date'] as String? ?? '';
    final guests = json['total_guests'] as int? ?? 1;
    final payment = json['payment'] as Map<String, dynamic>?;
    final checkIn = DateTime.parse(checkInRaw);
    final checkOut = DateTime.parse(checkOutRaw);
    final nightCount = checkOut.difference(checkIn).inDays;

    return BookingRecord(
      id: json['id']?.toString() ?? '',
      referenceCode: json['reference_code'] as String?,
      listingTitle: listing['title'] as String? ?? 'Stay',
      unitLabel: listing['location'] as String? ?? 'Unit',
      checkIn: checkIn.copyWith(hour: 15),
      checkOut: checkOut.copyWith(hour: 11),
      status: _statusFromApi(_resolveBookingStatusRaw(json)),
      galleryImageUrls: imageUrl.isNotEmpty ? [imageUrl] : const [],
      rating: 0,
      address: listing['location'] as String? ?? '',
      guestsSummary: guests == 1 ? '1 guest' : '$guests guests',
      bedsSummary: '',
      pricePerNight: (listing['base_price'] as num?)?.toDouble() ?? 0,
      latitude: (listing['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (listing['longitude'] as num?)?.toDouble() ?? 0,
      totalGuests: guests,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      transactionNumber: json['transaction_number'] as String? ?? payment?['reference_number'] as String?,
      paymentMethod: payment?['payment_method'] as String?,
      paymentStatus: payment?['status'] as String? ?? payment?['payment_status'] as String?,
      nights: nightCount > 0 ? nightCount : 1,
    );
  }

  factory BookingRecord.fromCreatedBooking({
    required String id,
    required String referenceCode,
    required UnitListing unit,
    required DateTime checkIn,
    required DateTime checkOut,
    required int totalGuests,
    required double totalAmount,
    String? paymentMethod,
  }) {
    final nights = checkOut.difference(checkIn).inDays;
    return BookingRecord(
      id: id,
      referenceCode: referenceCode.isNotEmpty ? referenceCode : null,
      listingTitle: unit.title,
      unitLabel: unit.location,
      checkIn: checkIn,
      checkOut: checkOut,
      status: BookingStatus.pending,
      galleryImageUrls: unit.mainImageUrl.isNotEmpty ? [unit.mainImageUrl] : const [],
      rating: 0,
      address: unit.location,
      guestsSummary: totalGuests == 1 ? '1 guest' : '$totalGuests guests',
      bedsSummary: '',
      pricePerNight: unit.price,
      latitude: unit.latitude ?? 0,
      longitude: unit.longitude ?? 0,
      totalGuests: totalGuests,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      paymentStatus: 'pending',
      nights: nights > 0 ? nights : 1,
    );
  }

  factory BookingRecord.fromBookingDetailJson(Map<String, dynamic> json) {
    final listing = json['listing'] as Map<String, dynamic>? ?? {};
    final imageUrl = ApiConfig.resolveMediaUrl(listing['main_image_url'] as String?);
    final checkInRaw = json['check_in_date'] as String? ?? '';
    final checkOutRaw = json['check_out_date'] as String? ?? '';
    final guests = json['total_guests'] as int? ?? 1;
    final payment = json['payment'] as Map<String, dynamic>?;
    final client = json['client'] as Map<String, dynamic>? ?? {};
    final first = client['first_name'] as String? ?? '';
    final last = client['last_name'] as String? ?? '';
    final clientName = [first, last].where((p) => p.trim().isNotEmpty).join(' ').trim();

    return BookingRecord(
      id: json['id']?.toString() ?? '',
      referenceCode: json['reference_code'] as String?,
      listingTitle: listing['title'] as String? ?? 'Stay',
      unitLabel: listing['location'] as String? ?? '',
      checkIn: DateTime.parse(checkInRaw).copyWith(hour: 15),
      checkOut: DateTime.parse(checkOutRaw).copyWith(hour: 11),
      status: _statusFromApi(_resolveBookingStatusRaw(json)),
      galleryImageUrls: imageUrl.isNotEmpty ? [imageUrl] : const [],
      rating: 0,
      address: listing['location'] as String? ?? '',
      guestsSummary: guests == 1 ? '1 guest' : '$guests guests',
      bedsSummary: '',
      pricePerNight: (json['unit_charge'] as num?)?.toDouble() ?? 0,
      latitude: (listing['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (listing['longitude'] as num?)?.toDouble() ?? 0,
      totalGuests: guests,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      transactionNumber: payment?['reference_number'] as String?,
      paymentMethod: payment?['payment_method'] as String?,
      paymentStatus: payment?['payment_status'] as String?,
      nights: json['nights'] as int?,
      clientName: clientName.isEmpty ? null : clientName,
      clientEmail: client['email'] as String?,
      notes: json['notes'] as String? ?? json['request_description'] as String?,
    );
  }

  factory BookingRecord.fromJson(Map<String, dynamic> json) {
    return BookingRecord(
      id: json['id'] as String? ?? '',
      referenceCode: json['referenceCode'] as String?,
      listingTitle: json['listingTitle'] as String? ?? '',
      unitLabel: json['unitLabel'] as String? ?? '',
      checkIn: DateTime.parse(json['checkIn'] as String),
      checkOut: DateTime.parse(json['checkOut'] as String),
      status: _statusFromApi(
        json['rawStatus'] as String? ?? json['status'] as String? ?? 'pending',
      ),
      galleryImageUrls: (json['galleryImageUrls'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String? ?? '',
      guestsSummary: json['guestsSummary'] as String? ?? '',
      bedsSummary: json['bedsSummary'] as String? ?? '',
      pricePerNight: (json['pricePerNight'] as num?)?.toDouble() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      totalGuests: json['totalGuests'] as int?,
      totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      transactionNumber: json['transactionNumber'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
      nights: json['nights'] as int?,
      clientName: json['clientName'] as String?,
      clientEmail: json['clientEmail'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'referenceCode': referenceCode,
        'listingTitle': listingTitle,
        'unitLabel': unitLabel,
        'checkIn': checkIn.toIso8601String(),
        'checkOut': checkOut.toIso8601String(),
        'status': status.name,
        'rawStatus': _rawStatusFromEnum(status),
        'galleryImageUrls': galleryImageUrls,
        'rating': rating,
        'address': address,
        'guestsSummary': guestsSummary,
        'bedsSummary': bedsSummary,
        'pricePerNight': pricePerNight,
        'latitude': latitude,
        'longitude': longitude,
        'totalGuests': totalGuests,
        'totalAmount': totalAmount,
        'transactionNumber': transactionNumber,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'nights': nights,
        'clientName': clientName,
        'clientEmail': clientEmail,
        'notes': notes,
      };

  static String _resolveBookingStatusRaw(Map<String, dynamic> json) {
    final status = json['status']?.toString().toLowerCase().trim();
    final raw = json['raw_status']?.toString().toLowerCase().trim();
    final bookingStatus = json['booking_status']?.toString().toLowerCase().trim();

    // Trust mapped terminal states from the API first.
    if (status == 'cancelled' || status == 'canceled') return 'cancelled';
    if (status == 'completed') return 'completed';
    if (status == 'booked') return 'confirmed';

    if (raw == 'cancelled' || raw == 'canceled') return 'cancelled';
    if (raw == 'completed') return 'completed';
    if (raw == 'confirmed') return 'confirmed';

    if (bookingStatus == 'cancelled' || bookingStatus == 'canceled') return 'cancelled';
    if (bookingStatus == 'completed') return 'completed';
    if (bookingStatus == 'confirmed') return 'confirmed';

    if (raw != null && raw.isNotEmpty) return raw;
    if (bookingStatus != null && bookingStatus.isNotEmpty) return bookingStatus;
    if (status != null && status.isNotEmpty) return status;
    return 'pending';
  }

  static String _rawStatusFromEnum(BookingStatus status) {
    switch (status) {
      case BookingStatus.booked:
        return 'confirmed';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
      case BookingStatus.pending:
        return 'penciled';
    }
  }

  static BookingStatus _statusFromApi(String raw) {
    switch (raw.toLowerCase()) {
      case 'booked':
      case 'confirmed':
        return BookingStatus.booked;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
      case 'canceled':
        return BookingStatus.cancelled;
      case 'pending':
      case 'pending-payment':
      case 'penciled':
      default:
        return BookingStatus.pending;
    }
  }
}
