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

const _detailTeal = KelseyColors.adminTeal;
const _surface = KelseyColors.adminSurface;
const _border = Color(0xFFF3F4F6);
const _textPrimary = Color(0xFF111827);
const _textMuted = Color(0xFF6B7280);

/// Reservation detail for an existing booking from the Bookings tab.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.booking});

  final BookingRecord booking;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

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

  String _statusText(BookingRecord b) {
    if (b.status == BookingStatus.pending &&
        b.paymentStatus != null &&
        b.paymentStatus!.toLowerCase() != 'paid') {
      return 'Awaiting payment';
    }
    return b.statusLabel;
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.booked:
      case BookingStatus.completed:
        return const Color(0xFF16A34A);
      case BookingStatus.cancelled:
        return const Color(0xFFDC2626);
      case BookingStatus.pending:
        return const Color(0xFFCA8A04);
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
    final top = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final b = _display;
    final urls = b.galleryImageUrls;
    final total = b.totalAmount ?? (b.pricePerNight * b.stayNights);
    final hasMap = hasMapCoordinates(b.latitude, b.longitude);
    final statusColor = _statusColor(b.status);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_detail);
      },
      child: Scaffold(
        backgroundColor: _surface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: _HeroHeader(
                    imageUrl: urls.isNotEmpty ? urls.first : null,
                    title: b.listingTitle,
                    statusText: _statusText(b),
                    statusColor: statusColor,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + bottomInset),
                  sliver: SliverList.list(
                    children: [
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: LinearProgressIndicator(color: _detailTeal),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                            ),
                          ),
                        ),
                      if (b.referenceCode?.isNotEmpty == true || b.address.isNotEmpty)
                        _DetailCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (b.referenceCode?.isNotEmpty == true) ...[
                                _InfoRow(
                                  icon: Icons.confirmation_number_outlined,
                                  label: 'Reference',
                                  value: b.referenceCode!,
                                ),
                              ],
                              if (b.referenceCode?.isNotEmpty == true && b.address.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                                ),
                              if (b.address.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.location_on_outlined,
                                  label: 'Location',
                                  value: b.address,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      _DetailCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardTitle('Your stay'),
                            const SizedBox(height: 14),
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
                                  const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),
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
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                            ),
                            _InfoRow(
                              icon: Icons.groups_outlined,
                              label: 'Guests',
                              value: b.guestsSummary,
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.nights_stay_outlined,
                              label: 'Nights',
                              value: '${b.stayNights}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DetailCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardTitle('Payment'),
                            const SizedBox(height: 14),
                            _InfoRow(
                              icon: Icons.payments_outlined,
                              label: 'Method',
                              value: _paymentMethodLabel(b.paymentMethod),
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.hourglass_top_outlined,
                              label: 'Status',
                              value: _paymentStatusLabel(b.paymentStatus),
                            ),
                            if (b.transactionNumber?.isNotEmpty == true) ...[
                              const SizedBox(height: 12),
                              _InfoRow(
                                icon: Icons.receipt_long_outlined,
                                label: 'Transaction',
                                value: b.transactionNumber!,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (b.clientName?.isNotEmpty == true ||
                          b.clientEmail?.isNotEmpty == true ||
                          b.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        _DetailCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CardTitle('Guest'),
                              const SizedBox(height: 14),
                              if (b.clientName?.isNotEmpty == true)
                                _InfoRow(
                                  icon: Icons.person_outline,
                                  label: 'Name',
                                  value: b.clientName!,
                                ),
                              if (b.clientEmail?.isNotEmpty == true) ...[
                                const SizedBox(height: 12),
                                _InfoRow(
                                  icon: Icons.email_outlined,
                                  label: 'Email',
                                  value: b.clientEmail!,
                                ),
                              ],
                              if (b.notes?.isNotEmpty == true) ...[
                                const SizedBox(height: 12),
                                _InfoRow(
                                  icon: Icons.notes_outlined,
                                  label: 'Notes',
                                  value: b.notes!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (hasMap) ...[
                        const SizedBox(height: 12),
                        _DetailCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(child: _CardTitle('Map')),
                                  IconButton(
                                    tooltip: Platform.isIOS ? 'Open in Apple Maps' : 'Open in Maps',
                                    onPressed: () => _openInMaps(b),
                                    icon: Icon(
                                      Platform.isIOS ? Icons.map_outlined : Icons.map_rounded,
                                      color: _detailTeal,
                                    ),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: _openNearbyMap,
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: const Text('Open map'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _detailTeal,
                                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => _openInMaps(b),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
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
                                                  child: const Icon(Icons.location_on, color: _detailTeal, size: 36),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Positioned(
                                          right: 10,
                                          bottom: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.94),
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.08),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Platform.isIOS ? Icons.map_outlined : Icons.navigation_rounded,
                                                  size: 16,
                                                  color: _detailTeal,
                                                ),
                                                const SizedBox(width: 4),
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
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.imageUrl,
    required this.title,
    required this.statusText,
    required this.statusColor,
  });

  final String? imageUrl;
  final String title;
  final String statusText;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            )
          else
            _placeholder(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: _detailTeal.withValues(alpha: 0.12),
      child: const Center(
        child: Icon(Icons.night_shelter_outlined, size: 56, color: _detailTeal),
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

class _BookingTotalFooter extends StatelessWidget {
  const _BookingTotalFooter({required this.totalAmount});

  final double totalAmount;

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
            const Expanded(
              child: Text(
                'Total bill',
                style: TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              CurrencyUtils.formatAmount(totalAmount),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: _detailTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _detailTeal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: _textMuted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _detailTeal),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: _textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dateLine,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            timeLine,
            style: const TextStyle(
              color: _detailTeal,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              height: 1.1,
            ),
          ),
        ],
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
      elevation: 0,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 18, color: _textPrimary),
        ),
      ),
    );
  }
}
