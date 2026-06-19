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
import 'widgets/unit_gallery_viewer.dart';

const _detailTeal = KelseyColors.adminTeal;
const _surface = KelseyColors.adminSurface;
const _border = Color(0xFFF3F4F6);
const _textPrimary = Color(0xFF111827);
const _textMuted = Color(0xFF6B7280);

/// Detail view for a homestay unit — matches home / web unit page styling.
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

  String get _propertyTypeLabel {
    if (u.propertyType.isEmpty) return 'Property';
    final t = u.propertyType;
    return t[0].toUpperCase() + t.substring(1);
  }

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
        _galleryUrls = images
            .map((e) => ApiConfig.resolveMediaUrl(e.toString()))
            .where((url) => url.isNotEmpty)
            .toList();
      });
    } catch (_) {
      // keep fallback image
    }
  }

  Future<void> _openInMaps() async {
    final lat = u.latitude;
    final lng = u.longitude;
    if (lat == null || lng == null) return;

    final opened = await openLocationInMaps(latitude: lat, longitude: lng, label: u.title);
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
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: _HeroGallery(
                  urls: urls,
                  pageController: _pageController,
                  photoIndex: _photoIndex,
                  propertyTypeLabel: _propertyTypeLabel,
                  onPageChanged: (i) => setState(() => _photoIndex = i),
                  onOpenFullscreen: urls.isEmpty
                      ? null
                      : () => UnitGalleryViewer.open(
                            context,
                            urls: urls,
                            initialIndex: _photoIndex,
                            title: u.title,
                          ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + bottomInset),
                sliver: SliverList.list(
                  children: [
                    _DetailCard(
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
                                    color: _textPrimary,
                                    height: 1.2,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (u.isFeatured) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _detailTeal.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Featured',
                                    style: TextStyle(
                                      color: _detailTeal,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 18, color: _textMuted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  u.locationLabel,
                                  style: textTheme.bodyMedium?.copyWith(color: _textMuted, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                          if (u.distanceLabel != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              u.distanceLabel!,
                              style: const TextStyle(
                                color: _detailTeal,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                CurrencyUtils.formatAmount(u.price, currency: u.currency),
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '/ night',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: _textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailCard(
                      child: _StatsGrid(unit: u),
                    ),
                    if (u.checkInTime != null || u.checkOutTime != null) ...[
                      const SizedBox(height: 12),
                      _DetailCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardTitle('Stay duration'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (u.checkInTime != null)
                                  Expanded(
                                    child: _StayTimeTile(
                                      label: 'Check-in',
                                      time: u.checkInTime!,
                                      icon: Icons.login_rounded,
                                    ),
                                  ),
                                if (u.checkInTime != null && u.checkOutTime != null)
                                  Container(
                                    width: 1,
                                    height: 48,
                                    margin: const EdgeInsets.symmetric(horizontal: 12),
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                if (u.checkOutTime != null)
                                  Expanded(
                                    child: _StayTimeTile(
                                      label: 'Check-out',
                                      time: u.checkOutTime!,
                                      icon: Icons.logout_rounded,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (u.description != null && u.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardTitle('About this place'),
                            const SizedBox(height: 10),
                            Text(
                              u.description!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: _textMuted,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (u.amenities.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardTitle('Amenities'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: u.amenities.map((a) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Text(
                                    a,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _textPrimary,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (latLng != null) ...[
                      const SizedBox(height: 12),
                      _DetailCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardTitle('Location'),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _openInMaps,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  height: 180,
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
                                                child: const Icon(Icons.location_on, color: _detailTeal, size: 40),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        right: 10,
                                        bottom: 10,
                                        child: Material(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          elevation: 2,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Platform.isIOS ? Icons.map_outlined : Icons.navigation_rounded,
                                                  size: 16,
                                                  color: _detailTeal,
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'Navigate',
                                                  style: TextStyle(
                                                    color: _detailTeal,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
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
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _DetailCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _detailTeal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.shield_outlined, color: _detailTeal, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Flexible cancellation',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Free cancellation before check-in. After check-in, the reservation is non-refundable.',
                                  style: TextStyle(color: _textMuted, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.unit});

  final UnitListing unit;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, String value})>[
      (icon: Icons.bed_outlined, label: 'Bedrooms', value: '${unit.bedrooms}'),
      (icon: Icons.bathtub_outlined, label: 'Bathrooms', value: '${unit.bathrooms}'),
      if (unit.squareFeet != null)
        (icon: Icons.square_foot_outlined, label: 'Sq ft', value: '${unit.squareFeet}'),
      if (unit.maxCapacity != null)
        (icon: Icons.groups_outlined, label: 'Guests', value: 'Up to ${unit.maxCapacity}'),
    ];

    return Row(
      children: List.generate(items.length, (i) {
        final item = items[i];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Icon(item.icon, size: 20, color: _detailTeal),
                const SizedBox(height: 6),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _StayTimeTile extends StatelessWidget {
  const _StayTimeTile({
    required this.label,
    required this.time,
    required this.icon,
  });

  final String label;
  final String time;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _detailTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: _textMuted)),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _textPrimary,
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

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.urls,
    required this.pageController,
    required this.photoIndex,
    required this.propertyTypeLabel,
    required this.onPageChanged,
    this.onOpenFullscreen,
  });

  final List<String> urls;
  final PageController pageController;
  final int photoIndex;
  final String propertyTypeLabel;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: 300 + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (urls.isEmpty)
            ColoredBox(
              color: _detailTeal.withValues(alpha: 0.08),
              child: const Center(
                child: Icon(Icons.night_shelter_outlined, size: 56, color: _detailTeal),
              ),
            )
          else
            PageView.builder(
              controller: pageController,
              itemCount: urls.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, i) => Image.network(
                urls[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: _detailTeal.withValues(alpha: 0.08),
                  child: const Icon(Icons.image_not_supported_outlined, size: 48, color: _detailTeal),
                ),
              ),
            ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 56,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                propertyTypeLabel,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (urls.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${photoIndex + 1} / ${urls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (onOpenFullscreen != null) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onOpenFullscreen,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Expand',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomInset),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('From', style: TextStyle(fontSize: 12, color: _textMuted)),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: priceLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: _detailTeal,
                          ),
                        ),
                        const TextSpan(
                          text: ' /night',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onBook,
              style: FilledButton.styleFrom(
                backgroundColor: _detailTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Reserve',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 20, color: _detailTeal),
        ),
      ),
    );
  }
}
