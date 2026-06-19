import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'config/api_config.dart';
import 'kelsey_brand.dart';
import 'models/unit_listing.dart';
import 'nearby_condos_map_screen.dart';
import 'services/auth_service.dart';
import 'services/units_service.dart';
import 'unit_detail_screen.dart';
import 'utils/network_utils.dart';

const _homeTeal = Color(0xFF0B5858);

/// Home tab — mirrors web `/home` (Hero + search + featured listings).
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final UnitsService _unitsService = const UnitsService();

  List<UnitListing> _featured = const [];
  List<UnitListing> _allUnits = const [];
  List<UnitListing> _displayUnits = const [];
  List<String> _cities = const [];

  bool _loading = true;
  bool _showAllListings = false;
  String? _error;

  String _searchLocation = '';
  RangeValues _priceRange = const RangeValues(0, 10000);
  bool _nearMeActive = false;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _unitsService.fetchUnits(featured: true, limit: 3),
        _unitsService.fetchUnits(limit: 100),
      ]);
      final featured = results[0];
      var all = results[1];
      final cities = all.map((u) => u.city).where((c) => c.isNotEmpty).toSet().toList()..sort();

      if (_nearMeActive && _userLocation != null) {
        all = _unitsService.sortByDistance(all, _userLocation!);
      }

      if (!mounted) return;
      setState(() {
        _featured = featured;
        _allUnits = all;
        _cities = cities;
        _displayUnits = _showAllListings ? _applyFilters(all) : featured;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = isOfflineError(e) ? 'You are offline.' : e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = isOfflineError(e) ? 'You are offline.' : 'Could not load listings.\n${ApiConfig.connectivityHint}';
        _loading = false;
      });
    }
  }

  List<UnitListing> _applyFilters(List<UnitListing> source) {
    return source.where((unit) {
      if (_searchLocation.isNotEmpty &&
          !unit.city.toLowerCase().contains(_searchLocation.toLowerCase()) &&
          !unit.location.toLowerCase().contains(_searchLocation.toLowerCase())) {
        return false;
      }
      if (unit.price < _priceRange.start || unit.price > _priceRange.end) return false;
      return true;
    }).toList();
  }

  void _runSearch() {
    setState(() {
      _showAllListings = true;
      _displayUnits = _applyFilters(_allUnits);
    });
  }

  void _viewAllListings() {
    setState(() {
      _showAllListings = true;
      _displayUnits = _applyFilters(_allUnits);
    });
  }

  Future<void> _toggleNearMe() async {
    if (_nearMeActive) {
      setState(() => _nearMeActive = false);
      await _loadHome();
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
        _showAllListings = true;
      });
      await _loadHome();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your location.')),
      );
    }
  }

  Future<void> _pickLocation() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Search location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                title: const Text('Any'),
                onTap: () => Navigator.pop(context, ''),
              ),
              ..._cities.map(
                (city) => ListTile(
                  title: Text(city),
                  onTap: () => Navigator.pop(context, city),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() => _searchLocation = selected);
  }

  Future<void> _pickPriceRange() async {
    var range = _priceRange;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Price range',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '₱${range.start.round().toStringAsFixed(0)} – ₱${range.end.round().toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: _homeTeal),
                  ),
                  RangeSlider(
                    values: range,
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    activeColor: _homeTeal,
                    onChanged: (v) => setModalState(() => range = v),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() => range = const RangeValues(0, 10000));
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: _homeTeal),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() => _priceRange = range);
  }

  @override
  Widget build(BuildContext context) {
    final heroImage = _featured.isNotEmpty && _featured.first.mainImageUrl.isNotEmpty
        ? _featured.first.mainImageUrl
        : ApiConfig.resolveMediaUrl('/heroimage.png');

    return RefreshIndicator(
      onRefresh: _loadHome,
      edgeOffset: MediaQuery.paddingOf(context).top,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _HomeHero(
              heroImageUrl: heroImage,
              searchLocation: _searchLocation,
              priceRange: _priceRange,
              onLocationTap: _pickLocation,
              onPriceTap: _pickPriceRange,
              onSearch: _runSearch,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _showAllListings ? 'All listings' : 'Featured listings',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _toggleNearMe,
                        icon: Icon(
                          Icons.near_me_rounded,
                          size: 18,
                          color: _nearMeActive ? _homeTeal : KelseyColors.cardMuted,
                        ),
                        label: Text(
                          'Near me',
                          style: TextStyle(
                            color: _nearMeActive ? _homeTeal : KelseyColors.cardMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(builder: (_) => const NearbyCondosMapScreen()),
                      );
                    },
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Open map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _homeTeal,
                      side: const BorderSide(color: _homeTeal),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: _ListingsSkeleton(),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _homeTeal),
                      onPressed: _loadHome,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          else if (_displayUnits.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No available listings. Try adjusting your search.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: KelseyColors.cardMuted),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverList.separated(
                itemCount: _displayUnits.length,
                separatorBuilder: (_, _) => const SizedBox(height: 20),
                itemBuilder: (context, index) => _PropertyCard(unit: _displayUnits[index]),
              ),
            ),
          if (!_loading && _error == null && !_showAllListings && _displayUnits.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _viewAllListings,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _homeTeal,
                      side: const BorderSide(color: _homeTeal, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'View All Listings',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.heroImageUrl,
    required this.searchLocation,
    required this.priceRange,
    required this.onLocationTap,
    required this.onPriceTap,
    required this.onSearch,
  });

  final String heroImageUrl;
  final String searchLocation;
  final RangeValues priceRange;
  final VoidCallback onLocationTap;
  final VoidCallback onPriceTap;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 300 + top,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                heroImageUrl,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.2),
                errorBuilder: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0D6B6B), _homeTeal, KelseyColors.background],
                    ),
                  ),
                ),
              ),
              Container(color: Colors.black.withValues(alpha: 0.25)),
              Padding(
                padding: EdgeInsets.fromLTRB(20, top + 24, 20, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Feel at home anytime,\nanywhere!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Find your perfect home away from home\nwhile you\'re on your dream vacation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              elevation: 8,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _SearchField(
                      label: 'Search Location',
                      value: searchLocation.isEmpty ? 'Any' : searchLocation,
                      onTap: onLocationTap,
                    ),
                    const Divider(height: 20),
                    _SearchField(
                      label: 'Price Range',
                      value: '₱${priceRange.start.round()} - ₱${priceRange.end.round()}',
                      onTap: onPriceTap,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _homeTeal,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: onSearch,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Search'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.unit});

  final UnitListing unit;

  String get _propertyTypeLabel {
    if (unit.propertyType.isEmpty) return 'Property';
    final t = unit.propertyType;
    return t[0].toUpperCase() + t.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => UnitDetailScreen(unit: unit)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: unit.mainImageUrl.isEmpty
                      ? ColoredBox(
                          color: _homeTeal.withValues(alpha: 0.12),
                          child: const Icon(Icons.night_shelter_outlined, size: 48, color: _homeTeal),
                        )
                      : Image.network(
                          unit.mainImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: _homeTeal.withValues(alpha: 0.12),
                            child: const Icon(Icons.broken_image_outlined, color: _homeTeal),
                          ),
                        ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.2), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _propertyTypeLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                            children: [
                              TextSpan(text: '${unit.currency} ${unit.price.toStringAsFixed(0)}'),
                              TextSpan(
                                text: ' / night',
                                style: textTheme.bodySmall?.copyWith(
                                  color: KelseyColors.cardMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (unit.isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _homeTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Featured',
                            style: TextStyle(
                              color: _homeTeal,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unit.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade500),
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
                        color: _homeTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _FeatureChip(icon: Icons.bed_outlined, label: '${unit.bedrooms} bed'),
                      const SizedBox(width: 16),
                      _FeatureChip(icon: Icons.bathtub_outlined, label: '${unit.bathrooms} bath'),
                      if (unit.squareFeet != null) ...[
                        const SizedBox(width: 16),
                        _FeatureChip(icon: Icons.square_foot_outlined, label: '${unit.squareFeet} sqft'),
                      ],
                    ],
                  ),
                  if (unit.amenities.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...unit.amenities.take(3).map(
                              (a) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(a, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                              ),
                            ),
                        if (unit.amenities.length > 3)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+${unit.amenities.length - 3} more',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (unit.description != null && unit.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      unit.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ListingsSkeleton extends StatelessWidget {
  const _ListingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
