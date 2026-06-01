import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/api_config.dart';
import '../models/unit_listing.dart';
import 'auth_service.dart';

class UnitsService {
  const UnitsService();

  Future<List<UnitListing>> fetchUnits({String? search}) async {
    final query = <String, String>{'limit': '50'};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final uri = Uri.parse(ApiConfig.unitsUrl).replace(queryParameters: query);
    http.Response response;

    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AuthException(
        'Could not reach the server at ${ApiConfig.baseUrl}. ${ApiConfig.connectivityHint}',
      );
    }

    if (response.statusCode != 200) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {
        body = null;
      }
      throw AuthException(body?['error'] as String? ?? 'Failed to load listings (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(UnitListing.fromJson)
        .where((u) => u.id.isNotEmpty)
        .toList();
  }

  Future<UnitListing> fetchUnitById(String id) async {
    final uri = Uri.parse(ApiConfig.unitUrl(id));
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw AuthException('Could not load listing details.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final listing = UnitListing.fromJson(body);
    final images = body['image_urls'];
    String imageUrl = listing.mainImageUrl;
    if (imageUrl.isEmpty && images is List && images.isNotEmpty) {
      imageUrl = ApiConfig.resolveMediaUrl(images.first.toString());
    }
    return UnitListing(
      id: listing.id,
      title: listing.title,
      location: listing.location,
      city: listing.city,
      country: listing.country,
      price: listing.price,
      currency: listing.currency,
      mainImageUrl: imageUrl,
      bedrooms: listing.bedrooms,
      bathrooms: listing.bathrooms,
      propertyType: listing.propertyType,
      isFeatured: listing.isFeatured,
      latitude: listing.latitude,
      longitude: listing.longitude,
      description: body['description'] as String? ?? listing.description,
      maxCapacity: listing.maxCapacity,
      checkInTime: body['check_in_time'] as String? ?? listing.checkInTime,
      checkOutTime: body['check_out_time'] as String? ?? listing.checkOutTime,
    );
  }

  List<UnitListing> sortByDistance(List<UnitListing> units, LatLng userLocation) {
    const distance = Distance();
    final withDistance = units.map((unit) {
      if (unit.latitude == null || unit.longitude == null) {
        return unit.copyWith(distanceKm: double.infinity);
      }
      final km = distance.as(
        LengthUnit.Kilometer,
        userLocation,
        LatLng(unit.latitude!, unit.longitude!),
      );
      return unit.copyWith(distanceKm: km);
    }).toList();

    withDistance.sort((a, b) => (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity));
    return withDistance;
  }

  List<UnitListing> filterNearMe(List<UnitListing> units, LatLng userLocation, {double radiusKm = 50}) {
    return sortByDistance(units, userLocation)
        .where((u) => u.distanceKm != null && u.distanceKm! <= radiusKm && u.distanceKm!.isFinite)
        .toList();
  }
}
