import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'config/api_config.dart';
import 'kelsey_brand.dart';
import 'models/unit_listing.dart';
import 'services/auth_service.dart';
import 'services/units_service.dart';
import 'unit_detail_screen.dart';
import 'utils/currency_utils.dart';
import 'utils/map_navigation.dart';
import 'widgets/unit_gallery_viewer.dart';

/// Map of available units using OpenStreetMap, sorted nearest → farthest via Haversine.
class NearbyCondosMapScreen extends StatefulWidget {
  const NearbyCondosMapScreen({super.key});

  @override
  State<NearbyCondosMapScreen> createState() => _NearbyCondosMapScreenState();
}

class _NearbyCondosMapScreenState extends State<NearbyCondosMapScreen> {
  static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);

  final MapController _mapController = MapController();
  final UnitsService _unitsService = const UnitsService();

  List<UnitListing> _units = [];
  bool _loadingUnits = true;
  String? _unitsError;

  LatLng? _userLocation;
  bool _loadingLocation = true;
  String? _locationNotice;

  bool _mapReady = false;
  bool _pendingFit = false;

  List<UnitListing> get _sortedUnits {
    if (_userLocation == null) return _units;
    return _unitsService.sortByDistance(_units, _userLocation!);
  }

  List<UnitListing> get _mappableUnits =>
      _sortedUnits.where((u) => u.latitude != null && u.longitude != null).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnits();
      _loadUserLocation();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _scheduleFitMap() {
    _pendingFit = true;
    if (!_mapReady || _mappableUnits.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingFit());
  }

  void _applyPendingFit() {
    if (!mounted || !_pendingFit || !_mapReady || _mappableUnits.isEmpty) return;
    _pendingFit = false;
    try {
      _fitMapToCondos();
    } catch (_) {
      _pendingFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pendingFit) return;
        try {
          _fitMapToCondos();
        } catch (_) {}
        _pendingFit = false;
      });
    }
  }

  void _onMapReady() {
    _mapReady = true;
    _applyPendingFit();
  }

  Future<void> _loadUnits() async {
    setState(() {
      _loadingUnits = true;
      _unitsError = null;
    });

    try {
      var units = await _unitsService.fetchUnits();
      if (_userLocation != null) {
        units = _unitsService.sortByDistance(units, _userLocation!);
      }
      if (!mounted) return;
      setState(() {
        _units = units;
        _loadingUnits = false;
      });
      _scheduleFitMap();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _unitsError = e.message;
        _loadingUnits = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unitsError = 'Could not load listings from the server.\n${ApiConfig.connectivityHint}';
        _loadingUnits = false;
      });
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationNotice = 'Turn on Location Services to sort stays by distance.';
          _loadingLocation = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationNotice = 'Location access denied. Stays are still listed below.';
          _loadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
        if (_units.isNotEmpty) {
          _units = _unitsService.sortByDistance(_units, _userLocation!);
        }
      });
      _scheduleFitMap();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationNotice = 'Could not read your location. Showing listing locations only.';
        _loadingLocation = false;
      });
    }
  }

  void _fitMapToCondos() {
    final points = _mappableUnits.map((u) => LatLng(u.latitude!, u.longitude!)).toList();
    if (points.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 96, 48, 280),
      ),
    );
  }

  Future<void> _openInMaps(UnitListing unit) async {
    if (unit.latitude == null || unit.longitude == null) return;
    final opened = await openLocationInMaps(
      latitude: unit.latitude!,
      longitude: unit.longitude!,
      label: unit.title,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps for this location.')),
      );
    }
  }

  void _focusUnit(UnitListing unit) {
    if (unit.latitude == null || unit.longitude == null) return;
    _mapController.move(LatLng(unit.latitude!, unit.longitude!), 15);
  }

  LatLng get _initialCenter {
    if (_mappableUnits.isNotEmpty) {
      final points = _mappableUnits.map((u) => LatLng(u.latitude!, u.longitude!)).toList();
      var latSum = 0.0;
      var lngSum = 0.0;
      for (final point in points) {
        latSum += point.latitude;
        lngSum += point.longitude;
      }
      return LatLng(latSum / points.length, lngSum / points.length);
    }
    if (_userLocation != null) return _userLocation!;
    return _defaultCenter;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final units = _sortedUnits;
    final isLoading = _loadingUnits || _loadingLocation;
    final hasLocationSort = _userLocation != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Condos near you'),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : _loadUnits,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loadingUnits
          ? const Center(child: CircularProgressIndicator())
          : _unitsError != null
              ? _ErrorBody(message: _unitsError!, onRetry: _loadUnits)
              : units.isEmpty
                  ? _ErrorBody(message: 'No available stays found.', onRetry: _loadUnits)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _initialCenter,
                                  initialZoom: 11,
                                  onMapReady: _onMapReady,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.drag |
                                        InteractiveFlag.pinchZoom |
                                        InteractiveFlag.doubleTapZoom,
                                  ),
                                  backgroundColor: const Color(0xFFE8E4DC),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.kelseyapp.kelseyapp',
                                  ),
                                  if (_userLocation != null)
                                    CircleLayer(
                                      circles: [
                                        CircleMarker(
                                          point: _userLocation!,
                                          radius: 8,
                                          useRadiusInMeter: false,
                                          color: Colors.blue.withValues(alpha: 0.2),
                                          borderColor: Colors.blue,
                                          borderStrokeWidth: 1.5,
                                        ),
                                      ],
                                    ),
                                  MarkerLayer(
                                    markers: _mappableUnits.map((unit) {
                                      final priceLabel = CurrencyUtils.formatAmount(
                                        unit.price,
                                        currency: unit.currency,
                                      );
                                      return Marker(
                                        point: LatLng(unit.latitude!, unit.longitude!),
                                        width: 108,
                                        height: 44,
                                        alignment: Alignment.bottomCenter,
                                        child: _MapPriceMarker(
                                          label: priceLabel,
                                          onTap: () {
                                            Navigator.of(context).push<void>(
                                              MaterialPageRoute<void>(
                                                builder: (_) => UnitDetailScreen(unit: unit),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                              if (_loadingLocation)
                                const Positioned(
                                  top: 16,
                                  left: 16,
                                  right: 16,
                                  child: _MapStatusBanner(
                                    icon: Icons.gps_fixed_rounded,
                                    message: 'Finding your location…',
                                  ),
                                )
                              else if (_locationNotice != null)
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  right: 16,
                                  child: _MapStatusBanner(
                                    icon: Icons.info_outline_rounded,
                                    message: _locationNotice!,
                                  ),
                                ),
                              if (_mappableUnits.isEmpty)
                                const Positioned(
                                  top: 16,
                                  left: 16,
                                  right: 16,
                                  child: _MapStatusBanner(
                                    icon: Icons.map_outlined,
                                    message: 'Listings have no map coordinates yet. See the list below.',
                                  ),
                                ),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Material(
                                  color: Colors.white,
                                  elevation: 3,
                                  shadowColor: Colors.black26,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: _mappableUnits.isEmpty ? null : _scheduleFitMap,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.center_focus_strong_rounded, size: 22),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                                  child: Text(
                                    hasLocationSort ? 'Nearest stays' : 'Available stays',
                                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                    itemCount: units.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final unit = units[index];
                                      return _UnitMapListTile(
                                        rank: hasLocationSort && unit.distanceKm != null && unit.distanceKm!.isFinite
                                            ? index + 1
                                            : null,
                                        unit: unit,
                                        onTap: () {
                                          Navigator.of(context).push<void>(
                                            MaterialPageRoute<void>(
                                              builder: (_) => UnitDetailScreen(unit: unit),
                                            ),
                                          );
                                        },
                                        onFocusMap: unit.latitude != null && unit.longitude != null
                                            ? () => _focusUnit(unit)
                                            : null,
                                        onOpenMaps: unit.latitude != null && unit.longitude != null
                                            ? () => _openInMaps(unit)
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _MapPriceMarker extends StatelessWidget {
  const _MapPriceMarker({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KelseyColors.tealButton, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: KelseyColors.tealButton,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: KelseyColors.tealButton,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _UnitMapListTile extends StatelessWidget {
  const _UnitMapListTile({
    required this.unit,
    required this.onTap,
    this.rank,
    this.onFocusMap,
    this.onOpenMaps,
  });

  final UnitListing unit;
  final VoidCallback onTap;
  final int? rank;
  final VoidCallback? onFocusMap;
  final VoidCallback? onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (rank != null) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: KelseyColors.tealButton,
                  child: Text(
                    '$rank',
                    style: textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                onTap: () => UnitGalleryViewer.openForUnit(context, unit),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: unit.mainImageUrl.isEmpty
                      ? SizedBox(
                          width: 72,
                          height: 72,
                          child: ColoredBox(
                            color: KelseyColors.tealButton.withValues(alpha: 0.15),
                            child: const Icon(Icons.night_shelter_outlined, color: KelseyColors.tealButton),
                          ),
                        )
                      : Image.network(
                          unit.mainImageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => ColoredBox(
                            color: KelseyColors.tealButton.withValues(alpha: 0.15),
                            child: const Icon(Icons.broken_image_outlined, color: KelseyColors.tealButton),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unit.locationLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      unit.distanceLabel ?? unit.priceLabel,
                      style: textTheme.labelLarge?.copyWith(
                        color: KelseyColors.tealButton,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onFocusMap != null)
                IconButton(
                  tooltip: 'Show on map',
                  onPressed: onFocusMap,
                  icon: const Icon(Icons.place_outlined),
                  color: KelseyColors.tealButton,
                ),
              if (onOpenMaps != null)
                IconButton(
                  tooltip: Platform.isIOS ? 'Open in Apple Maps' : 'Open in Maps',
                  onPressed: onOpenMaps,
                  icon: Icon(Platform.isIOS ? Icons.map_outlined : Icons.map_rounded),
                  color: KelseyColors.tealButton,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _MapStatusBanner extends StatelessWidget {
  const _MapStatusBanner({
    required this.icon,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 8 : 10),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, size: 18, color: KelseyColors.tealButton),
            const SizedBox(width: 10),
            if (compact)
              Text(
                message,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              )
            else
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
