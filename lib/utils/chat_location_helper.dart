import 'package:geolocator/geolocator.dart';

/// Resolves device location for the in-app chatbot (near-me queries).
class ChatLocationHelper {
  ChatLocationHelper._();

  static const _cacheMaxAge = Duration(minutes: 3);

  static Position? _cached;
  static DateTime? _cachedAt;

  /// Warm location cache when the chat screen opens.
  static Future<void> prefetch() async {
    final position = await _fetchLocation(requestIfDenied: false);
    if (position != null) {
      _cached = position;
      _cachedAt = DateTime.now();
    }
  }

  /// Returns coordinates for a near-me chat message, or null if unavailable.
  static Future<Position?> forNearMeQuery({bool requestIfDenied = true}) async {
    if (_cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheMaxAge) {
      return _cached;
    }

    final position = await _fetchLocation(requestIfDenied: requestIfDenied);
    if (position != null) {
      _cached = position;
      _cachedAt = DateTime.now();
    }
    return position;
  }

  static Future<Position?> _fetchLocation({required bool requestIfDenied}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestIfDenied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  static void clearCache() {
    _cached = null;
    _cachedAt = null;
  }
}
