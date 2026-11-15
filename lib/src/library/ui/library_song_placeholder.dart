import 'package:flutter/material.dart';

class LibrarySongPlaceholder extends StatelessWidget {
  const LibrarySongPlaceholder({super.key, this.height});
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height ?? (MediaQuery.sizeOf(context).width <= 720 ? 78 : 82),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 56,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 12,
                width: 180,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.04),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
