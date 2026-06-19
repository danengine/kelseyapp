import 'package:flutter/material.dart';

import '../utils/chat_unit_parser.dart';

/// Renders chatbot text with preserved line breaks and list spacing.
class ChatFormattedText extends StatelessWidget {
  const ChatFormattedText({
    super.key,
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  static final _numberedLine = RegExp(r'^(\d+)\.\s+(.*)$');
  static final _bulletLine = RegExp(r'^[-*•]\s+(.*)$');

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyLarge;
    final normalized = normalizeChatMessageDisplay(text);
    final lines = normalized.split('\n');
    final children = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      final numbered = _numberedLine.firstMatch(line.trim());
      if (numbered != null) {
        children.add(_ListLineRow(
          marker: '${numbered.group(1)}.',
          body: numbered.group(2)!,
          style: baseStyle,
          markerWeight: FontWeight.w700,
        ));
        continue;
      }

      final bulleted = _bulletLine.firstMatch(line.trim());
      if (bulleted != null) {
        children.add(_ListLineRow(
          marker: '•',
          body: bulleted.group(1)!,
          style: baseStyle,
          markerWeight: FontWeight.w800,
        ));
        continue;
      }

      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            line,
            style: baseStyle?.copyWith(height: 1.45),
          ),
        ),
      );
    }

    if (children.isEmpty) {
      return Text(normalized, style: baseStyle?.copyWith(height: 1.45));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _ListLineRow extends StatelessWidget {
  const _ListLineRow({
    required this.marker,
    required this.body,
    required this.style,
    required this.markerWeight,
  });

  final String marker;
  final String body;
  final TextStyle? style;
  final FontWeight markerWeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              marker,
              style: style?.copyWith(
                fontWeight: markerWeight,
                height: 1.45,
              ),
            ),
          ),
          Expanded(
            child: Text(
              body,
              style: style?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
