import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'auth_shared.dart';
import 'config/api_config.dart';
import 'kelsey_brand.dart';
import 'models/unit_listing.dart';
import 'nearby_condos_map_screen.dart';
import 'services/auth_service.dart';
import 'services/units_service.dart';
import 'unit_detail_screen.dart';
import 'utils/network_utils.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final UnitsService _unitsService = const UnitsService();
  final TextEditingController _searchController = TextEditingController();

  List<UnitListing> _units = [];
  bool _loading = true;
  String? _error;
  bool _nearMeActive = false;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var units = await _unitsService.fetchUnits(search: search);
      if (_nearMeActive && _userLocation != null) {
        units = _unitsService.sortByDistance(units, _userLocation!);
      }
      if (!mounted) return;
      setState(() {
        _units = units;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _units = [];
        _error = isOfflineError(e) ? 'You are offline.' : e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _units = [];
        _error = isOfflineError(e) ? 'You are offline.' : 'Could not load listings.\n${ApiConfig.connectivityHint}';
        _loading = false;
      });
    }
  }

  Future<void> _openSearchSheet() async {
    final controller = TextEditingController(text: _searchController.text);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bottom = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Search stays',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: kelseyAuthInputDecoration('Name, city, or location'),
                onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: KelseyColors.tealButton,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;
    _searchController.text = result;
    await _loadUnits(search: result.isEmpty ? null : result);
  }

  Future<void> _toggleNearMe() async {
    if (_nearMeActive) {
      setState(() => _nearMeActive = false);
      await _loadUnits(search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim());
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on Location Services to use Near me.')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required for Near me.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      if (!mounted) return;
      setState(() {
        _nearMeActive = true;
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      await _loadUnits(search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your location.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => _loadUnits(
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      ),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            surfaceTintColor: Colors.transparent,
            backgroundColor: scheme.surface,
            title: const Text('Home'),
            actions: [
              IconButton(
                tooltip: 'Search',
                onPressed: _openSearchSheet,
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Find your stay',
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse homestays and condos from kelseybackend.',
                    style: textTheme.bodyMedium?.copyWith(color: KelseyColors.cardMuted),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.search_rounded, size: 18),
                        label: Text(_searchController.text.isEmpty ? 'Search' : _searchController.text),
                        onPressed: _openSearchSheet,
                      ),
                      FilterChip(
                        selected: _nearMeActive,
                        avatar: Icon(
                          Icons.near_me_rounded,
                          size: 18,
                          color: _nearMeActive ? Colors.white : KelseyColors.tealButton,
                        ),
                        label: const Text('Near me'),
                        selectedColor: KelseyColors.tealButton,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _nearMeActive ? Colors.white : null,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => _toggleNearMe(),
                      ),
                      if (_searchController.text.isNotEmpty)
                        ActionChip(
                          label: const Text('Clear search'),
                          onPressed: () {
                            _searchController.clear();
                            _loadUnits();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(builder: (_) => const NearbyCondosMapScreen()),
                      );
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KelseyColors.tealButton,
                      side: const BorderSide(color: KelseyColors.tealButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center, style: textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _loadUnits(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_units.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  _nearMeActive ? 'No stays found near your location.' : 'No stays found.',
                  style: textTheme.bodyLarge?.copyWith(color: KelseyColors.cardMuted),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList.separated(
                itemCount: _units.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) => _UnitListingCard(unit: _units[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnitListingCard extends StatelessWidget {
  const _UnitListingCard({required this.unit});

  final UnitListing unit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => UnitDetailScreen(unit: unit)),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: unit.mainImageUrl.isEmpty
                  ? ColoredBox(
                      color: KelseyColors.tealButton.withValues(alpha: 0.15),
                      child: const Icon(Icons.night_shelter_outlined, size: 48, color: KelseyColors.tealButton),
                    )
                  : Image.network(
                      unit.mainImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: KelseyColors.tealButton.withValues(alpha: 0.15),
                        child: const Icon(Icons.broken_image_outlined, size: 48, color: KelseyColors.tealButton),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          unit.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (unit.isFeatured)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: KelseyColors.yellow.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Featured',
                            style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: KelseyColors.cardMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          unit.locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(color: KelseyColors.cardMuted),
                        ),
                      ),
                    ],
                  ),
                  if (unit.distanceLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      unit.distanceLabel!,
                      style: textTheme.labelLarge?.copyWith(
                        color: KelseyColors.tealButton,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    unit.priceLabel,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: KelseyColors.tealButton,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
