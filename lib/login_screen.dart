import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_shared.dart';
import 'kelsey_brand.dart';
import 'kelsey_success_splash.dart';
import 'main_shell.dart';
import 'services/auth_service.dart';
import 'services/auth_session.dart';
import 'services/auth_storage.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final AuthService _authService = const AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _showSuccessSplash = false;

  List<BiometricType> _biometricTypes = [];

  /// Show the biometric row on mobile/desktop OSes where [local_auth] is typically used.
  /// Not gated on [LocalAuthentication.canCheckBiometrics] (often false on simulators / before enrollment).
  bool get _showBiometricOption {
    if (kIsWeb) return false;
    const supported = {
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    };
    return supported.contains(defaultTargetPlatform);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _probeBiometrics());
  }

  Future<void> _probeBiometrics() async {
    try {
      final types = await _localAuth.getAvailableBiometrics();
      if (!mounted) return;
      setState(() => _biometricTypes = types);
    } catch (_) {
      if (mounted) setState(() => _biometricTypes = []);
    }
  }

  String get _biometricButtonLabel {
    if (_biometricTypes.contains(BiometricType.face)) return 'Log in with Face ID';
    if (_biometricTypes.contains(BiometricType.fingerprint)) return 'Log in with fingerprint';
    if (_biometricTypes.contains(BiometricType.iris)) return 'Log in with iris';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'Log in with Face ID or Touch ID';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'Log in with Touch ID';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'Log in with Windows Hello';
    return 'Log in with biometrics';
  }

  IconData get _biometricIcon {
    if (_biometricTypes.contains(BiometricType.face)) return Icons.face_rounded;
    if (_biometricTypes.contains(BiometricType.fingerprint)) return Icons.fingerprint_rounded;
    if (defaultTargetPlatform == TargetPlatform.windows) return Icons.phonelink_lock_rounded;
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      return Icons.face_rounded;
    }
    return Icons.fingerprint_rounded;
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!v.contains('@')) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    return null;
  }

  Route<void> _homeEntranceRoute() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => const MainShell(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 480),
    );
  }

  Future<void> _runSuccessSplashThenGoHome() async {
    setState(() {
      _isSubmitting = false;
      _showSuccessSplash = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1150));
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(_homeEntranceRoute());
  }

  Future<void> _submitPasswordLogin() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isSubmitting = true);

    try {
      await _authService.login(
        email: email,
        password: password,
        persist: _rememberMe,
      );
      if (!mounted) return;
      await _runSuccessSplashThenGoHome();
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

  /// After a successful [LocalAuthentication.authenticate], restore the user session
  /// (e.g. read a refresh token from [flutter_secure_storage]) and navigate home.
  Future<void> _signInWithBiometrics() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: "Verify it's you to sign in to kelsey's homestay.",
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (!mounted) return;
      if (ok) {
        final hasSession = AuthSession.isLoggedIn || await AuthStorage.restoreSession();
        if (!mounted) return;
        if (!hasSession) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign in with email and password first to use biometrics.')),
          );
          return;
        }
        await _runSuccessSplashThenGoHome();
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final code = e.code;
      if (code == 'NotAvailable' || code == 'NotEnrolled' || code == 'LockedOut' || code == 'PermanentlyLockedOut') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Biometrics unavailable')),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: KelseyColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.paddingOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrandHeader(),
                  const SizedBox(height: 28),
                  AuthWelcomeBlock(textTheme: textTheme),
                  const SizedBox(height: 28),
                  _LoginCard(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    rememberMe: _rememberMe,
                    onRememberChanged: (v) => setState(() => _rememberMe = v ?? false),
                    textTheme: textTheme,
                    showBiometric: _showBiometricOption,
                    biometricLabel: _biometricButtonLabel,
                    biometricIcon: _biometricIcon,
                    onBiometric: _signInWithBiometrics,
                    emailValidator: _validateEmail,
                    passwordValidator: _validatePassword,
                    isSubmitting: _isSubmitting,
                    onPasswordLogin: _submitPasswordLogin,
                  ),
                ],
              ),
            ),
          ),
          if (_showSuccessSplash)
            const Positioned.fill(
              child: KelseySuccessSplash(
                title: 'Welcome back!',
                subtitle: 'Opening your stay…',
              ),
            ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.rememberMe,
    required this.onRememberChanged,
    required this.textTheme,
    required this.showBiometric,
    required this.biometricLabel,
    required this.biometricIcon,
    required this.onBiometric,
    required this.emailValidator,
    required this.passwordValidator,
    required this.isSubmitting,
    required this.onPasswordLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool rememberMe;
  final ValueChanged<bool?> onRememberChanged;
  final TextTheme textTheme;
  final bool showBiometric;
  final String biometricLabel;
  final IconData biometricIcon;
  final Future<void> Function() onBiometric;
  final FormFieldValidator<String> emailValidator;
  final FormFieldValidator<String> passwordValidator;
  final bool isSubmitting;
  final Future<void> Function() onPasswordLogin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log In',
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
                    const TextSpan(text: "Don't have an account? "),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
                          );
                        },
                        child: Text(
                          'Sign Up',
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
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: emailValidator,
                enabled: !isSubmitting,
                decoration: kelseyAuthInputDecoration('Email Address'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: passwordValidator,
                enabled: !isSubmitting,
                onFieldSubmitted: (_) => onPasswordLogin(),
                decoration: kelseyAuthInputDecoration('Password'),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: rememberMe,
                      onChanged: onRememberChanged,
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return KelseyColors.tealButton;
                        }
                        return Colors.white;
                      }),
                      side: BorderSide(color: Colors.grey.shade400),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Remember me',
                      style: textTheme.bodyMedium?.copyWith(color: KelseyColors.cardMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: textTheme.bodyMedium?.copyWith(
                        color: KelseyColors.tealButton,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: isSubmitting ? null : () => onPasswordLogin(),
                  style: FilledButton.styleFrom(
                    backgroundColor: KelseyColors.tealButton,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Log In'),
                ),
              ),
              if (showBiometric) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'or',
                    style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: isSubmitting ? null : () => onBiometric(),
                    icon: Icon(biometricIcon, color: KelseyColors.tealButton),
                    label: Text(
                      biometricLabel,
                      style: textTheme.titleSmall?.copyWith(
                        color: KelseyColors.tealButton,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: KelseyColors.tealButton, width: 1.5),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
