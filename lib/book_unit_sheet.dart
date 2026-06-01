import 'package:flutter/material.dart';

import 'booking_detail_screen.dart';
import 'booking_models.dart';
import 'kelsey_brand.dart';
import 'kelsey_success_splash.dart';
import 'models/unit_listing.dart';
import 'services/auth_service.dart';
import 'services/auth_session.dart';
import 'services/bookings_service.dart';
import 'services/units_service.dart';
import 'utils/currency_utils.dart';

Future<bool?> openBookUnitFlow(BuildContext context, UnitListing unit) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => BookUnitScreen(unit: unit),
    ),
  );
}

class BookUnitScreen extends StatefulWidget {
  const BookUnitScreen({super.key, required this.unit});

  final UnitListing unit;

  @override
  State<BookUnitScreen> createState() => _BookUnitScreenState();
}

class _BookUnitScreenState extends State<BookUnitScreen> {
  final BookingsService _bookingsService = const BookingsService();
  final UnitsService _unitsService = const UnitsService();
  final PageController _pageController = PageController();

  int _step = 0;
  List<UnitAvailabilityRange> _blocked = const [];
  late UnitListing _unit;
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _guests = 1;
  String _paymentMethod = 'gcash';
  final TextEditingController _gcashNameController = TextEditingController();
  final TextEditingController _gcashNumberController = TextEditingController();
  final TextEditingController _gcashRefController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _depositorNameController = TextEditingController();
  final TextEditingController _bankAccountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _agreeTerms = false;
  bool _loadingAvailability = true;
  bool _submitting = false;
  bool _showSuccessSplash = false;
  String? _successSubtitle;
  String? _error;

  UnitListing get unit => _unit;

  TimeOfDay get _checkInTimeOfDay => _parseUnitTime(_unit.checkInTime, fallback: const TimeOfDay(hour: 15, minute: 0));

  TimeOfDay get _checkOutTimeOfDay => _parseUnitTime(_unit.checkOutTime, fallback: const TimeOfDay(hour: 11, minute: 0));

  @override
  void initState() {
    super.initState();
    _unit = widget.unit;
    final profile = AuthSession.profile;
    _gcashNameController.text = profile?.fullName ?? '';
    _depositorNameController.text = profile?.fullName ?? '';
    _loadAvailability();
  }

  int get _maxGuests => unit.maxCapacity ?? 8;

  @override
  void dispose() {
    _pageController.dispose();
    _gcashNameController.dispose();
    _gcashNumberController.dispose();
    _gcashRefController.dispose();
    _bankNameController.dispose();
    _depositorNameController.dispose();
    _bankAccountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _loadingAvailability = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _bookingsService.fetchUnitAvailability(widget.unit.id),
        _unitsService.fetchUnitById(widget.unit.id),
      ]);
      if (!mounted) return;
      setState(() {
        _blocked = results[0] as List<UnitAvailabilityRange>;
        _unit = results[1] as UnitListing;
        _loadingAvailability = false;
        if (_checkIn != null && _isDayBlocked(_checkIn!)) {
          _checkIn = null;
          _checkOut = null;
        } else if (_checkOut != null && (_checkIn == null || _rangeOverlapsBlocked(_checkIn!, _checkOut!))) {
          _checkOut = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAvailability = false;
        _error = e is AuthException ? e.message : 'Could not load availability.';
      });
    }
  }

  bool _isDayBlocked(DateTime day) {
    final d = _dateOnly(day);
    for (final range in _blocked) {
      final start = _dateOnly(range.checkIn);
      final end = _dateOnly(range.checkOut);
      if (!d.isBefore(start) && d.isBefore(end)) return true;
    }
    return false;
  }

  DateTime _dateOnly(DateTime day) => DateTime(day.year, day.month, day.day);

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  TimeOfDay _parseUnitTime(String? raw, {required TimeOfDay fallback}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final parts = raw.trim().split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  DateTime _resolveInitialDate({
    required DateTime? preferred,
    required DateTime firstDate,
    required DateTime lastDate,
    required bool Function(DateTime day) isSelectable,
  }) {
    if (preferred != null && isSelectable(_dateOnly(preferred))) {
      return _dateOnly(preferred);
    }
    var cursor = _dateOnly(firstDate);
    final last = _dateOnly(lastDate);
    while (!cursor.isAfter(last)) {
      if (isSelectable(cursor)) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return _dateOnly(firstDate);
  }

  String _formatStayTime(DateTime d) {
    final hour24 = d.hour;
    final h = hour24 > 12 ? hour24 - 12 : (hour24 == 0 ? 12 : hour24);
    final am = hour24 >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$h:$mm $am';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour24 = time.hour;
    final h = hour24 > 12 ? hour24 - 12 : (hour24 == 0 ? 12 : hour24);
    final am = hour24 >= 12 ? 'PM' : 'AM';
    final mm = time.minute.toString().padLeft(2, '0');
    return '$h:$mm $am';
  }

  bool _rangeOverlapsBlocked(DateTime start, DateTime end) {
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (cursor.isBefore(last)) {
      if (_isDayBlocked(cursor)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  int get _nights {
    if (_checkIn == null || _checkOut == null) return 0;
    return _checkOut!.difference(_checkIn!).inDays;
  }

  double get _estimatedTotal => unit.price * (_nights < 1 ? 1 : _nights);

  Future<void> _pickCheckIn() async {
    final now = DateTime.now();
    final first = _dateOnly(now);
    final last = first.add(const Duration(days: 365));
    bool isSelectable(DateTime day) => !_isDayBlocked(day);
    final initialDate = _resolveInitialDate(
      preferred: _checkIn,
      firstDate: first,
      lastDate: last,
      isSelectable: isSelectable,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: isSelectable,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _checkIn = _combineDateAndTime(picked, _checkInTimeOfDay);
      if (_checkOut != null && !_checkOut!.isAfter(_checkIn!)) {
        _checkOut = null;
      }
    });
  }

  Future<void> _pickCheckOut() async {
    if (_checkIn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select check-in first.')),
      );
      return;
    }

    final minOut = _dateOnly(_checkIn!.add(const Duration(days: 1)));
    final last = minOut.add(const Duration(days: 365));
    bool isSelectable(DateTime day) {
      final d = _dateOnly(day);
      if (d.isBefore(minOut)) return false;
      return !_rangeOverlapsBlocked(_checkIn!, d);
    }

    final initialDate = _resolveInitialDate(
      preferred: _checkOut,
      firstDate: minOut,
      lastDate: last,
      isSelectable: isSelectable,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minOut,
      lastDate: last,
      selectableDayPredicate: isSelectable,
    );
    if (picked == null || !mounted) return;
    setState(() => _checkOut = _combineDateAndTime(picked, _checkOutTimeOfDay));
  }

  bool _validateDatesStep() {
    if (_checkIn == null || _checkOut == null) {
      _error = 'Select check-in and check-out dates.';
      return false;
    }
    if (_rangeOverlapsBlocked(_checkIn!, _checkOut!)) {
      _error = 'Selected dates include unavailable nights.';
      return false;
    }
    return true;
  }

  bool _validatePaymentStep() {
    if (_paymentMethod == 'gcash') {
      if (_gcashNameController.text.trim().isEmpty || _gcashNumberController.text.trim().isEmpty) {
        _error = 'Enter your GCash name and mobile number.';
        return false;
      }
    } else {
      if (_bankNameController.text.trim().isEmpty ||
          _depositorNameController.text.trim().isEmpty ||
          _bankAccountController.text.trim().isEmpty) {
        _error = 'Complete all bank transfer details.';
        return false;
      }
    }
    return true;
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _nextFromDates() async {
    setState(() => _error = null);
    if (!_validateDatesStep()) {
      setState(() {});
      return;
    }
    _goToStep(1);
  }

  Future<void> _nextFromPayment() async {
    setState(() => _error = null);
    if (!_validatePaymentStep()) {
      setState(() {});
      return;
    }
    _goToStep(2);
  }

  Map<String, dynamic> _clientPayload() {
    final profile = AuthSession.profile;
    return {
      'first_name': profile?.firstName ?? '',
      'last_name': profile?.lastName ?? '',
      'email': profile?.email ?? '',
      'contact_number': _paymentMethod == 'gcash'
          ? _gcashNumberController.text.trim()
          : _bankAccountController.text.trim(),
    };
  }

  String? _paymentNotes() {
    final notes = _notesController.text.trim();
    if (_paymentMethod == 'gcash') {
      final ref = _gcashRefController.text.trim();
      final payer = _gcashNameController.text.trim();
      final parts = [
        if (payer.isNotEmpty) 'GCash name: $payer',
        if (ref.isNotEmpty) 'GCash ref: $ref',
        if (notes.isNotEmpty) notes,
      ];
      return parts.isEmpty ? null : parts.join('\n');
    }

    final parts = [
      'Bank: ${_bankNameController.text.trim()}',
      'Depositor: ${_depositorNameController.text.trim()}',
      'Account: ${_bankAccountController.text.trim()}',
      if (notes.isNotEmpty) notes,
    ];
    return parts.join('\n');
  }

  Future<void> _runSuccessSplashThenExit(GuestBookingResult result) async {
    final bookingKey = result.referenceCode.isNotEmpty ? result.referenceCode : result.id;
    BookingRecord? fetchedBooking;

    final detailFuture = _bookingsService.fetchBookingDetail(bookingKey).then((booking) {
      fetchedBooking = booking;
    }).catchError((_) {});

    setState(() {
      _submitting = false;
      _showSuccessSplash = true;
      _successSubtitle = result.referenceCode.isNotEmpty
          ? '${result.referenceCode} · Awaiting payment verification'
          : 'Awaiting payment verification';
    });

    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: 1150)),
      detailFuture,
    ]);

    if (!mounted) return;

    final booking = fetchedBooking ??
        BookingRecord.fromCreatedBooking(
          id: result.id,
          referenceCode: result.referenceCode,
          unit: unit,
          checkIn: _checkIn!,
          checkOut: _checkOut!,
          totalGuests: result.totalGuests,
          totalAmount: result.totalAmount,
          paymentMethod: result.paymentMethod,
        );

    final navigator = Navigator.of(context);
    navigator.pop(); // BookUnitScreen
    navigator.pop(); // UnitDetailScreen
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BookingDetailScreen(booking: booking),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_agreeTerms) {
      setState(() => _error = 'Please agree to the payment terms.');
      return;
    }
    if (!_validateDatesStep() || !_validatePaymentStep()) {
      setState(() {});
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await _bookingsService.createBooking(
        CreateBookingInput(
          unitId: unit.id,
          checkIn: _checkIn!,
          checkOut: _checkOut!,
          totalGuests: _guests,
          paymentMethod: _paymentMethod,
          requirePayment: true,
          client: _clientPayload(),
          notes: _paymentNotes(),
        ),
      );
      if (!mounted) return;
      await _runSuccessSplashThenExit(result);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Booking failed. Please try again.';
      });
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Select date';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatDateTime(DateTime? d, {required TimeOfDay fallbackTime}) {
    if (d == null) return 'Select date · ${_formatTimeOfDay(fallbackTime)}';
    return '${_formatDate(d)} · ${_formatStayTime(d)}';
  }

  String _paymentLabel() => _paymentMethod == 'gcash' ? 'GCash' : 'Bank Transfer';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: Text('Book ${unit.title}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                _StepChip(label: 'Dates', stepNumber: 1, active: _step == 0, done: _step > 0),
                _StepDivider(active: _step > 0),
                _StepChip(label: 'Payment', stepNumber: 2, active: _step == 1, done: _step > 1),
                _StepDivider(active: _step > 1),
                _StepChip(label: 'Review', stepNumber: 3, active: _step == 2, done: false),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _DatesStep(
                  loading: _loadingAvailability,
                  checkInLabel: _formatDate(_checkIn),
                  checkInTimeLabel: _checkIn != null ? _formatStayTime(_checkIn!) : _formatTimeOfDay(_checkInTimeOfDay),
                  checkOutLabel: _formatDate(_checkOut),
                  checkOutTimeLabel: _checkOut != null ? _formatStayTime(_checkOut!) : _formatTimeOfDay(_checkOutTimeOfDay),
                  guests: _guests,
                  maxGuests: _maxGuests,
                  nights: _nights,
                  unit: unit,
                  onPickCheckIn: _pickCheckIn,
                  onPickCheckOut: _pickCheckOut,
                  onGuestsChanged: (g) => setState(() => _guests = g),
                ),
                _PaymentStep(
                  paymentMethod: _paymentMethod,
                  onPaymentMethodChanged: (m) => setState(() => _paymentMethod = m),
                  gcashNameController: _gcashNameController,
                  gcashNumberController: _gcashNumberController,
                  gcashRefController: _gcashRefController,
                  bankNameController: _bankNameController,
                  depositorNameController: _depositorNameController,
                  bankAccountController: _bankAccountController,
                  notesController: _notesController,
                ),
                _ReviewStep(
                  unit: unit,
                  checkIn: _checkIn,
                  checkOut: _checkOut,
                  guests: _guests,
                  nights: _nights,
                  estimatedTotal: _estimatedTotal,
                  paymentLabel: _paymentLabel(),
                  agreeTerms: _agreeTerms,
                  onAgreeChanged: (v) => setState(() => _agreeTerms = v),
                  formatDateTime: (d, {required fallbackTime}) => _formatDateTime(d, fallbackTime: fallbackTime),
                  checkInFallbackTime: _checkInTimeOfDay,
                  checkOutFallbackTime: _checkOutTimeOfDay,
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(color: scheme.error),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _submitting ? null : () => _goToStep(_step - 1),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _submitting || _loadingAvailability
                        ? null
                        : () {
                            if (_step == 0) {
                              _nextFromDates();
                            } else if (_step == 1) {
                              _nextFromPayment();
                            } else {
                              _submit();
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE6834B),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(_step == 2 ? 'Confirm payment' : 'Continue'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
        ),
        if (_showSuccessSplash)
          Positioned.fill(
            child: KelseySuccessSplash(
              title: 'Booking submitted!',
              subtitle: _successSubtitle ?? 'Awaiting payment verification',
            ),
          ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.stepNumber,
    required this.active,
    required this.done,
  });

  final String label;
  final int stepNumber;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final activeColor = KelseyColors.tealButton;
    final inactiveColor = Colors.grey.shade400;
    final isHighlighted = active || done;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isHighlighted ? activeColor : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(
                    '$stepNumber',
                    style: textTheme.labelLarge?.copyWith(
                      color: active ? Colors.white : inactiveColor,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(
              color: isHighlighted ? activeColor : inactiveColor,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: active ? KelseyColors.tealButton : Colors.grey.shade300,
      ),
    );
  }
}

class _DatesStep extends StatelessWidget {
  const _DatesStep({
    required this.loading,
    required this.checkInLabel,
    required this.checkInTimeLabel,
    required this.checkOutLabel,
    required this.checkOutTimeLabel,
    required this.guests,
    required this.maxGuests,
    required this.nights,
    required this.unit,
    required this.onPickCheckIn,
    required this.onPickCheckOut,
    required this.onGuestsChanged,
  });

  final bool loading;
  final String checkInLabel;
  final String checkInTimeLabel;
  final String checkOutLabel;
  final String checkOutTimeLabel;
  final int guests;
  final int maxGuests;
  final int nights;
  final UnitListing unit;
  final VoidCallback onPickCheckIn;
  final VoidCallback onPickCheckOut;
  final ValueChanged<int> onGuestsChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final checkInSelected = checkInLabel != 'Select date';
    final checkOutSelected = checkOutLabel != 'Select date';

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(unit.location, style: textTheme.bodyMedium?.copyWith(color: KelseyColors.cardMuted)),
        const SizedBox(height: 20),
        Text(
          'Select your dates',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Material(
          color: scheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StayDateTile(
                    label: 'Check-in',
                    icon: Icons.login_rounded,
                    dateLine: checkInLabel,
                    timeLine: checkInTimeLabel,
                    isPlaceholder: !checkInSelected,
                    onTap: onPickCheckIn,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.65),
                ),
                Expanded(
                  child: _StayDateTile(
                    label: 'Check-out',
                    icon: Icons.logout_rounded,
                    dateLine: checkOutLabel,
                    timeLine: checkOutTimeLabel,
                    isPlaceholder: !checkOutSelected,
                    onTap: onPickCheckOut,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Guests',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Material(
          color: scheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _GuestStepButton(
                  icon: Icons.remove_rounded,
                  enabled: guests > 1,
                  onPressed: () => onGuestsChanged(guests - 1),
                ),
                Expanded(
                  child: Text(
                    guests == 1 ? '1 guest' : '$guests guests',
                    textAlign: TextAlign.center,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _GuestStepButton(
                  icon: Icons.add_rounded,
                  enabled: guests < maxGuests,
                  onPressed: () => onGuestsChanged(guests + 1),
                ),
              ],
            ),
          ),
        ),
        if (nights > 0) ...[
          const SizedBox(height: 12),
          Text(
            '$nights night${nights == 1 ? '' : 's'} · ${CurrencyUtils.formatPerNight(unit.price, currency: unit.currency)}',
            style: textTheme.bodyMedium?.copyWith(color: KelseyColors.cardMuted),
          ),
        ],
      ],
    );
  }
}

class _StayDateTile extends StatelessWidget {
  const _StayDateTile({
    required this.label,
    required this.icon,
    required this.dateLine,
    required this.timeLine,
    required this.isPlaceholder,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String dateLine;
  final String timeLine;
  final bool isPlaceholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
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
              const SizedBox(height: 10),
              Text(
                dateLine,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: isPlaceholder ? scheme.onSurfaceVariant : null,
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
          ),
        ),
      ),
    );
  }
}

class _GuestStepButton extends StatelessWidget {
  const _GuestStepButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: enabled ? scheme.surfaceContainerHighest : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? KelseyColors.tealButton : scheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.gcashNameController,
    required this.gcashNumberController,
    required this.gcashRefController,
    required this.bankNameController,
    required this.depositorNameController,
    required this.bankAccountController,
    required this.notesController,
  });

  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final TextEditingController gcashNameController;
  final TextEditingController gcashNumberController;
  final TextEditingController gcashRefController;
  final TextEditingController bankNameController;
  final TextEditingController depositorNameController;
  final TextEditingController bankAccountController;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Payment method',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Only GCash and Bank Transfer are accepted.',
          style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'gcash', label: Text('GCash')),
            ButtonSegment(value: 'bank_transfer', label: Text('Bank')),
          ],
          selected: {paymentMethod},
          onSelectionChanged: (s) => onPaymentMethodChanged(s.first),
        ),
        const SizedBox(height: 20),
        if (paymentMethod == 'gcash') ...[
          TextField(
            controller: gcashNameController,
            decoration: const InputDecoration(labelText: 'Name on GCash account'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: gcashNumberController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'GCash mobile number'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: gcashRefController,
            decoration: const InputDecoration(labelText: 'Reference number (optional)'),
          ),
        ] else ...[
          TextField(
            controller: bankNameController,
            decoration: const InputDecoration(labelText: 'Bank name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: depositorNameController,
            decoration: const InputDecoration(labelText: 'Depositor name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bankAccountController,
            decoration: const InputDecoration(labelText: 'Account number'),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: notesController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.unit,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.nights,
    required this.estimatedTotal,
    required this.paymentLabel,
    required this.agreeTerms,
    required this.onAgreeChanged,
    required this.formatDateTime,
    required this.checkInFallbackTime,
    required this.checkOutFallbackTime,
  });

  final UnitListing unit;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int guests;
  final int nights;
  final double estimatedTotal;
  final String paymentLabel;
  final bool agreeTerms;
  final ValueChanged<bool> onAgreeChanged;
  final String Function(DateTime?, {required TimeOfDay fallbackTime}) formatDateTime;
  final TimeOfDay checkInFallbackTime;
  final TimeOfDay checkOutFallbackTime;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Review your booking', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _ReviewRow(label: 'Property', value: unit.title),
        _ReviewRow(label: 'Location', value: unit.location),
        _ReviewRow(
          label: 'Check-in',
          value: formatDateTime(checkIn, fallbackTime: checkInFallbackTime),
        ),
        _ReviewRow(
          label: 'Check-out',
          value: formatDateTime(checkOut, fallbackTime: checkOutFallbackTime),
        ),
        _ReviewRow(label: 'Guests', value: '$guests'),
        _ReviewRow(label: 'Nights', value: '$nights'),
        _ReviewRow(label: 'Payment', value: paymentLabel),
        _ReviewRow(
          label: 'Estimated total',
          value: CurrencyUtils.formatAmount(estimatedTotal, currency: unit.currency),
        ),
        const SizedBox(height: 12),
        Text(
          'Final amount is calculated by the server. Your booking will be pending until payment is verified.',
          style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: agreeTerms,
          onChanged: (v) => onAgreeChanged(v ?? false),
          title: const Text('I agree to the payment terms and conditions'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

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
            width: 110,
            child: Text(label, style: textTheme.bodyMedium?.copyWith(color: KelseyColors.cardMuted)),
          ),
          Expanded(
            child: Text(value, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
