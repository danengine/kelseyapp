import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../kelsey_brand.dart';
import '../utils/external_url.dart';

/// Renders plain text with tappable http(s) links.
class LinkifiedText extends StatelessWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkColor = KelseyColors.adminTeal,
  });

  final String text;
  final TextStyle? style;
  final Color linkColor;

  static final _urlPattern = RegExp(
    r'(https?://[^\s]+|www\.[^\s]+)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyLarge;
    final spans = <InlineSpan>[];
    var start = 0;

    for (final match in _urlPattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: baseStyle));
      }

      final raw = match.group(0)!;
      final url = raw.startsWith('http') ? raw : 'https://$raw';
      spans.add(
        TextSpan(
          text: raw,
          style: baseStyle?.copyWith(
            color: linkColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => openExternalUrl(url),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    if (spans.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
