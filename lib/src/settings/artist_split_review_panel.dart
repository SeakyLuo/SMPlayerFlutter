import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';

part 'artist_split_review_widgets.dart';
part 'artist_split_review_editor.dart';

const _maxArtistCells = 6;

List<ArtistSplitResultItem> _splitItems(
  ArtistSplitAnalysisResult result, {
  required bool appliedDirectSplits,
}) {
  return [
    if (!appliedDirectSplits) ...result.directSplits,
    ...result.possibleSplits,
    ...result.mergeSuggestions,
  ];
}

class ArtistSplitReviewPanel extends StatefulWidget {
  const ArtistSplitReviewPanel({
    super.key,
    required this.directSplits,
    required this.possibleSplits,
    required this.mergeSuggestions,
    required this.applying,
    required this.onClose,
    required this.onApply,
    this.appliedDirectSplits = false,
    this.artworkPathBySongId = const {},
    this.embeddedInFolderUpdateResult = false,
  });

  final List<ArtistSplitResultItem> directSplits;
  final List<ArtistSplitResultItem> possibleSplits;
  final List<ArtistSplitResultItem> mergeSuggestions;
  final bool applying;
  final VoidCallback onClose;
  final FutureOr<void> Function(List<ArtistSplitResultItem> splits) onApply;
  final bool appliedDirectSplits;
  final Map<int, String> artworkPathBySongId;
  final bool embeddedInFolderUpdateResult;

  @override
  State<ArtistSplitReviewPanel> createState() => _ArtistSplitReviewPanelState();
}

class _ArtistSplitReviewPanelState extends State<ArtistSplitReviewPanel> {
  late final Map<int, List<String>> _artistEdits;
  late final Set<int> _selectedSongIds;
  var _directExpanded = true;
  var _possibleExpanded = true;
  var _mergeExpanded = true;
  var _applying = false;

  @override
  void initState() {
    super.initState();
    _artistEdits = {
      for (final item in [
        ...widget.mergeSuggestions,
        ...widget.directSplits,
        ...widget.possibleSplits,
      ])
        item.songId: item.artists,
    };
    _selectedSongIds = {
      if (!widget.appliedDirectSplits)
        for (final item in widget.directSplits) item.songId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final result = ArtistSplitAnalysisResult(
      directSplits: widget.directSplits,
      possibleSplits: widget.possibleSplits,
      mergeSuggestions: widget.mergeSuggestions,
    );
    final selectedSplits = _selectedSplits(result);

    final applying = widget.applying || _applying;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth <= 720;
        final compact = constraints.maxWidth <= 520;
        final horizontalPadding =
            widget.embeddedInFolderUpdateResult ? 0.0 : (mobile ? 12.0 : 28.0);
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  0,
                ),
                child: ClipRect(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      right: mobile ? 0 : 12,
                      bottom: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.directSplits.isNotEmpty)
                          _ArtistSplitGroup(
                            title:
                                widget.appliedDirectSplits
                                    ? i18n.t(
                                      'local.refreshArtistSplitsAppliedTitle',
                                    )
                                    : i18n.t('local.directArtistSplitsTitle'),
                            count: widget.directSplits.length,
                            items: widget.directSplits,
                            selectedSongIds: _selectedSongIds,
                            artistEdits: _artistEdits,
                            disabled: widget.appliedDirectSplits,
                            expanded: _directExpanded,
                            compact: compact,
                            artworkPathBySongId: widget.artworkPathBySongId,
                            onToggleExpanded:
                                () => setState(() {
                                  _directExpanded = !_directExpanded;
                                }),
                            onToggle: _toggleSplit,
                            onSetGroupSelection: _setGroupSelection,
                            onUpdateArtists: _updateArtists,
                          ),
                        if (widget.possibleSplits.isNotEmpty)
                          _ArtistSplitGroup(
                            title: i18n.t(
                              'local.refreshArtistSplitSuggestionsTitle',
                            ),
                            count: widget.possibleSplits.length,
                            items: widget.possibleSplits,
                            selectedSongIds: _selectedSongIds,
                            artistEdits: _artistEdits,
                            expanded: _possibleExpanded,
                            compact: compact,
                            artworkPathBySongId: widget.artworkPathBySongId,
                            onToggleExpanded:
                                () => setState(() {
                                  _possibleExpanded = !_possibleExpanded;
                                }),
                            onToggle: _toggleSplit,
                            onSetGroupSelection: _setGroupSelection,
                            onUpdateArtists: _updateArtists,
                          ),
                        if (widget.mergeSuggestions.isNotEmpty)
                          _ArtistSplitGroup(
                            title: i18n.t('local.artistMergeSuggestionsTitle'),
                            count: widget.mergeSuggestions.length,
                            items: widget.mergeSuggestions,
                            selectedSongIds: _selectedSongIds,
                            artistEdits: _artistEdits,
                            expanded: _mergeExpanded,
                            compact: compact,
                            artworkPathBySongId: widget.artworkPathBySongId,
                            variant: _ArtistSplitReviewVariant.merge,
                            onToggleExpanded:
                                () => setState(() {
                                  _mergeExpanded = !_mergeExpanded;
                                }),
                            onToggle: _toggleSplit,
                            onSetGroupSelection: _setGroupSelection,
                            onUpdateArtists: _updateArtists,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding:
                  widget.embeddedInFolderUpdateResult
                      ? EdgeInsets.zero
                      : mobile
                      ? const EdgeInsets.fromLTRB(12, 12, 12, 20)
                      : const EdgeInsets.fromLTRB(28, 9, 28, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ArtistSplitFooterButton(
                    label: i18n.t('local.keepArtistSplits'),
                    onPressed: applying ? null : widget.onClose,
                  ),
                  const SizedBox(width: 10),
                  _ArtistSplitFooterButton(
                    label:
                        applying
                            ? i18n.t('local.applyingArtistSplits')
                            : i18n.t('local.applySelectedArtistSplits', {
                              'count': selectedSplits.length,
                            }),
                    primary: true,
                    loading: applying,
                    onPressed:
                        applying || selectedSplits.isEmpty
                            ? null
                            : () => _applySelectedSplits(selectedSplits),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<ArtistSplitResultItem> _selectedSplits(
    ArtistSplitAnalysisResult result,
  ) {
    return [
      for (final item in _splitItems(
        result,
        appliedDirectSplits: widget.appliedDirectSplits,
      ))
        if (_selectedSongIds.contains(item.songId))
          _editedSplitItem(item, _artistEdits[item.songId] ?? item.artists),
    ];
  }

  ArtistSplitResultItem _editedSplitItem(
    ArtistSplitResultItem item,
    List<String> artists,
  ) {
    final editedArtists = _getEditedArtists(artists);
    if (_sameArtists(item.artists, editedArtists)) {
      return item;
    }
    return ArtistSplitResultItem(
      songId: item.songId,
      title: item.title,
      artist: item.artist,
      artists: editedArtists,
    );
  }

  void _toggleSplit(int songId) {
    setState(() {
      if (!_selectedSongIds.add(songId)) {
        _selectedSongIds.remove(songId);
      }
    });
  }

  void _setGroupSelection(List<ArtistSplitResultItem> items, bool selected) {
    setState(() {
      for (final item in items) {
        if (selected) {
          _selectedSongIds.add(item.songId);
        } else {
          _selectedSongIds.remove(item.songId);
        }
      }
    });
  }

  void _updateArtists(int songId, List<String> artists) {
    setState(() {
      _artistEdits[songId] = artists;
    });
  }

  Future<void> _applySelectedSplits(
    List<ArtistSplitResultItem> selectedSplits,
  ) async {
    setState(() {
      _applying = true;
    });
    try {
      await widget.onApply(selectedSplits);
    } finally {
      if (mounted) {
        setState(() {
          _applying = false;
        });
      }
    }
  }
}

class _ArtistSplitFooterButton extends StatelessWidget {
  const _ArtistSplitFooterButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final enabled = onPressed != null;
    final background =
        primary
            ? enabled
                ? colors.accent
                : const Color(0xc7e6ebf3)
            : PopupDialogColors.buttonSurface;
    final foreground =
        primary
            ? enabled
                ? Colors.white
                : const Color(0xb85e6773)
            : PopupDialogColors.text;
    final border =
        primary
            ? enabled
                ? colors.accent.withValues(alpha: 0.52)
                : const Color(0x619ba6b6)
            : PopupDialogColors.buttonBorder;

    return TextButton(
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: const Size(88, 40),
        maximumSize: const Size(double.infinity, 40),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        backgroundColor: background,
        disabledBackgroundColor: background,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: border),
        shadowColor:
            primary && enabled
                ? colors.accent.withValues(alpha: 0.22)
                : const Color(0x0f28374c),
        elevation: primary && enabled ? 2 : 1,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (primary) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return const Color(0xfaf7fafe);
        }),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.42),
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
