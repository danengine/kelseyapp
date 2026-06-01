import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'main_shell.dart';
import 'services/auth_service.dart';
import 'services/auth_session.dart';
import 'services/auth_storage.dart';

/// Restores a saved session on launch, then shows login or home.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final restored = await AuthStorage.restoreSession();
    if (restored) {
      // Refresh profile when online; offline still uses cached profile + token.
      await const AuthService().refreshProfileIfOnline();
    }
    if (!mounted) return;
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (AuthSession.isLoggedIn) {
      return const MainShell();
    }

    return const LoginScreen();
  }
}
