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

const _bookTeal = KelseyColors.adminTeal;
const _bookSurface = KelseyColors.adminSurface;
const _bookBorder = Color(0xFFF3F4F6);
const _textPrimary = Color(0xFF111827);
const _textMuted = Color(0xFF6B7280);

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

    return Stack(
      children: [
        Scaffold(
          backgroundColor: _bookSurface,
          appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            backgroundColor: _bookSurface,
            foregroundColor: _textPrimary,
            elevation: 0,
            title: Text(
              'Reserve',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: _textPrimary),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(72),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _BookStepper(currentStep: _step),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _error!,
                      style: textTheme.bodyMedium?.copyWith(color: Colors.red.shade800),
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      if (_step > 0)
                        OutlinedButton(
                          onPressed: _submitting ? null : () => _goToStep(_step - 1),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _bookTeal,
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      if (_step > 0) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
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
                            backgroundColor: _bookTeal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text(
                                  _step == 2 ? 'Confirm payment' : 'Continue',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                        ),
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

class _BookStepper extends StatelessWidget {
  const _BookStepper({required this.currentStep});

  final int currentStep;

  static const _steps = ['Dates', 'Payment', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIndex = i ~/ 2;
          final done = currentStep > stepIndex;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: done ? _bookTeal : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }

        final stepIndex = i ~/ 2;
        final active = currentStep == stepIndex;
        final done = currentStep > stepIndex;
        final highlighted = active || done;

        return Expanded(
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: highlighted ? _bookTeal : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: done
                    ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          color: active ? Colors.white : _textMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                _steps[stepIndex],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: highlighted ? _bookTeal : _textMuted,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bookBorder),
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

class _BookSectionTitle extends StatelessWidget {
  const _BookSectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(fontSize: 13, color: _textMuted)),
        ],
      ],
    );
  }
}

InputDecoration _bookInputDecoration(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: _textMuted, fontWeight: FontWeight.w500),
    floatingLabelStyle: const TextStyle(color: _bookTeal, fontWeight: FontWeight.w600),
    filled: true,
    fillColor: _bookSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _bookTeal, width: 1.5),
    ),
  );
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
    final checkInSelected = checkInLabel != 'Select date';
    final checkOutSelected = checkOutLabel != 'Select date';

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: _bookTeal),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _BookCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: unit.mainImageUrl.isNotEmpty
                    ? Image.network(
                        unit.mainImageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _unitThumbPlaceholder(),
                      )
                    : _unitThumbPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: _textMuted),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            unit.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: _textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyUtils.formatPerNight(unit.price, currency: unit.currency),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _bookTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _BookSectionTitle('Select your dates', subtitle: 'Choose check-in and check-out'),
        const SizedBox(height: 12),
        _BookCard(
          padding: EdgeInsets.zero,
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
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),
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
        const _BookSectionTitle('Guests'),
        const SizedBox(height: 12),
        _BookCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _textPrimary),
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
        if (nights > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _bookTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _bookTeal.withValues(alpha: 0.15)),
            ),
            child: Text(
              '$nights night${nights == 1 ? '' : 's'} · ${CurrencyUtils.formatPerNight(unit.price, currency: unit.currency)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _bookTeal),
            ),
          ),
        ],
      ],
    );
  }
}

Widget _unitThumbPlaceholder() {
  return Container(
    width: 72,
    height: 72,
    color: _bookBorder,
    child: const Icon(Icons.home_outlined, color: _textMuted),
  );
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: _bookTeal),
                  const SizedBox(width: 6),
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: _textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      fontSize: 11,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                dateLine,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.25,
                  color: isPlaceholder ? _textMuted : _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeLine,
                style: const TextStyle(
                  color: _bookTeal,
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
    return Material(
      color: enabled ? _bookSurface : _bookSurface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? _bookTeal : _textMuted.withValues(alpha: 0.4),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const _BookSectionTitle(
          'Payment method',
          subtitle: 'Only GCash and Bank Transfer are accepted.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _PaymentMethodTile(
                label: 'GCash',
                icon: Icons.phone_android_rounded,
                selected: paymentMethod == 'gcash',
                onTap: () => onPaymentMethodChanged('gcash'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PaymentMethodTile(
                label: 'Bank',
                icon: Icons.account_balance_outlined,
                selected: paymentMethod == 'bank_transfer',
                onTap: () => onPaymentMethodChanged('bank_transfer'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _BookCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paymentMethod == 'gcash' ? 'GCash details' : 'Bank transfer details',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _textPrimary),
              ),
              const SizedBox(height: 16),
              if (paymentMethod == 'gcash') ...[
                TextField(
                  controller: gcashNameController,
                  decoration: _bookInputDecoration('Name on GCash account'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: gcashNumberController,
                  keyboardType: TextInputType.phone,
                  decoration: _bookInputDecoration('GCash mobile number'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: gcashRefController,
                  decoration: _bookInputDecoration('Reference number (optional)'),
                ),
              ] else ...[
                TextField(
                  controller: bankNameController,
                  decoration: _bookInputDecoration('Bank name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: depositorNameController,
                  decoration: _bookInputDecoration('Depositor name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: bankAccountController,
                  decoration: _bookInputDecoration('Account number'),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: _bookInputDecoration('Notes (optional)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? _bookTeal.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _bookTeal : const Color(0xFFE5E7EB),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: selected ? _bookTeal : _textMuted),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: selected ? _bookTeal : _textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const _BookSectionTitle('Review your booking', subtitle: 'Confirm details before payment'),
        const SizedBox(height: 14),
        _BookCard(
          child: Column(
            children: [
              _ReviewRow(label: 'Property', value: unit.title),
              const Divider(height: 20, color: Color(0xFFF3F4F6)),
              _ReviewRow(label: 'Location', value: unit.location),
              const Divider(height: 20, color: Color(0xFFF3F4F6)),
              _ReviewRow(
                label: 'Check-in',
                value: formatDateTime(checkIn, fallbackTime: checkInFallbackTime),
              ),
              const Divider(height: 20, color: Color(0xFFF3F4F6)),
              _ReviewRow(
                label: 'Check-out',
                value: formatDateTime(checkOut, fallbackTime: checkOutFallbackTime),
              ),
              const Divider(height: 20, color: Color(0xFFF3F4F6)),
              _ReviewRow(label: 'Guests', value: '$guests'),
              const Divider(height: 20, color: Color(0xFFF3F4F6)),
              _ReviewRow(label: 'Nights', value: '$nights'),
              const Divider(height: 20, color: Color(0xFFF3F4F6)),
              _ReviewRow(label: 'Payment', value: paymentLabel),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _BookCard(
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Estimated total',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: _textPrimary),
                ),
              ),
              Text(
                CurrencyUtils.formatAmount(estimatedTotal, currency: unit.currency),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _bookTeal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _BookCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: agreeTerms,
            activeColor: _bookTeal,
            onChanged: (v) => onAgreeChanged(v ?? false),
            title: const Text(
              'I agree to the payment terms and conditions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textPrimary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary),
          ),
        ),
      ],
    );
  }
}
