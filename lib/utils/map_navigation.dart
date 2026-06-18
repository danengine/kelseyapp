import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

/// Opens the property location in Apple Maps (iOS) or Google Maps (Android).
Future<bool> openLocationInMaps({
  required double latitude,
  required double longitude,
  required String label,
}) async {
  if (latitude == 0 && longitude == 0) return false;

  final encodedLabel = Uri.encodeComponent(label);
  final candidates = Platform.isIOS
      ? <Uri>[
          Uri.parse('maps://?ll=$latitude,$longitude&q=$encodedLabel'),
          Uri.parse('https://maps.apple.com/?ll=$latitude,$longitude&q=$encodedLabel'),
        ]
      : <Uri>[
          Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($encodedLabel)'),
          Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'),
        ];

  for (final uri in candidates) {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {
      // Try the next URL scheme.
    }
  }

  return false;
}

bool hasMapCoordinates(double latitude, double longitude) {
  return latitude != 0 || longitude != 0;
}
