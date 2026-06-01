import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'kelsey_brand.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KelseyApp());
}

class KelseyApp extends StatelessWidget {
  const KelseyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "kelsey's homestay",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: KelseyColors.tealButton,
          brightness: Brightness.light,
        ),
      ),
      home: const AuthGate(),
    );
  }
}
