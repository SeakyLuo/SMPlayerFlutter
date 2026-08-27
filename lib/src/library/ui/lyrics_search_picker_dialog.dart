part of 'music_dialog.dart';

class LyricsSearchPickerDialog extends StatefulWidget {
  const LyricsSearchPickerDialog({
    super.key,
    required this.song,
    required this.candidates,
    required this.onApply,
    required this.onClose,
  });

  final LibrarySong song;
  final List<InternetLyricsCandidate> candidates;
  final ValueChanged<InternetLyricsCandidate> onApply;
  final VoidCallback onClose;

  @override
  State<LyricsSearchPickerDialog> createState() =>
      _LyricsSearchPickerDialogState();
}

class _LyricsSearchPickerDialogState extends State<LyricsSearchPickerDialog> {
  late String _selectedSourceKey = widget.candidates.first.sourceKey;
  String? _expandedSourceKey;

  InternetLyricsCandidate get _selectedCandidate => widget.candidates
      .firstWhere((candidate) => candidate.sourceKey == _selectedSourceKey);

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return PopupDialog(
      overlayClassName: 'lyrics-search-picker-overlay',
      className: 'lyrics-search-picker-dialog ContentDialog',
      navClassName: 'lyrics-search-picker-nav',
      navLabel: i18n.t('song.chooseLyrics'),
      ariaLabel: i18n.t('song.chooseLyrics'),
      width: 860,
      height: 680,
      onClose: widget.onClose,
      navChildren: [
        Expanded(
          child: Text(
            i18n.t('song.chooseLyrics'),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: mobile ? 18 : 22,
              fontWeight: FontWeight.w600,
              height: mobile ? 25 / 18 : null,
            ),
          ),
        ),
      ],
      footer: Padding(
        padding:
            mobile
                ? const EdgeInsets.fromLTRB(12, 12, 12, 20)
                : const EdgeInsets.fromLTRB(28, 18, 28, 24),
        child: _SongDialogPickerFooterButtonTheme(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 10,
            children: [
              SmPlayerTextIconButton(
                label: i18n.t('common.cancel'),
                minWidth: 44,
                height: 40,
                horizontalPadding: 14,
                borderRadius: 10,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation.weight(720)],
                onPressed: widget.onClose,
              ),
              SmPlayerTextIconButton(
                label: i18n.t('song.useSelectedLyrics'),
                minWidth: 44,
                height: 40,
                horizontalPadding: 14,
                borderRadius: 10,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation.weight(720)],
                active: true,
                activeHoverSurface: PopupDialogColors.accentStrong,
                glassEnabled: false,
                onPressed: () {
                  widget.onApply(_selectedCandidate);
                },
              ),
            ],
          ),
        ),
      ),
      child: Padding(
        padding:
            mobile
                ? const EdgeInsets.fromLTRB(12, 0, 12, 0)
                : const EdgeInsets.fromLTRB(28, 0, 28, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              i18n.t('song.lyricsResultsSummary', {
                'count': widget.candidates.length,
                'title': widget.song.title,
              }),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            SizedBox(height: mobile ? 10 : 14),
            Expanded(
              child:
                  mobile
                      ? _buildCompactCandidates(context)
                      : _buildWideCandidates(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideCandidates(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 310,
          child: _LyricsCandidateList(
            candidates: widget.candidates,
            selectedSourceKey: _selectedSourceKey,
            onSelect: _selectCandidate,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _LyricsCandidateFullPreview(candidate: _selectedCandidate),
        ),
      ],
    );
  }

  Widget _buildCompactCandidates(BuildContext context) {
    return LayoutBuilder(
      builder:
          (context, constraints) => _LyricsCandidateList(
            candidates: widget.candidates,
            selectedSourceKey: _selectedSourceKey,
            expandedSourceKey: _expandedSourceKey,
            expandedPreviewMaxHeight: constraints.maxHeight * 0.5,
            onSelect: (candidate) {
              setState(() {
                _selectedSourceKey = candidate.sourceKey;
                _expandedSourceKey =
                    _expandedSourceKey == candidate.sourceKey
                        ? null
                        : candidate.sourceKey;
              });
            },
          ),
    );
  }

  void _selectCandidate(InternetLyricsCandidate candidate) {
    setState(() {
      _selectedSourceKey = candidate.sourceKey;
    });
  }
}

class _LyricsCandidateList extends StatefulWidget {
  const _LyricsCandidateList({
    required this.candidates,
    required this.selectedSourceKey,
    required this.onSelect,
    this.expandedSourceKey,
    this.expandedPreviewMaxHeight,
  });

  final List<InternetLyricsCandidate> candidates;
  final String selectedSourceKey;
  final String? expandedSourceKey;
  final double? expandedPreviewMaxHeight;
  final ValueChanged<InternetLyricsCandidate> onSelect;

  @override
  State<_LyricsCandidateList> createState() => _LyricsCandidateListState();
}

class _LyricsCandidateListState extends State<_LyricsCandidateList> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _controller,
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        itemCount: widget.candidates.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final candidate = widget.candidates[index];
          return _LyricsCandidateTile(
            candidate: candidate,
            selected: widget.selectedSourceKey == candidate.sourceKey,
            expanded: widget.expandedSourceKey == candidate.sourceKey,
            expandedPreviewMaxHeight: widget.expandedPreviewMaxHeight,
            onPressed: () {
              widget.onSelect(candidate);
            },
          );
        },
      ),
    );
  }
}

class _LyricsCandidateTile extends StatefulWidget {
  const _LyricsCandidateTile({
    required this.candidate,
    required this.selected,
    required this.expanded,
    required this.expandedPreviewMaxHeight,
    required this.onPressed,
  });

  final InternetLyricsCandidate candidate;
  final bool selected;
  final bool expanded;
  final double? expandedPreviewMaxHeight;
  final VoidCallback onPressed;

  @override
  State<_LyricsCandidateTile> createState() => _LyricsCandidateTileState();
}

class _LyricsCandidateTileState extends State<_LyricsCandidateTile> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final brightness = Theme.of(context).brightness;
    final interactive = _hovered || _focused;
    final selectedBackground =
        brightness == Brightness.dark
            ? GlobalUI.selectedBgColorNight
            : GlobalUI.selectedBgColorDay;
    final hoverBackground =
        brightness == Brightness.dark
            ? GlobalUI.hoverBgColorNight
            : GlobalUI.hoverBgColorDay;
    final selectedBorder = colors.accent.withValues(alpha: 0.56);
    final hoverBorder =
        brightness == Brightness.dark
            ? GlobalUI.hoverBorderColorNight
            : GlobalUI.hoverBorderColorDay;
    return Focus(
      onFocusChange: (focused) {
        setState(() {
          _focused = focused;
        });
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() {
            _hovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            _hovered = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  widget.selected
                      ? selectedBackground
                      : interactive
                      ? hoverBackground
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    widget.selected
                        ? selectedBorder
                        : interactive
                        ? hoverBorder
                        : colors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.candidate.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.candidate.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 13,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LyricsCandidateTypeBadge(
                      text:
                          widget.candidate.lyrics.isSynced
                              ? i18n.t('song.syncedLyrics')
                              : i18n.t('song.plainLyrics'),
                    ),
                    if (widget.selected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        FluentIcons.checkmark_20_regular,
                        size: 18,
                        color: colors.accentStrong,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _LyricsCandidateTextPreview(
                  candidate: widget.candidate,
                  expanded: widget.expanded,
                  maxExpandedHeight: widget.expandedPreviewMaxHeight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricsCandidateTextPreview extends StatefulWidget {
  const _LyricsCandidateTextPreview({
    required this.candidate,
    required this.expanded,
    required this.maxExpandedHeight,
  });

  final InternetLyricsCandidate candidate;
  final bool expanded;
  final double? maxExpandedHeight;

  @override
  State<_LyricsCandidateTextPreview> createState() =>
      _LyricsCandidateTextPreviewState();
}

class _LyricsCandidateTextPreviewState
    extends State<_LyricsCandidateTextPreview> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(_LyricsCandidateTextPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.expanded && widget.expanded && _controller.hasClients) {
      _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final text = _lyricsCandidateDisplayText(widget.candidate);
    final style = TextStyle(color: colors.text, fontSize: 13, height: 1.55);
    if (!widget.expanded || widget.maxExpandedHeight == null) {
      return Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxExpandedHeight!),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          padding: const EdgeInsets.only(right: 10),
          child: Text(widget.candidate.lyrics.rawText, style: style),
        ),
      ),
    );
  }
}

class _LyricsCandidateFullPreview extends StatefulWidget {
  const _LyricsCandidateFullPreview({required this.candidate});

  final InternetLyricsCandidate candidate;

  @override
  State<_LyricsCandidateFullPreview> createState() =>
      _LyricsCandidateFullPreviewState();
}

class _LyricsCandidateFullPreviewState
    extends State<_LyricsCandidateFullPreview> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(_LyricsCandidateFullPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate.sourceKey != widget.candidate.sourceKey &&
        _controller.hasClients) {
      _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            widget.candidate.lyrics.rawText,
            style: TextStyle(color: colors.text, fontSize: 14, height: 1.65),
          ),
        ),
      ),
    );
  }
}

class _LyricsCandidateTypeBadge extends StatelessWidget {
  const _LyricsCandidateTypeBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.accentStrong,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

String _lyricsCandidateDisplayText(InternetLyricsCandidate candidate) {
  return candidate.lyrics.lines.map((line) => line.text).join('\n');
}
