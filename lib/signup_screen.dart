import 'package:flutter/material.dart';

import 'auth_shared.dart';
import 'kelsey_brand.dart';
import 'services/auth_service.dart';

/// Sign-up flow matching kelsey homestay auth styling (same shell as login).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = const AuthService();
  int _step = 0;
  bool _isSubmitting = false;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _dobDisplay = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender;
  final _street = TextEditingController();
  final _barangay = TextEditingController();
  final _city = TextEditingController();
  final _zip = TextEditingController();

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  static const _genders = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];

  static String? _genderForApi(String? label) {
    return switch (label) {
      'Female' => 'female',
      'Male' => 'male',
      'Non-binary' => 'non-binary',
      'Prefer not to say' => 'prefer_not_to_say',
      _ => null,
    };
  }

  static String _birthDateForApi(DateTime d) {
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  /// US-style display: 03/04/2005 for March 4, 2005.
  static String _formatDobMmDdYyyy(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$m/$day/${d.year}';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _dobDisplay.dispose();
    _street.dispose();
    _barangay.dispose();
    _city.dispose();
    _zip.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _req(String? v, String msg) {
    if (v == null || v.trim().isEmpty) return msg;
    return null;
  }

  String? _zipValidator(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter ZIP code';
    if (int.tryParse(t) == null) return 'Digits only';
    return null;
  }

  Future<void> _pickDateOfBirth() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 21, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? DateTime(now.year - 18, 1, 1) : initial,
      firstDate: DateTime(1920, 1, 1),
      lastDate: now,
      helpText: 'Date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: KelseyColors.tealButton, brightness: Brightness.light),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() {
      _dateOfBirth = picked;
      _dobDisplay.text = _formatDobMmDdYyyy(picked);
    });
  }

  String? _dobValidator(String? _) {
    if (_dateOfBirth == null) return 'Select date of birth';
    return null;
  }

  void _continueFromPersonal() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _step = 1);
  }

  String? _passwordValidator(String? v) {
    if (v == null || v.isEmpty) return 'Password required';
    if (v.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Include a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include a number';
    return null;
  }

  Future<void> _submitAccount() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_password.text != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _authService.register(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        password: _password.text,
        gender: _genderForApi(_gender),
        birthDate: _dateOfBirth == null ? null : _birthDateForApi(_dateOfBirth!),
        street: _street.text,
        barangay: _barangay.text,
        city: _city.text,
        zipCode: _zip.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. You can log in with your email.')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  Widget _twoFields(BuildContext context, {required Widget left, required Widget right}) {
    final wide = MediaQuery.sizeOf(context).width >= 400;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        left,
        const SizedBox(height: 14),
        right,
      ],
    );
  }

  Widget _stepHeader(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StepDot(active: _step == 0, label: '1', title: 'Personal Info', textTheme: textTheme),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Divider(height: 2, thickness: 2, color: Colors.grey.shade300),
              ),
            ),
            _StepDot(active: _step == 1, label: '2', title: 'Account Setup', textTheme: textTheme),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: KelseyColors.background,
      resizeToAvoidBottomInset: true,
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat — connect to your support widget.')),
          );
        },
        backgroundColor: KelseyColors.tealButton,
        foregroundColor: Colors.white,
        child: const Icon(Icons.chat_bubble_outline),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.paddingOf(context).bottom + 72,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(),
              const SizedBox(height: 28),
              AuthWelcomeBlock(textTheme: textTheme),
              const SizedBox(height: 28),
              Material(
                color: Colors.white,
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Create an Account',
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            style: textTheme.bodyMedium?.copyWith(color: KelseyColors.cardMuted),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Text(
                                    'Log In',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: KelseyColors.tealButton,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _stepHeader(textTheme),
                        if (_step == 0) ...[
                          _twoFields(
                            context,
                            left: TextFormField(
                              controller: _firstName,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              enabled: !_isSubmitting,
                              validator: (v) => _req(v, 'First name'),
                              decoration: kelseyAuthInputDecoration('First Name'),
                            ),
                            right: TextFormField(
                              controller: _lastName,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              enabled: !_isSubmitting,
                              validator: (v) => _req(v, 'Last name'),
                              decoration: kelseyAuthInputDecoration('Last Name'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _twoFields(
                            context,
                            left: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Date of Birth', style: textTheme.labelMedium?.copyWith(color: KelseyColors.cardMuted)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _dobDisplay,
                                  readOnly: true,
                                  enabled: !_isSubmitting,
                                  onTap: _isSubmitting ? null : _pickDateOfBirth,
                                  validator: _dobValidator,
                                  decoration: kelseyAuthInputDecoration(
                                    'MM / DD / YYYY',
                                    suffixIcon: IconButton(
                                      icon: Icon(Icons.calendar_month_rounded, color: Colors.grey.shade700),
                                      onPressed: _pickDateOfBirth,
                                      tooltip: 'Pick date',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            right: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Gender', style: textTheme.labelMedium?.copyWith(color: KelseyColors.cardMuted)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _gender, // ignore: deprecated_member_use
                                  isExpanded: true,
                                  decoration: kelseyAuthInputDecoration('Select gender'),
                                  validator: (v) => v == null ? 'Select gender' : null,
                                  items: _genders
                                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                      .toList(),
                                  onChanged: _isSubmitting ? null : (v) => setState(() => _gender = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _twoFields(
                            context,
                            left: TextFormField(
                              controller: _street,
                              textInputAction: TextInputAction.next,
                              validator: (v) => _req(v, 'Street'),
                              decoration: kelseyAuthInputDecoration('Street'),
                            ),
                            right: TextFormField(
                              controller: _barangay,
                              textInputAction: TextInputAction.next,
                              validator: (v) => _req(v, 'Barangay'),
                              decoration: kelseyAuthInputDecoration('Barangay'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _twoFields(
                            context,
                            left: TextFormField(
                              controller: _city,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => _req(v, 'City'),
                              decoration: kelseyAuthInputDecoration('City'),
                            ),
                            right: TextFormField(
                              controller: _zip,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              validator: _zipValidator,
                              decoration: kelseyAuthInputDecoration('ZIP Code'),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _continueFromPersonal,
                              style: FilledButton.styleFrom(
                                backgroundColor: KelseyColors.tealButton,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: const StadiumBorder(),
                                textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Save and Continue'),
                            ),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            enabled: !_isSubmitting,
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              if (t.isEmpty) return 'Email required';
                              if (!t.contains('@')) return 'Invalid email';
                              return null;
                            },
                            decoration: kelseyAuthInputDecoration('Email Address'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            enabled: !_isSubmitting,
                            validator: _passwordValidator,
                            decoration: kelseyAuthInputDecoration('Password'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmPassword,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            enabled: !_isSubmitting,
                            onFieldSubmitted: (_) => _submitAccount(),
                            validator: (v) => _req(v, 'Confirm password'),
                            decoration: kelseyAuthInputDecoration('Confirm Password'),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSubmitting ? null : () => setState(() => _step = 0),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    side: const BorderSide(color: KelseyColors.tealButton),
                                    foregroundColor: KelseyColors.tealButton,
                                  ),
                                  child: const Text('Back'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _isSubmitting ? null : _submitAccount,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: KelseyColors.tealButton,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: const StadiumBorder(),
                                      textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                          )
                                        : const Text('Create account'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.active,
    required this.label,
    required this.title,
    required this.textTheme,
  });

  final bool active;
  final String label;
  final String title;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? KelseyColors.tealButton : Colors.grey.shade300,
          ),
          child: Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              color: active ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 100,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: textTheme.labelSmall?.copyWith(
              color: active ? KelseyColors.tealButton : KelseyColors.cardMuted,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
