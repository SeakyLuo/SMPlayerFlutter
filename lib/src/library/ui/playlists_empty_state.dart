part of 'playlists_page.dart';

class _PlaylistsEmptyState extends StatelessWidget {
  const _PlaylistsEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        key: const ValueKey('Playlists.EmptyState'),
        decoration: BoxDecoration(
          color: _PlaylistsColors.emptyStateSurfaceFor(brightness),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _PlaylistsColors.emptyStateBorderFor(brightness),
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
                  color: _PlaylistsColors.textStrongFor(brightness),
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
                    color: _PlaylistsColors.textMutedFor(brightness),
                    fontSize: 14,
                    height: 1.65,
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
