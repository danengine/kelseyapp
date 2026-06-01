import 'package:flutter/material.dart';

import 'kelsey_brand.dart';

/// Full-screen success overlay — yellow check on teal, matching login.
class KelseySuccessSplash extends StatefulWidget {
  const KelseySuccessSplash({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<KelseySuccessSplash> createState() => _KelseySuccessSplashState();
}

class _KelseySuccessSplashState extends State<KelseySuccessSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 720))
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    final fade = CurvedAnimation(parent: _controller, curve: const Interval(0.35, 1, curve: Curves.easeOut));

    return Material(
      color: KelseyColors.background.withValues(alpha: 0.94),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: scale,
                child: const Icon(Icons.check_circle_rounded, size: 96, color: KelseyColors.yellow),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: fade,
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: fade,
                child: Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
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
