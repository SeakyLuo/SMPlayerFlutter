import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/settings/artist_split_review_panel.dart';

import '../data/library_models.dart';
import 'default_album_artwork.dart';
import 'folder_update_result_file_title.dart';
import 'local_folder_model.dart';
import 'local_page_quick_jump.dart';
import 'song_artwork.dart';

const _folderUpdateResultRowHeight = 66.0;
const _folderUpdateResultMaxVisibleRows = 14;

class FolderUpdateResultFileSection extends StatelessWidget {
  const FolderUpdateResultFileSection({
    super.key,
    required this.folderPath,
    required this.paths,
    required this.playable,
    required this.songsByPathKey,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlay,
  });

  final String folderPath;
  final List<String> paths;
  final bool playable;
  final Map<String, LibrarySong> songsByPathKey;
  final int? selectedTrackId;
  final bool isPlaying;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = getUpdateResultFileItems(paths, folderPath);
    final visibleRows =
        items.length > _folderUpdateResultMaxVisibleRows
            ? _folderUpdateResultMaxVisibleRows
            : items.length;
    return SizedBox(
      height: visibleRows * _folderUpdateResultRowHeight,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xb8ffffff),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x9ebec8d6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.builder(
          itemExtent: _folderUpdateResultRowHeight,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final path = item.path;
            final title = item.title;
            final showsFullPath = title == path;
            final song =
                playable
                    ? songsByPathKey[normalizePath(path).toLowerCase()]
                    : null;
            final current = song != null && song.id == selectedTrackId;
            return _FolderUpdateResultRow(
              title: title,
              fullPath: showsFullPath,
              first: index == 0,
              odd: index.isEven,
              song: song,
              current: current,
              isPlaying: current && isPlaying,
              onPlay: song == null ? null : () => onPlay(song.id),
            );
          },
        ),
      ),
    );
  }
}

class FolderUpdateResultArtwork extends StatefulWidget {
  const FolderUpdateResultArtwork({
    super.key,
    required this.song,
    required this.current,
    required this.isPlaying,
    required this.onPlay,
  });

  final LibrarySong song;
  final bool current;
  final bool isPlaying;
  final VoidCallback onPlay;

  @override
  State<FolderUpdateResultArtwork> createState() =>
      _FolderUpdateResultArtworkState();
}

class _FolderUpdateResultArtworkState extends State<FolderUpdateResultArtwork> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final showPlayOverlay = _hovered || _focused;
    return SizedBox(
      width: 42,
      height: 42,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SongArtwork(
                artworkPath: widget.song.thumbnailPath,
                fallback: const DefaultAlbumArtwork(logoOpacity: 0.9),
              ),
            ),
            if (widget.current && !showPlayOverlay)
              _FolderUpdatePlayingWave(active: widget.isPlaying),
            IgnorePointer(
              ignoring: !showPlayOverlay,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: showPlayOverlay ? 1 : 0,
                child: SizedBox.square(
                  dimension: 34,
                  child: Material(
                    color: const Color(0xb81e2228),
                    shape: const CircleBorder(),
                    elevation: 2,
                    shadowColor: const Color(0x47141e28),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onFocusChange:
                          (focused) => setState(() => _focused = focused),
                      onTap: widget.onPlay,
                      child: Icon(
                        widget.isPlaying
                            ? FluentIcons.pause_16_filled
                            : FluentIcons.play_16_filled,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderUpdatePlayingWave extends StatefulWidget {
  const _FolderUpdatePlayingWave({required this.active});

  final bool active;

  @override
  State<_FolderUpdatePlayingWave> createState() =>
      _FolderUpdatePlayingWaveState();
}

class _FolderUpdatePlayingWaveState extends State<_FolderUpdatePlayingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_FolderUpdatePlayingWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) {
      return;
    }
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xb81e2228),
        boxShadow: [
          BoxShadow(
            color: Color(0x47141e28),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _FolderUpdateWaveBar(height: _height(7, 0)),
              const SizedBox(width: 2),
              _FolderUpdateWaveBar(height: _height(12, 0.16)),
              const SizedBox(width: 2),
              _FolderUpdateWaveBar(height: _height(15, 0.31)),
              const SizedBox(width: 2),
              _FolderUpdateWaveBar(height: _height(9, 0.46)),
            ],
          );
        },
      ),
    );
  }

  double _height(double base, double delay) {
    if (!widget.active) {
      return base;
    }
    final value = (_controller.value + delay) % 1;
    final scale = value < 0.5 ? value * 2 : (1 - value) * 2;
    return 5 + (15 - 5) * scale;
  }
}

class _FolderUpdateWaveBar extends StatelessWidget {
  const _FolderUpdateWaveBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
    );
  }
}

class _FolderUpdateResultRow extends StatelessWidget {
  const _FolderUpdateResultRow({
    required this.title,
    required this.fullPath,
    required this.first,
    required this.odd,
    required this.song,
    required this.current,
    required this.isPlaying,
    required this.onPlay,
  });

  final String title;
  final bool fullPath;
  final bool first;
  final bool odd;
  final LibrarySong? song;
  final bool current;
  final bool isPlaying;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final playable = song != null;
    final background =
        playable
            ? const Color(0xb8ffffff)
            : odd
            ? const Color(0xd1f6f9fd)
            : const Color(0xb8ffffff);
    return Material(
      color: background,
      child: InkWell(
        onTap: onPlay,
        child: Container(
          decoration: BoxDecoration(
            border:
                first
                    ? null
                    : const Border(top: BorderSide(color: Color(0x85bec8d6))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              if (playable) ...[
                FolderUpdateResultArtwork(
                  song: song!,
                  current: current,
                  isPlaying: isPlaying,
                  onPlay: onPlay!,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: fullPath ? 2 : 1,
                  overflow:
                      fullPath ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        playable
                            ? LocalPageColors.textStrong
                            : LocalPageColors.textMuted,
                    fontSize: fullPath ? 13 : 16,
                    fontWeight: FontWeight.w500,
                    height: fullPath ? 1.25 : null,
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

class FolderUpdateResultArtistSection extends StatelessWidget {
  const FolderUpdateResultArtistSection({
    super.key,
    required this.result,
    required this.applying,
    required this.artworkPathBySongId,
    required this.onApply,
    required this.onClose,
  });

  final LocalFolderRefreshResult result;
  final bool applying;
  final Map<int, String> artworkPathBySongId;
  final FutureOr<void> Function(List<ArtistSplitResultItem> splits) onApply;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ArtistSplitReviewPanel(
        directSplits: result.artistSplitsApplied,
        possibleSplits: result.artistSplitSuggestions,
        mergeSuggestions: result.artistMergeSuggestions,
        applying: applying,
        artworkPathBySongId: artworkPathBySongId,
        embeddedInFolderUpdateResult: true,
        onApply: onApply,
        onClose: onClose,
      ),
    );
  }
}
