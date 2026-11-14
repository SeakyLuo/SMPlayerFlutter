part of 'playlists_page.dart';

class _PlaylistsEmptyState extends StatelessWidget {
  const _PlaylistsEmptyState({
    required this.title,
    required this.message,
    required this.searching,
    required this.onAction,
  });

  final String title;
  final String message;
  final bool searching;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final i18n = context.smPlayerI18n;
    return LayoutBuilder(
      builder:
          (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (searching)
                          Icon(
                            FluentIcons.search_24_regular,
                            size: 48,
                            color: _PlaylistsColors.textMutedFor(brightness),
                          )
                        else
                          const LocalPageEmptyArtwork(),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _PlaylistsColors.textStrongFor(brightness),
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _PlaylistsColors.textMutedFor(brightness),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (onAction != null)
                          PopupDialogActionButton(
                            label: i18n.t(
                              searching
                                  ? 'common.clearSearch'
                                  : 'playlists.createNew',
                            ),
                            icon:
                                searching
                                    ? FluentIcons.dismiss_20_regular
                                    : FluentIcons.add_20_regular,
                            primary: true,
                            height:
                                Platform.isAndroid || Platform.isIOS ? 48 : 40,
                            onPressed: onAction,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
