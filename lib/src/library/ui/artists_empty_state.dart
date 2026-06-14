part of 'artists_page.dart';

class _ArtistsEmptyState extends StatelessWidget {
  const _ArtistsEmptyState({
    required this.title,
    required this.message,
    this.detail = false,
  });

  final String title;
  final String message;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final titleStyle = TextStyle(
      color: _ArtistsColors.textStrongFor(brightness),
      fontSize: 26,
      fontWeight: FontWeight.w700,
    );
    final messageStyle = TextStyle(
      color: _ArtistsColors.textMutedFor(brightness),
      fontSize: 14,
      height: 1.65,
    );
    final decoration = BoxDecoration(
      color: _ArtistsColors.emptyStateSurfaceFor(brightness),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _ArtistsColors.emptyStateBorderFor(brightness)),
    );
    if (detail) {
      return Center(
        child: DecoratedBox(
          key: const ValueKey('Artists.EmptyState'),
          decoration: _ArtistsColors.detailEmptyStateDecoration(brightness),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, textAlign: TextAlign.center, style: titleStyle),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: messageStyle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      key: const ValueKey('Artists.EmptyState'),
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: titleStyle),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(message, style: messageStyle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
