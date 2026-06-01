import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'kelsey_brand.dart';

/// Logo row — same on login and sign-up.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: "kelsey's homestay",
        image: true,
        child: SvgPicture.asset(
          KelseyLoginAssets.logo,
          height: KelseyLoginAssets.logoHeight,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}

/// Hello / welcome block — same on login and sign-up.
class AuthWelcomeBlock extends StatelessWidget {
  const AuthWelcomeBlock({super.key, required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello,',
          style: textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            height: 1.05,
          ),
        ),
        Text(
          'welcome!',
          style: textTheme.displaySmall?.copyWith(
            color: KelseyColors.yellow,
            fontWeight: FontWeight.bold,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "A welcoming stay, the Kelsey's way",
          style: textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

InputDecoration kelseyAuthInputDecoration(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w400),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: KelseyColors.inputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: KelseyColors.inputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: KelseyColors.tealButton, width: 1.5),
    ),
  );
}
