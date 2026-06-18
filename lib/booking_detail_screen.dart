import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'booking_models.dart';
import 'kelsey_brand.dart';
import 'nearby_condos_map_screen.dart';
import 'services/auth_service.dart';
import 'services/bookings_service.dart';
import 'utils/currency_utils.dart';
import 'utils/map_navigation.dart';

/// Reservation detail for an existing booking from the Bookings tab.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.booking});

  final BookingRecord booking;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

const Color _accentOrange = Color(0xFFE6834B);

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final BookingsService _bookingsService = const BookingsService();

  BookingRecord? _detail;
  bool _loading = true;
  String? _error;

  BookingRecord get _display => _detail ?? widget.booking;

  static const List<String> _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> _weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await _bookingsService.fetchBookingDetail(widget.booking.bookingKey);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detail = widget.booking;
        _loading = false;
        _error = e is AuthException ? e.message : null;
      });
    }
  }

  String _formatStayDate(DateTime d) {
    return '${_weekdaysShort[d.weekday - 1]}, ${_monthsShort[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatStayTime(DateTime d) {
    final hour24 = d.hour;
    final h = hour24 > 12 ? hour24 - 12 : (hour24 == 0 ? 12 : hour24);
    final am = hour24 >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$h:$mm $am';
  }

  String _paymentMethodLabel(String? method) {
    switch (method?.toLowerCase()) {
      case 'gcash':
        return 'GCash';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      default:
        return method?.isNotEmpty == true ? method! : '—';
    }
  }

  String _paymentStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'verified':
        return 'Verified';
      case 'submitted':
        return 'Submitted';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return const Color(0xFFE65100);
      case BookingStatus.booked:
        return KelseyColors.tealButton;
      case BookingStatus.completed:
        return Colors.grey.shade700;
      case BookingStatus.cancelled:
        return Colors.red.shade700;
    }
  }

  Future<void> _openInMaps(BookingRecord b) async {
    final opened = await openLocationInMaps(
      latitude: b.latitude,
      longitude: b.longitude,
      label: b.listingTitle,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps for this location.')),
      );
    }
  }

  void _openNearbyMap() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NearbyCondosMapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final b = _display;
    final urls = b.galleryImageUrls;
    final total = b.totalAmount ?? (b.pricePerNight * b.stayNights);
    final hasMap = hasMapCoordinates(b.latitude, b.longitude);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_detail);
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (urls.isNotEmpty)
                        Image.network(
                          urls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: KelseyColors.tealButton.withValues(alpha: 0.15),
                            child: const Icon(Icons.night_shelter_outlined, size: 56, color: Colors.white70),
                          ),
                        )
                      else
                        ColoredBox(
                          color: KelseyColors.tealButton.withValues(alpha: 0.15),
                          child: const Icon(Icons.night_shelter_outlined, size: 56, color: Colors.white70),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Text(
                                  b.statusLabel,
                                  style: textTheme.labelLarge?.copyWith(
                                    color: _statusColor(b.status),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              b.listingTitle,
                              style: textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: LinearProgressIndicator(),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: textTheme.bodySmall?.copyWith(color: Colors.orange.shade800),
                          ),
                        ),
                      if (b.referenceCode?.isNotEmpty == true)
                        _InfoTile(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Reference',
                          value: b.referenceCode!,
                        ),
                      if (b.address.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InfoTile(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: b.address,
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Your stay',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _StayBlock(
                                label: 'Check-in',
                                icon: Icons.login_rounded,
                                dateLine: _formatStayDate(b.checkIn),
                                timeLine: _formatStayTime(b.checkIn),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: VerticalDivider(
                                width: 1,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            Expanded(
                              child: _StayBlock(
                                label: 'Check-out',
                                icon: Icons.logout_rounded,
                                dateLine: _formatStayDate(b.checkOut),
                                timeLine: _formatStayTime(b.checkOut),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InfoTile(
                        icon: Icons.groups_outlined,
                        label: 'Guests',
                        value: b.guestsSummary,
                      ),
                      const SizedBox(height: 8),
                      _InfoTile(
                        icon: Icons.nights_stay_outlined,
                        label: 'Nights',
                        value: '${b.stayNights}',
                      ),
                      const SizedBox(height: 22),
                      Divider(height: 1, color: Colors.grey.shade300),
                      const SizedBox(height: 22),
                      Text(
                        'Payment',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.payments_outlined,
                        label: 'Method',
                        value: _paymentMethodLabel(b.paymentMethod),
                      ),
                      const SizedBox(height: 8),
                      _InfoTile(
                        icon: Icons.hourglass_top_outlined,
                        label: 'Status',
                        value: _paymentStatusLabel(b.paymentStatus),
                      ),
                      if (b.transactionNumber?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        _InfoTile(
                          icon: Icons.receipt_long_outlined,
                          label: 'Transaction',
                          value: b.transactionNumber!,
                        ),
                      ],
                      if (b.clientName?.isNotEmpty == true) ...[
                        const SizedBox(height: 22),
                        Divider(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 22),
                        Text(
                          'Guest',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          icon: Icons.person_outline,
                          label: 'Name',
                          value: b.clientName!,
                        ),
                        if (b.clientEmail?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          _InfoTile(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: b.clientEmail!,
                          ),
                        ],
                      ],
                      if (b.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        _InfoTile(
                          icon: Icons.notes_outlined,
                          label: 'Notes',
                          value: b.notes!,
                        ),
                      ],
                      if (hasMap) ...[
                        const SizedBox(height: 22),
                        Divider(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Location',
                                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              tooltip: Platform.isIOS ? 'Open in Apple Maps' : 'Open in Maps',
                              onPressed: () => _openInMaps(b),
                              icon: Icon(Platform.isIOS ? Icons.map_outlined : Icons.map_rounded),
                              color: KelseyColors.tealButton,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _openNearbyMap,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Open map'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: KelseyColors.tealButton,
                            side: const BorderSide(color: KelseyColors.tealButton),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _openInMaps(b),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              height: 180,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  FlutterMap(
                                    options: MapOptions(
                                      initialCenter: LatLng(b.latitude, b.longitude),
                                      initialZoom: 14,
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
                                            point: LatLng(b.latitude, b.longitude),
                                            width: 36,
                                            height: 36,
                                            child: Icon(Icons.location_on, color: _accentOrange, size: 36),
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
                      SizedBox(height: 104 + MediaQuery.viewPaddingOf(context).bottom),
                    ],
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
              onTap: () => Navigator.of(context).pop(_detail),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BookingTotalFooter(totalAmount: total),
          ),
        ],
      ),
      ),
    );
  }
}

class _BookingTotalFooter extends StatelessWidget {
  const _BookingTotalFooter({required this.totalAmount});

  final double totalAmount;

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
                    'Total',
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyUtils.formatAmount(totalAmount),
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(color: KelseyColors.cardMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StayBlock extends StatelessWidget {
  const _StayBlock({
    required this.label,
    required this.icon,
    required this.dateLine,
    required this.timeLine,
  });

  final String label;
  final IconData icon;
  final String dateLine;
  final String timeLine;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: KelseyColors.tealButton.withValues(alpha: 0.85)),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: KelseyColors.cardMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(dateLine, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          timeLine,
          style: textTheme.titleLarge?.copyWith(
            color: KelseyColors.tealButton,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ],
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
      elevation: 3,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }
}
