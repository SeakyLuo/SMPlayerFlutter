import 'package:flutter/material.dart';

class SearchMatchText extends StatelessWidget {
  const SearchMatchText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.highlightColor,
  });

  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim();
    if (needle.isEmpty) {
      return Text(text, maxLines: maxLines, overflow: overflow, style: style);
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in RegExp(
      RegExp.escape(needle),
      caseSensitive: false,
    ).allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: style.copyWith(
            color: highlightColor ?? Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
