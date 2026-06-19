import 'package:flutter/material.dart';

import 'booking_models.dart';
import 'kelsey_brand.dart';
import 'models/admin_booking_item.dart';
import 'services/admin_bookings_service.dart';
import 'services/auth_service.dart';
import 'utils/currency_utils.dart';

/// Admin screen: review and approve/decline booking requests.
class AdminBookingsTab extends StatefulWidget {
  const AdminBookingsTab({super.key, this.embedded = false});

  final bool embedded;

  @override
  AdminBookingsTabState createState() => AdminBookingsTabState();
}

class AdminBookingsTabState extends State<AdminBookingsTab> {
  final AdminBookingsService _service = const AdminBookingsService();

  List<AdminBookingItem> _bookings = const [];
  bool _loading = true;
  String? _error;
  AdminBookingFilter _filter = AdminBookingFilter.all;
  String? _actionBookingId;

  List<AdminBookingItem> get _filtered =>
      _bookings.where(_filter.matches).toList();

  int get _pendingCount => _bookings.where((b) => b.status == BookingStatus.pending).length;

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
    });

    try {
      final bookings = await _service.fetchAllBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bookings = const [];
        _loading = false;
        _error = e is AuthException ? e.message : 'Could not load bookings.';
      });
    }
  }

  Future<void> _confirm(AdminBookingItem booking) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm booking?'),
        content: Text(
          'Approve ${booking.referenceCode} for ${booking.clientName}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: KelseyColors.tealButton),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _actionBookingId = booking.id);
    try {
      await _service.confirmBooking(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking confirmed')),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : 'Could not confirm booking.')),
      );
    } finally {
      if (mounted) setState(() => _actionBookingId = null);
    }
  }

  Future<void> _decline(AdminBookingItem booking) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline request?'),
        content: Text(
          'Decline ${booking.referenceCode} from ${booking.clientName}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _actionBookingId = booking.id);
    try {
      await _service.declineBooking(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking request declined')),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : 'Could not decline booking.')),
      );
    } finally {
      if (mounted) setState(() => _actionBookingId = null);
    }
  }

  void _openDetail(AdminBookingItem booking) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AdminBookingDetailSheet(
        booking: booking,
        busy: _actionBookingId == booking.id,
        onConfirm: booking.canApproveOrDecline ? () => _confirm(booking) : null,
        onDecline: booking.canApproveOrDecline ? () => _decline(booking) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = _filtered;

    final scrollView = RefreshIndicator(
      color: KelseyColors.adminTeal,
      onRefresh: _loadBookings,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (!widget.embedded)
            SliverAppBar(
              pinned: true,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text('Booking requests'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _loadBookings,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, widget.embedded ? 12 : 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.embedded) ...[
                    Text(
                      'Booking requests',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    widget.embedded
                        ? 'Review pending stays and approve or decline.'
                        : 'Review pending stays and approve or decline, like the admin web panel.',
                    style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StatPill(
                        label: 'Pending',
                        value: '$_pendingCount',
                        color: const Color(0xFFE65100),
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        label: 'Total',
                        value: '${_bookings.length}',
                        color: KelseyColors.adminTeal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: AdminBookingFilter.values.map((filter) {
                        final selected = _filter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: selected,
                            label: Text(filter.label),
                            selectedColor: KelseyColors.adminTeal,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : null,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        );
                      }).toList(),
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
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _loadBookings, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            )
          else if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No ${_filter == AdminBookingFilter.all ? '' : '${_filter.label.toLowerCase()} '}bookings found.',
                  style: textTheme.bodyLarge?.copyWith(color: KelseyColors.cardMuted),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, widget.embedded ? 100 : 32),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final booking = items[index];
                  return _AdminBookingCard(
                    booking: booking,
                    onTap: () => _openDetail(booking),
                  );
                },
              ),
            ),
        ],
      ),
    );

    if (widget.embedded) return scrollView;
    return Scaffold(body: scrollView);
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminBookingCard extends StatelessWidget {
  const _AdminBookingCard({
    required this.booking,
    required this.onTap,
  });

  final AdminBookingItem booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chip = _statusChip(booking.status);

    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFF3F4F6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: booking.imageUrl.isEmpty
                        ? Container(
                            width: 72,
                            height: 72,
                            color: KelseyColors.tealButton.withValues(alpha: 0.12),
                            child: const Icon(Icons.night_shelter_outlined, color: KelseyColors.tealButton),
                          )
                        : Image.network(
                            booking.imageUrl,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: KelseyColors.tealButton.withValues(alpha: 0.12),
                              child: const Icon(Icons.broken_image_outlined, color: KelseyColors.tealButton),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                booking.listingTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: chip.background,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                chip.label,
                                style: textTheme.labelSmall?.copyWith(
                                  color: chip.foreground,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking.clientName,
                          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          booking.referenceCode,
                          style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.date_range_rounded, size: 16, color: KelseyColors.cardMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_formatDate(booking.checkIn)} → ${_formatDate(booking.checkOut)}',
                      style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    CurrencyUtils.formatAmount(booking.totalAmount),
                    style: textTheme.titleSmall?.copyWith(
                      color: KelseyColors.tealButton,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (booking.canApproveOrDecline)
                    Text(
                      'Tap to review',
                      style: textTheme.labelMedium?.copyWith(
                        color: KelseyColors.tealButton,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static ({String label, Color background, Color foreground}) _statusChip(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return (label: 'Pending', background: const Color(0xFFFFF8E1), foreground: const Color(0xFFE65100));
      case BookingStatus.booked:
        return (label: 'Booked', background: KelseyColors.tealButton.withValues(alpha: 0.12), foreground: KelseyColors.tealButton);
      case BookingStatus.completed:
        return (label: 'Completed', background: const Color(0xFFE0F2F1), foreground: const Color(0xFF00695C));
      case BookingStatus.cancelled:
        return (label: 'Declined', background: const Color(0xFFF5F5F4), foreground: const Color(0xFF57534E));
    }
  }
}

class _AdminBookingDetailSheet extends StatelessWidget {
  const _AdminBookingDetailSheet({
    required this.booking,
    required this.busy,
    this.onConfirm,
    this.onDecline,
  });

  final AdminBookingItem booking;
  final bool busy;
  final VoidCallback? onConfirm;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            booking.listingTitle,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            booking.location,
            style: textTheme.bodyMedium?.copyWith(color: KelseyColors.cardMuted),
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Reference', value: booking.referenceCode),
          _DetailRow(label: 'Guest', value: booking.clientName),
          if (booking.clientEmail.isNotEmpty) _DetailRow(label: 'Email', value: booking.clientEmail),
          if (booking.clientPhone.isNotEmpty) _DetailRow(label: 'Phone', value: booking.clientPhone),
          if (booking.agentName != null) _DetailRow(label: 'Agent', value: booking.agentName!),
          _DetailRow(
            label: 'Stay',
            value: '${_formatDate(booking.checkIn)} → ${_formatDate(booking.checkOut)}',
          ),
          _DetailRow(label: 'Guests', value: '${booking.totalGuests}'),
          _DetailRow(label: 'Amount', value: CurrencyUtils.formatAmount(booking.totalAmount)),
          if (booking.paymentMethod != null)
            _DetailRow(label: 'Payment', value: booking.paymentMethod!),
          const SizedBox(height: 20),
          if (onConfirm != null || onDecline != null)
            Row(
              children: [
                if (onDecline != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                if (onConfirm != null && onDecline != null) const SizedBox(width: 12),
                if (onConfirm != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: KelseyColors.tealButton,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Confirm'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(color: KelseyColors.cardMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
