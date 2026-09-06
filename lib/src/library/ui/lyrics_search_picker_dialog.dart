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
            onSelect: _selectCandidate,
            onToggleExpanded: (candidate) {
              setState(() {
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
    this.onToggleExpanded,
  });

  final List<InternetLyricsCandidate> candidates;
  final String selectedSourceKey;
  final String? expandedSourceKey;
  final double? expandedPreviewMaxHeight;
  final ValueChanged<InternetLyricsCandidate> onSelect;
  final ValueChanged<InternetLyricsCandidate>? onToggleExpanded;

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
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return _SongDialogScrollbarHost(
      controller: _controller,
      right: mobile ? -14 : -8,
      bottom: 8,
      trackWidth: mobile ? 16 : 9,
      normalThumbLeft: mobile ? 5 : 2,
      normalThumbRight: mobile ? 6 : 2,
      hoverThumbLeft: mobile ? 4 : 1,
      hoverThumbRight: mobile ? 5 : 1,
      frameKey: const ValueKey('LyricsSearchPicker.ListFrame'),
      positionKey: const ValueKey('LyricsSearchPicker.Scrollbar.Position'),
      thumbKey: const ValueKey('LyricsSearchPicker.Scrollbar.Thumb'),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.separated(
          controller: _controller,
          padding: EdgeInsets.only(right: mobile ? 0 : 8, bottom: 8),
          itemCount: widget.candidates.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final candidate = widget.candidates[index];
            return _LyricsCandidateTile(
              candidate: candidate,
              selected: widget.selectedSourceKey == candidate.sourceKey,
              expanded: widget.expandedSourceKey == candidate.sourceKey,
              collapsedPreviewMaxLines: mobile ? 5 : 3,
              expandedPreviewMaxHeight: widget.expandedPreviewMaxHeight,
              onPressed: () {
                widget.onSelect(candidate);
              },
              onToggleExpanded:
                  widget.onToggleExpanded == null
                      ? null
                      : () => widget.onToggleExpanded!(candidate),
            );
          },
        ),
      ),
    );
  }
}

class _LyricsCandidateTile extends StatefulWidget {
  const _LyricsCandidateTile({
    required this.candidate,
    required this.selected,
    required this.expanded,
    required this.collapsedPreviewMaxLines,
    required this.expandedPreviewMaxHeight,
    required this.onPressed,
    required this.onToggleExpanded,
  });

  final InternetLyricsCandidate candidate;
  final bool selected;
  final bool expanded;
  final int collapsedPreviewMaxLines;
  final double? expandedPreviewMaxHeight;
  final VoidCallback onPressed;
  final VoidCallback? onToggleExpanded;

  @override
  State<_LyricsCandidateTile> createState() => _LyricsCandidateTileState();
}

class _LyricsCandidateTileState extends State<_LyricsCandidateTile> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final brightness = Theme.of(context).brightness;
    final interactive = _focused;
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
    final cardBackground =
        widget.selected
            ? selectedBackground
            : interactive
            ? hoverBackground
            : Colors.transparent;
    final previewOverlayColor =
        cardBackground == Colors.transparent
            ? colors.surface
            : Color.alphaBlend(cardBackground, colors.surface);
    return Focus(
      onFocusChange: (focused) {
        setState(() {
          _focused = focused;
        });
      },
      onKeyEvent: (node, event) {
        if (node.hasPrimaryFocus &&
            event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding:
                widget.expanded && widget.onToggleExpanded != null
                    ? const EdgeInsets.fromLTRB(12, 12, 12, 9)
                    : const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBackground,
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
                            widget.candidate.album.isEmpty
                                ? widget.candidate.artist
                                : '${widget.candidate.artist} - ${widget.candidate.album}',
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
                    SizedBox.square(
                      dimension: 18,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: widget.selected ? 1 : 0,
                        child: Icon(
                          FluentIcons.checkmark_20_regular,
                          size: 18,
                          color: colors.accentStrong,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!widget.expanded && widget.onToggleExpanded != null)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _LyricsCandidateTextPreview(
                        candidate: widget.candidate,
                        expanded: false,
                        collapsedMaxLines: widget.collapsedPreviewMaxLines,
                        maxExpandedHeight: widget.expandedPreviewMaxHeight,
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -4,
                        child: _LyricsCandidateExpandOverlay(
                          color: previewOverlayColor,
                          onPressed: widget.onToggleExpanded!,
                        ),
                      ),
                    ],
                  )
                else
                  _LyricsCandidateTextPreview(
                    candidate: widget.candidate,
                    expanded: widget.expanded,
                    collapsedMaxLines: widget.collapsedPreviewMaxLines,
                    maxExpandedHeight: widget.expandedPreviewMaxHeight,
                  ),
                if (widget.expanded && widget.onToggleExpanded != null) ...[
                  const SizedBox(height: 3),
                  Align(
                    alignment: Alignment.center,
                    child: _LyricsCandidateExpandButton(
                      expanded: widget.expanded,
                      onPressed: widget.onToggleExpanded!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricsCandidateExpandOverlay extends StatelessWidget {
  const _LyricsCandidateExpandOverlay({
    required this.color,
    required this.onPressed,
  });

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.72),
            color.withValues(alpha: 0.88),
            color.withValues(alpha: 0.72),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.28, 0.5, 0.72, 1],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _LyricsCandidateExpandButton(
          expanded: false,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _LyricsCandidateExpandButton extends StatelessWidget {
  const _LyricsCandidateExpandButton({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final label = i18n.t(
      expanded ? 'song.collapseLyrics' : 'song.expandLyrics',
    );
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox(
          width: 112,
          height: 32,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.textMuted,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded
                      ? FluentIcons.chevron_up_24_regular
                      : FluentIcons.chevron_down_24_regular,
                  size: 16,
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
    required this.collapsedMaxLines,
    required this.maxExpandedHeight,
  });

  final InternetLyricsCandidate candidate;
  final bool expanded;
  final int collapsedMaxLines;
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
        maxLines: widget.collapsedMaxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxExpandedHeight!),
      child: SmPlayerAutoHideScrollbar(
        controller: _controller,
        showOnHover: true,
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
      child: SmPlayerAutoHideScrollbar(
        controller: _controller,
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

String _lyricsCandidateDisplayText(InternetLyricsCandidate candidate) {
  return candidate.lyrics.lines.map((line) => line.text).join('\n');
}
