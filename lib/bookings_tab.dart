import 'package:flutter/material.dart';

import 'booking_detail_screen.dart';
import 'booking_models.dart';
import 'kelsey_brand.dart';
import 'services/auth_service.dart';
import 'services/bookings_cache.dart';
import 'services/bookings_service.dart';
import 'utils/currency_utils.dart';
import 'utils/network_utils.dart';

enum _BookingFilter { all, pending, booked, completed, cancelled }

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
  _BookingFilter _filter = _BookingFilter.all;

  static const _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() => _loadBookings();

  List<BookingRecord> get _filtered {
    if (_filter == _BookingFilter.all) return _bookings;
    return _bookings.where((b) {
      switch (_filter) {
        case _BookingFilter.pending:
          return b.status == BookingStatus.pending;
        case _BookingFilter.booked:
          return b.status == BookingStatus.booked;
        case _BookingFilter.completed:
          return b.status == BookingStatus.completed;
        case _BookingFilter.cancelled:
          return b.status == BookingStatus.cancelled;
        case _BookingFilter.all:
          return true;
      }
    }).toList();
  }

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

  static String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    return '${_monthsShort[d.month - 1]} $day, ${d.year}';
  }

  static String _formatDateRange(BookingRecord b) {
    return '${_formatDate(b.checkIn)} - ${_formatDate(b.checkOut)}';
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
    final items = _filtered;

    return ColoredBox(
      color: KelseyColors.adminSurface,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: KelseyColors.adminTeal,
          onRefresh: _loadBookings,
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BookingFilterTabs(
                      selected: _filter,
                      onSelected: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: 4),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  ],
                ),
              ),
            ),
            if (_offline)
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: KelseyColors.adminTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: KelseyColors.adminTeal.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 18, color: KelseyColors.adminTeal),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are offline — showing saved bookings.',
                          style: TextStyle(fontSize: 13, color: KelseyColors.adminTeal, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: _loading
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(color: KelseyColors.adminTeal),
                      ),
                    )
                  : _error != null && _bookings.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: _BookingsEmptyState(
                            message: _error!,
                            showRetry: true,
                            onRetry: _loadBookings,
                          ),
                        )
                      : items.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: _BookingsEmptyState(
                                message: _bookings.isEmpty
                                    ? 'You have no bookings yet.'
                                    : 'No bookings found for the selected filter.',
                              ),
                            )
                          : SliverList.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 16),
                              itemBuilder: (context, index) => _BookingCard(
                                booking: items[index],
                                dateRange: _formatDateRange(items[index]),
                                onView: () => _openBookingDetail(items[index]),
                              ),
                            ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _BookingFilterTabs extends StatelessWidget {
  const _BookingFilterTabs({
    required this.selected,
    required this.onSelected,
  });

  final _BookingFilter selected;
  final ValueChanged<_BookingFilter> onSelected;

  static const _tabs = <_BookingFilter, String>{
    _BookingFilter.all: 'All',
    _BookingFilter.pending: 'Pending',
    _BookingFilter.booked: 'Booked',
    _BookingFilter.completed: 'Completed',
    _BookingFilter.cancelled: 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _tabs.entries.map((entry) {
          final isSelected = selected == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onSelected(entry.key),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF1F2937) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BookingsEmptyState extends StatelessWidget {
  const _BookingsEmptyState({
    required this.message,
    this.showRetry = false,
    this.onRetry,
  });

  final String message;
  final bool showRetry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: const Icon(Icons.calendar_month_outlined, size: 32, color: Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(backgroundColor: KelseyColors.adminTeal),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.dateRange,
    required this.onView,
  });

  final BookingRecord booking;
  final String dateRange;
  final VoidCallback onView;

  String get _statusText {
    if (booking.status == BookingStatus.pending &&
        booking.paymentStatus != null &&
        booking.paymentStatus!.toLowerCase() != 'paid') {
      return 'Awaiting payment';
    }
    switch (booking.status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.booked:
        return 'Booked';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get _statusColor {
    switch (booking.status) {
      case BookingStatus.booked:
      case BookingStatus.completed:
        return const Color(0xFF16A34A);
      case BookingStatus.cancelled:
        return const Color(0xFFDC2626);
      case BookingStatus.pending:
        return const Color(0xFFCA8A04);
    }
  }

  String get _transactionLabel {
    final ref = booking.transactionNumber;
    if (ref != null && ref.isNotEmpty) return 'Transaction No. #$ref';
    if (booking.referenceCode != null && booking.referenceCode!.isNotEmpty) {
      return 'Ref. ${booking.referenceCode}';
    }
    return 'Ref. ${booking.id}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final totalBill = booking.totalAmount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dateRange,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  height: 88,
                  child: booking.heroImageUrl.isNotEmpty
                      ? Image.network(
                          booking.heroImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _imagePlaceholder(),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return _imagePlaceholder(loading: true);
                          },
                        )
                      : _imagePlaceholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.listingTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.unitLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 10),
                    if (booking.clientName != null && booking.clientName!.isNotEmpty)
                      _MetaRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Booked for ${booking.clientName}',
                      ),
                    if (booking.clientName != null && booking.clientName!.isNotEmpty)
                      const SizedBox(height: 6),
                    _MetaRow(
                      icon: Icons.receipt_long_outlined,
                      label: _transactionLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _statusText,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _statusColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Bill',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      totalBill != null
                          ? CurrencyUtils.formatAmount(totalBill)
                          : '—',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: onView,
                style: FilledButton.styleFrom(
                  backgroundColor: KelseyColors.adminTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('View', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder({bool loading = false}) {
    return ColoredBox(
      color: KelseyColors.adminTeal.withValues(alpha: 0.08),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: KelseyColors.adminTeal),
              )
            : Icon(Icons.night_shelter_outlined, size: 32, color: KelseyColors.adminTeal.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }
}
