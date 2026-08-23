import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'folder_update_result_sections.dart';
import 'folder_update_result_tab.dart';
import 'folder_update_result_tab_button.dart';
import 'local_folder_model.dart';
import 'popup_dialog.dart';

class FolderUpdateResultDialog extends StatefulWidget {
  const FolderUpdateResultDialog({
    super.key,
    required this.folder,
    required this.result,
    required this.songs,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlay,
    required this.onOpenSongMenu,
    required this.onApplyArtistSplits,
    required this.onDismissArtistSplitSuggestions,
    required this.onClose,
  });

  final FolderNode folder;
  final LocalFolderRefreshResult result;
  final List<LibrarySong> songs;
  final int? selectedTrackId;
  final bool isPlaying;
  final ValueChanged<int> onPlay;
  final void Function(LibrarySong song, Offset position) onOpenSongMenu;
  final FutureOr<void> Function(List<ArtistSplitResultItem> splits)
  onApplyArtistSplits;
  final VoidCallback onDismissArtistSplitSuggestions;
  final VoidCallback onClose;

  @override
  State<FolderUpdateResultDialog> createState() =>
      FolderUpdateResultDialogState();
}

class FolderUpdateResultDialogState extends State<FolderUpdateResultDialog> {
  late FolderUpdateResultTab _activeTab;
  var _artistSplitsApplying = false;

  @override
  void initState() {
    super.initState();
    _activeTab = _initialTab();
  }

  FolderUpdateResultTab _initialTab() {
    if (_artistUpdateCount > 0) {
      return FolderUpdateResultTab.artists;
    }
    if (widget.result.filesAdded.isNotEmpty) {
      return FolderUpdateResultTab.added;
    }
    if (widget.result.filesRemoved.isNotEmpty) {
      return FolderUpdateResultTab.removed;
    }
    if (widget.result.filesMoved.isNotEmpty) {
      return FolderUpdateResultTab.moved;
    }
    return FolderUpdateResultTab.added;
  }

  int get _artistUpdateCount =>
      widget.result.artistSplitsApplied.length +
      widget.result.artistSplitSuggestions.length +
      widget.result.artistMergeSuggestions.length;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final title = i18n.t('local.updateResultOfFolder', {
      'name':
          widget.folder.name.isEmpty
              ? i18n.t('local.libraryRoot')
              : widget.folder.name,
    });
    final tabs = [
      if (widget.result.filesAdded.isNotEmpty)
        FolderUpdateResultTabItem(
          tab: FolderUpdateResultTab.added,
          label: i18n.t('local.refreshAddedTab'),
          count: widget.result.filesAdded.length,
          icon: FluentIcons.music_note_2_20_regular,
        ),
      if (widget.result.filesRemoved.isNotEmpty)
        FolderUpdateResultTabItem(
          tab: FolderUpdateResultTab.removed,
          label: i18n.t('local.refreshRemovedTab'),
          count: widget.result.filesRemoved.length,
          icon: FluentIcons.music_note_2_20_regular,
        ),
      if (widget.result.filesMoved.isNotEmpty)
        FolderUpdateResultTabItem(
          tab: FolderUpdateResultTab.moved,
          label: i18n.t('local.refreshMovedTab'),
          count: widget.result.filesMoved.length,
          icon: FluentIcons.music_note_2_20_regular,
        ),
      if (_artistUpdateCount > 0)
        FolderUpdateResultTabItem(
          tab: FolderUpdateResultTab.artists,
          label: i18n.t('local.refreshArtistUpdatesTab'),
          count: _artistUpdateCount,
          icon: FluentIcons.people_24_regular,
        ),
    ];

    return PopupDialog(
      overlayClassName: 'folder-update-result-popup-overlay',
      className: 'folder-update-result-dialog ContentDialog',
      navClassName: 'folder-update-result-nav',
      navLabel: title,
      ariaLabel: title,
      width: 780,
      height: 760,
      onClose: widget.onClose,
      navChildren: [Expanded(child: _FolderUpdateResultTitle(title))],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in tabs) ...[
                    FolderUpdateResultTabButton(
                      item: tab,
                      selected: tab.tab == _activeTab,
                      onPressed: () {
                        setState(() {
                          _activeTab = tab.tab;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder:
                    (context, constraints) =>
                        _buildActiveTabPane(maxHeight: constraints.maxHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabPane({required double maxHeight}) {
    return _buildActiveTabContent(maxHeight: maxHeight);
  }

  Widget _buildActiveTabContent({required double maxHeight}) {
    final songsByPathKey = {
      for (final song in widget.songs)
        normalizePath(song.path).toLowerCase(): song,
    };
    return switch (_activeTab) {
      FolderUpdateResultTab.added => FolderUpdateResultFileSection(
        folderPath: widget.folder.path,
        paths: widget.result.filesAdded,
        playable: true,
        songsByPathKey: songsByPathKey,
        selectedTrackId: widget.selectedTrackId,
        isPlaying: widget.isPlaying,
        onPlay: widget.onPlay,
        onOpenSongMenu: widget.onOpenSongMenu,
        maxHeight: maxHeight,
      ),
      FolderUpdateResultTab.removed => FolderUpdateResultFileSection(
        folderPath: widget.folder.path,
        paths: widget.result.filesRemoved,
        playable: false,
        songsByPathKey: songsByPathKey,
        selectedTrackId: widget.selectedTrackId,
        isPlaying: widget.isPlaying,
        onPlay: widget.onPlay,
        onOpenSongMenu: widget.onOpenSongMenu,
        maxHeight: maxHeight,
      ),
      FolderUpdateResultTab.moved => FolderUpdateResultFileSection(
        folderPath: widget.folder.path,
        paths: widget.result.filesMoved,
        playable: true,
        songsByPathKey: songsByPathKey,
        selectedTrackId: widget.selectedTrackId,
        isPlaying: widget.isPlaying,
        onPlay: widget.onPlay,
        onOpenSongMenu: widget.onOpenSongMenu,
        maxHeight: maxHeight,
      ),
      FolderUpdateResultTab.artists => FolderUpdateResultArtistSection(
        result: widget.result,
        applying: _artistSplitsApplying,
        artworkPathBySongId: {
          for (final song in widget.songs) song.id: song.thumbnailPath,
        },
        onApply: _applyArtistSplits,
        onClose: widget.onDismissArtistSplitSuggestions,
      ),
    };
  }

  Future<void> _applyArtistSplits(List<ArtistSplitResultItem> splits) async {
    setState(() {
      _artistSplitsApplying = true;
    });
    try {
      await widget.onApplyArtistSplits(splits);
    } finally {
      if (mounted) {
        setState(() {
          _artistSplitsApplying = false;
        });
      }
    }
  }
}

class _FolderUpdateResultTitle extends StatelessWidget {
  const _FolderUpdateResultTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
    );
  }
}
