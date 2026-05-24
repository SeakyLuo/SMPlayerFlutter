import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'default_album_artwork.dart';
import 'folder_update_result_file_title.dart';
import 'local_folder_model.dart';
import 'local_page_quick_jump.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xb8ffffff),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x9ebec8d6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        itemExtent: 66,
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
    );
  }
}

class FolderUpdateResultArtwork extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child:
                song.thumbnailPath.isEmpty
                    ? const DefaultAlbumArtwork(logoOpacity: 0.9)
                    : Image.file(
                      File(song.thumbnailPath),
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, _, _) =>
                              const DefaultAlbumArtwork(logoOpacity: 0.9),
                    ),
          ),
          if (current)
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xb81e2228),
              ),
              child: Icon(
                isPlaying
                    ? FluentIcons.pause_16_filled
                    : FluentIcons.play_16_filled,
                color: Colors.white,
                size: 16,
              ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(21),
                onTap: onPlay,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
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
  const FolderUpdateResultArtistSection({super.key, required this.result});

  final LocalFolderRefreshResult result;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final separator = i18n.t('common.artistSeparator');
    final items = [
      ...result.artistSplitsApplied,
      ...result.artistSplitSuggestions,
      ...result.artistMergeSuggestions,
    ];

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:
                index.isEven
                    ? const Color(0xd1f6f9fd)
                    : const Color(0xb8ffffff),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LocalPageColors.textStrong,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.artist} -> ${item.artists.join(separator)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LocalPageColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
