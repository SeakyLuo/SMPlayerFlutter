part of 'search_page.dart';

class _SearchLyricsExcerpt extends StatefulWidget {
  const _SearchLyricsExcerpt({
    super.key,
    required this.match,
    required this.query,
    required this.i18n,
    required this.onTap,
  });

  final LocalLyricsSearchMatch match;
  final String query;
  final SmPlayerI18n i18n;
  final VoidCallback onTap;

  @override
  State<_SearchLyricsExcerpt> createState() => _SearchLyricsExcerptState();
}

class _SearchLyricsExcerptState extends State<_SearchLyricsExcerpt> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    final match = widget.match;
    final canExpand =
        match.matchContexts.length > 1 ||
        match.matchContexts.single.length > match.contextLines.length;
    final contexts = _expanded ? match.matchContexts : [match.contextLines];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.subtleBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.textMuted.withValues(alpha: 0.075),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < contexts.length; index++) ...[
                  if (index > 0) const SizedBox(height: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onTap,
                      child: SearchMatchText(
                        text: contexts[index].join('\n'),
                        query: widget.query,
                        maxLines: null,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],
                if (canExpand)
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 112,
                      height: 32,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: colors.textMuted,
                          backgroundColor: Colors.transparent,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.i18n.t(
                                _expanded
                                    ? 'song.collapseLyrics'
                                    : 'song.expandLyrics',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _expanded
                                  ? FluentIcons.chevron_up_24_regular
                                  : FluentIcons.chevron_down_24_regular,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
