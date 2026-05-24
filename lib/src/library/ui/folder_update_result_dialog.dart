import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'folder_update_result_sections.dart';
import 'folder_update_result_tab.dart';
import 'folder_update_result_tab_button.dart';
import 'local_folder_model.dart';
import 'local_page_quick_jump.dart';

class FolderUpdateResultDialog extends StatefulWidget {
  const FolderUpdateResultDialog({
    super.key,
    required this.folder,
    required this.result,
    required this.songs,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlay,
    required this.onClose,
  });

  final FolderNode folder;
  final LocalFolderRefreshResult result;
  final List<LibrarySong> songs;
  final int? selectedTrackId;
  final bool isPlaying;
  final ValueChanged<int> onPlay;
  final VoidCallback onClose;

  @override
  State<FolderUpdateResultDialog> createState() =>
      FolderUpdateResultDialogState();
}

class FolderUpdateResultDialogState extends State<FolderUpdateResultDialog> {
  late FolderUpdateResultTab _activeTab;

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
          icon: FluentIcons.people_20_regular,
        ),
    ];

    return ColoredBox(
      color: const Color(0x3d181e26),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 760),
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xfafafcff),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x80b9c3d2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47342d3c),
                  blurRadius: 80,
                  offset: Offset(0, 26),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FolderUpdateHeader(title: title, onClose: widget.onClose),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    child:
                        !widget.result.hasChanges
                            ? Text(
                              i18n.t('local.refreshNoChange'),
                              style: const TextStyle(
                                color: LocalPageColors.textMuted,
                              ),
                            )
                            : Column(
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
                                Expanded(child: _buildActiveTabContent()),
                              ],
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

  Widget _buildActiveTabContent() {
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
      ),
      FolderUpdateResultTab.removed => FolderUpdateResultFileSection(
        folderPath: widget.folder.path,
        paths: widget.result.filesRemoved,
        playable: false,
        songsByPathKey: songsByPathKey,
        selectedTrackId: widget.selectedTrackId,
        isPlaying: widget.isPlaying,
        onPlay: widget.onPlay,
      ),
      FolderUpdateResultTab.moved => FolderUpdateResultFileSection(
        folderPath: widget.folder.path,
        paths: widget.result.filesMoved,
        playable: true,
        songsByPathKey: songsByPathKey,
        selectedTrackId: widget.selectedTrackId,
        isPlaying: widget.isPlaying,
        onPlay: widget.onPlay,
      ),
      FolderUpdateResultTab.artists => FolderUpdateResultArtistSection(
        result: widget.result,
      ),
    };
  }
}

class _FolderUpdateHeader extends StatelessWidget {
  const _FolderUpdateHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
        child: Row(
          children: [
            const SizedBox(width: 42),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LocalPageColors.textStrong,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
            SizedBox(
              width: 42,
              height: 40,
              child: IconButton(
                tooltip: context.smPlayerI18n.t('common.close'),
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xebffffff),
                  foregroundColor: LocalPageColors.commandText,
                  side: const BorderSide(color: Color(0x9ebec8d6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(FluentIcons.dismiss_20_regular, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
