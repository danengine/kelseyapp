import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'book_unit_sheet.dart';
import 'config/api_config.dart';
import 'kelsey_brand.dart';
import 'models/unit_listing.dart';
import 'utils/currency_utils.dart';
import 'utils/map_navigation.dart';

/// Detail view for a homestay unit from the backend.
class UnitDetailScreen extends StatefulWidget {
  const UnitDetailScreen({super.key, required this.unit});

  final UnitListing unit;

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  late final PageController _pageController;
  int _photoIndex = 0;
  List<String> _galleryUrls = [];

  UnitListing get u => widget.unit;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _galleryUrls = u.mainImageUrl.isNotEmpty ? [u.mainImageUrl] : [];
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.unitUrl(u.id))).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || !mounted) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final images = body['image_urls'];
      if (images is! List || images.isEmpty) return;
      setState(() {
        _galleryUrls = images.map((e) => ApiConfig.resolveMediaUrl(e.toString())).where((url) => url.isNotEmpty).toList();
      });
    } catch (_) {
      // keep fallback image
    }
  }

  Future<void> _openInMaps() async {
    final lat = u.latitude;
    final lng = u.longitude;
    if (lat == null || lng == null) return;

    final opened = await openLocationInMaps(
      latitude: lat,
      longitude: lng,
      label: u.title,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps for this location.')),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final urls = _galleryUrls;
    final latLng = u.latitude != null && u.longitude != null ? LatLng(u.latitude!, u.longitude!) : null;

    return Scaffold(
      backgroundColor: KelseyColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _HeroGallery(urls: urls, pageController: _pageController, photoIndex: _photoIndex, onPageChanged: (i) => setState(() => _photoIndex = i))),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -12),
                  child: Material(
                    color: Colors.white,
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 36, 22, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  u.title,
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              if (u.isFeatured) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: KelseyColors.yellow.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Featured',
                                    style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: KelseyColors.tealButton.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              u.propertyType,
                              style: textTheme.labelLarge?.copyWith(
                                color: KelseyColors.tealButton,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on_outlined, size: 20, color: KelseyColors.tealButton),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  u.locationLabel,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: KelseyColors.cardMuted,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (u.distanceLabel != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              u.distanceLabel!,
                              style: textTheme.labelLarge?.copyWith(
                                color: KelseyColors.tealButton,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: _FeatureChip(
                                  icon: Icons.bed_outlined,
                                  label: '${u.bedrooms} bed${u.bedrooms == 1 ? '' : 's'}',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FeatureChip(
                                  icon: Icons.bathtub_outlined,
                                  label: '${u.bathrooms} bath${u.bathrooms == 1 ? '' : 's'}',
                                ),
                              ),
                              if (u.maxCapacity != null) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _FeatureChip(
                                    icon: Icons.groups_outlined,
                                    label: 'Up to ${u.maxCapacity}',
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (u.checkInTime != null || u.checkOutTime != null) ...[
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                if (u.checkInTime != null)
                                  Expanded(
                                    child: _TimeChip(
                                      icon: Icons.login_rounded,
                                      label: 'Check-in',
                                      time: u.checkInTime!,
                                    ),
                                  ),
                                if (u.checkInTime != null && u.checkOutTime != null) const SizedBox(width: 10),
                                if (u.checkOutTime != null)
                                  Expanded(
                                    child: _TimeChip(
                                      icon: Icons.logout_rounded,
                                      label: 'Check-out',
                                      time: u.checkOutTime!,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (u.description != null && u.description!.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _SectionHeader(title: 'About'),
                            const SizedBox(height: 10),
                            Text(
                              u.description!,
                              style: textTheme.bodyLarge?.copyWith(
                                color: KelseyColors.cardMuted,
                                height: 1.45,
                              ),
                            ),
                          ],
                          if (latLng != null) ...[
                            const SizedBox(height: 24),
                            _SectionHeader(title: 'Location'),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _openInMaps,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: SizedBox(
                                  height: 200,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      FlutterMap(
                                        options: MapOptions(
                                          initialCenter: latLng,
                                          initialZoom: 13,
                                          interactionOptions: const InteractionOptions(
                                            flags: InteractiveFlag.none,
                                          ),
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName: 'com.kelseyapp.kelseyapp',
                                          ),
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: latLng,
                                                width: 40,
                                                height: 40,
                                                alignment: Alignment.bottomCenter,
                                                child: const Icon(Icons.location_on, color: KelseyColors.tealButton, size: 40),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        right: 10,
                                        bottom: 10,
                                        child: Material(
                                          color: Colors.white.withValues(alpha: 0.94),
                                          borderRadius: BorderRadius.circular(20),
                                          elevation: 2,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Platform.isIOS ? Icons.map_outlined : Icons.navigation_rounded,
                                                  size: 16,
                                                  color: KelseyColors.tealButton,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Navigate',
                                                  style: textTheme.labelMedium?.copyWith(
                                                    color: KelseyColors.tealButton,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 120 + MediaQuery.viewPaddingOf(context).bottom),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: top + 8,
            left: 16,
            child: _RoundIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BookFooter(
              priceLabel: CurrencyUtils.formatAmount(u.price, currency: u.currency),
              onBook: () => openBookUnitFlow(context, u),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.urls,
    required this.pageController,
    required this.photoIndex,
    required this.onPageChanged,
  });

  final List<String> urls;
  final PageController pageController;
  final int photoIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: urls.isEmpty
          ? ColoredBox(
              color: KelseyColors.tealButton.withValues(alpha: 0.25),
              child: const Center(
                child: Icon(Icons.night_shelter_outlined, size: 56, color: Colors.white70),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: pageController,
                  itemCount: urls.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (context, i) => Image.network(
                    urls[i],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: KelseyColors.tealButton.withValues(alpha: 0.25),
                      child: const Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.white70),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        KelseyColors.background.withValues(alpha: 0.45),
                        Colors.transparent,
                        KelseyColors.background.withValues(alpha: 0.75),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
                if (urls.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(urls.length, (i) {
                        final active = i == photoIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 9 : 6,
                          height: active ? 9 : 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active ? KelseyColors.yellow : Colors.white.withValues(alpha: 0.45),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: KelseyColors.yellow,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: KelseyColors.tealButton.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KelseyColors.tealButton.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: KelseyColors.tealButton),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: KelseyColors.tealButton,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.icon,
    required this.label,
    required this.time,
  });

  final IconData icon;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KelseyColors.inputBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: KelseyColors.tealButton),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(color: KelseyColors.cardMuted),
                ),
                Text(
                  time,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookFooter extends StatelessWidget {
  const _BookFooter({
    required this.priceLabel,
    required this.onBook,
  });

  final String priceLabel;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black26,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 14, 22, 14 + bottomInset),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'From',
                    style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: priceLabel,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: KelseyColors.tealButton,
                          ),
                        ),
                        TextSpan(
                          text: ' /night',
                          style: textTheme.titleMedium?.copyWith(
                            color: KelseyColors.cardMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  backgroundColor: KelseyColors.tealButton,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: const StadiumBorder(),
                  textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                child: const Text('Select dates'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 3,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 20, color: KelseyColors.tealButton),
        ),
      ),
    );
  }
}
