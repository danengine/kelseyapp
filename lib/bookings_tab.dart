import 'package:flutter/material.dart';

import 'booking_detail_screen.dart';
import 'booking_models.dart';
import 'kelsey_brand.dart';
import 'services/auth_service.dart';
import 'services/bookings_cache.dart';
import 'services/bookings_service.dart';
import 'utils/network_utils.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  BookingsTabState createState() => BookingsTabState();
}

class BookingsTabState extends State<BookingsTab> {
  final BookingsService _bookingsService = const BookingsService();

  List<BookingRecord> _bookings = const [];
  bool _loading = true;
  bool _offline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() => _loadBookings();

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
      _offline = false;
    });

    try {
      final bookings = await _bookingsService.fetchMyBookings();
      await BookingsCache.save(bookings);
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
        _offline = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (isOfflineError(e)) {
        final cached = await BookingsCache.load();
        setState(() {
          _bookings = cached;
          _loading = false;
          _offline = true;
          _error = cached.isEmpty ? 'You are offline.' : null;
        });
        return;
      }

      setState(() {
        _loading = false;
        _offline = false;
        _error = e is AuthException ? e.message : 'Could not load bookings.';
      });
    }
  }

  static const List<String> _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> _weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _formatStayDate(DateTime d) {
    return '${_weekdaysShort[d.weekday - 1]}, ${_monthsShort[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _formatStayTime(DateTime d) {
    final hour24 = d.hour;
    final h = hour24 > 12 ? hour24 - 12 : (hour24 == 0 ? 12 : hour24);
    final am = hour24 >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$h:$mm $am';
  }

  static int _nightCount(BookingRecord b) {
    final inDate = DateTime(b.checkIn.year, b.checkIn.month, b.checkIn.day);
    final outDate = DateTime(b.checkOut.year, b.checkOut.month, b.checkOut.day);
    final days = outDate.difference(inDate).inDays;
    return days < 1 ? 1 : days;
  }

  Future<void> _openBookingDetail(BookingRecord booking) async {
    await Navigator.of(context).push<BookingRecord>(
      MaterialPageRoute<BookingRecord>(
        builder: (_) => BookingDetailScreen(booking: booking),
      ),
    );

    if (!mounted) return;
    await _loadBookings();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            surfaceTintColor: Colors.transparent,
            backgroundColor: scheme.surface,
            title: const Text('Bookings'),
          ),
          if (_offline)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are offline — showing saved bookings.',
                        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            sliver: _loading
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null && _bookings.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge?.copyWith(color: KelseyColors.cardMuted),
                            ),
                          ),
                        ),
                      )
                    : _bookings.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No bookings yet.',
                                style: textTheme.bodyLarge?.copyWith(color: KelseyColors.cardMuted),
                              ),
                            ),
                          )
                        : SliverList.list(
                            children: [
                              Text(
                                'Your reservations',
                                style: textTheme.titleMedium?.copyWith(color: KelseyColors.cardMuted),
                              ),
                              const SizedBox(height: 16),
                              ..._bookings.map(
                                (b) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _BookingCard(
                                    booking: b,
                                    formatStayDate: _formatStayDate,
                                    formatStayTime: _formatStayTime,
                                    nightCount: _nightCount(b),
                                    onTap: () => _openBookingDetail(b),
                                  ),
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.formatStayDate,
    required this.formatStayTime,
    required this.nightCount,
    required this.onTap,
  });

  final BookingRecord booking;
  final String Function(DateTime) formatStayDate;
  final String Function(DateTime) formatStayTime;
  final int nightCount;
  final VoidCallback onTap;

  ({String label, Color onImageBg, Color onImageFg}) _statusStyle(BookingStatus s, ColorScheme scheme) {
    switch (s) {
      case BookingStatus.pending:
        return (
          label: 'Pending',
          onImageBg: const Color(0xFFFFF8E1).withValues(alpha: 0.95),
          onImageFg: const Color(0xFFE65100),
        );
      case BookingStatus.booked:
        return (
          label: 'Booked',
          onImageBg: Colors.white.withValues(alpha: 0.94),
          onImageFg: KelseyColors.tealButton,
        );
      case BookingStatus.completed:
        return (
          label: 'Completed',
          onImageBg: Colors.white.withValues(alpha: 0.92),
          onImageFg: scheme.onSurfaceVariant,
        );
      case BookingStatus.cancelled:
        return (
          label: 'Cancelled',
          onImageBg: Colors.white.withValues(alpha: 0.92),
          onImageFg: Colors.red.shade700,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final st = _statusStyle(booking.status, scheme);
    final nightsLabel = nightCount == 1 ? '1 night' : '$nightCount nights';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        shadowColor: Colors.black26,
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    booking.heroImageUrl,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: KelseyColors.tealButton.withValues(alpha: 0.2),
                      child: const Center(
                        child: Icon(Icons.night_shelter_outlined, size: 48, color: Colors.white70),
                      ),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.primary.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: st.onImageBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          st.label,
                          style: textTheme.labelLarge?.copyWith(
                            color: st.onImageFg,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          booking.unitLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                blurRadius: 10,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking.listingTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                blurRadius: 16,
                                offset: const Offset(0, 2),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 18, color: KelseyColors.cardMuted),
                      const SizedBox(width: 6),
                      Text(
                        nightsLabel,
                        style: textTheme.bodyMedium?.copyWith(
                          color: KelseyColors.cardMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _StayScheduleBlock(
                            label: 'Check-in',
                            icon: Icons.login_rounded,
                            dateLine: formatStayDate(booking.checkIn),
                            timeLine: formatStayTime(booking.checkIn),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: scheme.outlineVariant.withValues(alpha: 0.65),
                          ),
                        ),
                        Expanded(
                          child: _StayScheduleBlock(
                            label: 'Check-out',
                            icon: Icons.logout_rounded,
                            dateLine: formatStayDate(booking.checkOut),
                            timeLine: formatStayTime(booking.checkOut),
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
      ),
    );
  }
}

class _StayScheduleBlock extends StatelessWidget {
  const _StayScheduleBlock({
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
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          dateLine,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          timeLine,
          style: textTheme.titleLarge?.copyWith(
            color: KelseyColors.tealButton,
            fontWeight: FontWeight.w800,
            height: 1.1,
            fontSize: 22,
          ),
        ),
      ],
    );
  }
}
