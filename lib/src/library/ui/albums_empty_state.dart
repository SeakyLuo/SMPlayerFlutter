part of 'albums_page.dart';

class _AlbumsEmptyState extends StatelessWidget {
  const _AlbumsEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      key: const ValueKey('Albums.EmptyState'),
      decoration: BoxDecoration(
        color: _AlbumsColors.emptyStateSurfaceFor(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _AlbumsColors.emptyStateBorderFor(brightness),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _AlbumsColors.textStrongFor(brightness),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                message,
                style: TextStyle(
                  color: _AlbumsColors.textMutedFor(brightness),
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
