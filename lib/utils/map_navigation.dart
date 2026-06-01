import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

/// Opens the property location in Apple Maps (iOS) or Google Maps.
Future<bool> openLocationInMaps({
  required double latitude,
  required double longitude,
  required String label,
}) async {
  if (latitude == 0 && longitude == 0) return false;

  final encodedLabel = Uri.encodeComponent(label);
  final uri = Platform.isIOS
      ? Uri.parse('https://maps.apple.com/?ll=$latitude,$longitude&q=$encodedLabel')
      : Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');

  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

bool hasMapCoordinates(double latitude, double longitude) {
  return latitude != 0 || longitude != 0;
}
