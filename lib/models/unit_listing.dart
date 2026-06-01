import '../config/api_config.dart';
import '../utils/currency_utils.dart';

class UnitListing {
  const UnitListing({
    required this.id,
    required this.title,
    required this.location,
    required this.city,
    required this.country,
    required this.price,
    required this.currency,
    required this.mainImageUrl,
    required this.bedrooms,
    required this.bathrooms,
    required this.propertyType,
    required this.isFeatured,
    this.latitude,
    this.longitude,
    this.description,
    this.maxCapacity,
    this.distanceKm,
    this.checkInTime,
    this.checkOutTime,
  });

  final String id;
  final String title;
  final String location;
  final String city;
  final String country;
  final double price;
  final String currency;
  final String mainImageUrl;
  final int bedrooms;
  final int bathrooms;
  final String propertyType;
  final bool isFeatured;
  final double? latitude;
  final double? longitude;
  final String? description;
  final int? maxCapacity;
  final double? distanceKm;
  final String? checkInTime;
  final String? checkOutTime;

  String get locationLabel {
    if (location.isNotEmpty) return location;
    final parts = [city, country].where((p) => p.isNotEmpty);
    return parts.join(', ');
  }

  String get priceLabel => CurrencyUtils.formatPerNight(price, currency: currency);

  String? get distanceLabel {
    final km = distanceKm;
    if (km == null) return null;
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  factory UnitListing.fromJson(Map<String, dynamic> json) {
    return UnitListing(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      location: json['location'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: CurrencyUtils.normalizeSymbol(json['currency'] as String?),
      mainImageUrl: ApiConfig.resolveMediaUrl(json['main_image_url'] as String?),
      bedrooms: (json['bedrooms'] as num?)?.toInt() ?? 0,
      bathrooms: (json['bathrooms'] as num?)?.toInt() ?? 0,
      propertyType: json['property_type'] as String? ?? 'unit',
      isFeatured: json['is_featured'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      description: json['description'] as String?,
      maxCapacity: (json['max_capacity'] as num?)?.toInt(),
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
    );
  }

  UnitListing copyWith({
    double? distanceKm,
    String? checkInTime,
    String? checkOutTime,
  }) {
    return UnitListing(
      id: id,
      title: title,
      location: location,
      city: city,
      country: country,
      price: price,
      currency: currency,
      mainImageUrl: mainImageUrl,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      propertyType: propertyType,
      isFeatured: isFeatured,
      latitude: latitude,
      longitude: longitude,
      description: description,
      maxCapacity: maxCapacity,
      distanceKm: distanceKm ?? this.distanceKm,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
    );
  }
}
