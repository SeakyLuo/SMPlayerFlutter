import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_queue.dart';

class ImmersiveModeMultiSelectCommandBar extends StatelessWidget {
  const ImmersiveModeMultiSelectCommandBar({
    super.key,
    required this.i18n,
    required this.songs,
    required this.songIds,
    required this.playlists,
    required this.defaultNewPlaylistName,
    required this.hideMultiSelectCommandBarAfterOperation,
    required this.selection,
    required this.currentQueueSongIds,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.onPlay,
    required this.onReplaceQueue,
    required this.onRemoveSelectedQueueIndexes,
    required this.onSelectionChanged,
  });

  final SmPlayerI18n i18n;
  final List<LibrarySong> songs;
  final List<int> songIds;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final String defaultNewPlaylistName;
  final bool hideMultiSelectCommandBarAfterOperation;
  final PageSelectionController<int> selection;
  final List<int> Function() currentQueueSongIds;
  final Future<void> Function(List<int> songIds, bool favorite)
  onToggleFavorite;
  final Future<void> Function(int playlistId, List<int> songIds)
  onAddToPlaylist;
  final ValueChanged<List<int>> onPlay;
  final ValueChanged<List<int>> onReplaceQueue;
  final void Function(List<int> selectedIndexes, List<int> nextSongIds)
  onRemoveSelectedQueueIndexes;
  final VoidCallback onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    List<int> selectedSongIds() {
      return [
        for (var index = 0; index < songIds.length; index += 1)
          if (selection.selectedItems.contains(index)) songIds[index],
      ];
    }

    List<int> selectedUnfavoritedSongIds() {
      return [
        for (var index = 0; index < songs.length; index += 1)
          if (selection.selectedItems.contains(index) && !songs[index].favorite)
            songs[index].id,
      ];
    }

    bool selectedSongsHaveUnfavorited() {
      for (var index = 0; index < songs.length; index += 1) {
        if (selection.selectedItems.contains(index) && !songs[index].favorite) {
          return true;
        }
      }
      return false;
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 64,
      child: MultiSelectCommandBar(
        visible: selection.multiSelect,
        selectedCount: selection.selectedItems.length,
        playlists: playlists,
        addToSongIds: selectedSongIds(),
        nowPlayingSongIds: songIds,
        defaultPlaylistName: defaultNewPlaylistName,
        currentPlaylistName: i18n.t('common.nowPlaying'),
        includeFavoritesInAddTo: selectedSongsHaveUnfavorited(),
        removeLabel: i18n.t('nowPlaying.remove'),
        hideAfterOperation: hideMultiSelectCommandBarAfterOperation,
        onToggleFavorite: () {
          final selectedIds = selectedUnfavoritedSongIds();
          onToggleFavorite(selectedIds, true);
          final songsById = {for (final song in songs) song.id: song};
          showUndoableNotification(
            context: context,
            i18n: i18n,
            message: songsAddedUndoMessage(
              i18n: i18n,
              songIds: selectedIds,
              songsById: songsById,
              target: i18n.t('common.myFavorites'),
            ),
            onUndo: () => onToggleFavorite(selectedIds, false),
          );
        },
        onAddToPlaylist: (playlistId) {
          onAddToPlaylist(playlistId, selectedSongIds());
          selection.hideAfterOperation(hideMultiSelectCommandBarAfterOperation);
          onSelectionChanged();
        },
        onPlay: () {
          onPlay(selectedSongIds());
          selection.hideAfterOperation(hideMultiSelectCommandBarAfterOperation);
          onSelectionChanged();
        },
        onRemove: () {
          final selectedIndexes = selection.selectedItems.toList()..sort();
          final removedSongIds = selectedSongIds();
          final insertIndex = selectedIndexes.first;
          final songsById = {for (final song in songs) song.id: song};
          final nextSongIds = [
            for (var index = 0; index < songIds.length; index += 1)
              if (!selectedIndexes.contains(index)) songIds[index],
          ];
          onRemoveSelectedQueueIndexes(selectedIndexes, nextSongIds);
          showUndoableNotification(
            context: context,
            i18n: i18n,
            message: songsRemovedUndoMessage(
              i18n: i18n,
              songIds: removedSongIds,
              songsById: songsById,
              target: i18n.t('common.nowPlaying'),
            ),
            onUndo:
                () => onReplaceQueue(
                  insertImmersiveModeQueueSongs(
                    currentQueueSongIds(),
                    insertIndex,
                    removedSongIds,
                  ),
                ),
          );
          selection.clearSelection();
          onSelectionChanged();
        },
        onSelectAll: () {
          selection.selectAll(List.generate(songIds.length, (index) => index));
          onSelectionChanged();
        },
        onReverseSelection: () {
          selection.reverseSelection(
            List.generate(songIds.length, (index) => index),
          );
          onSelectionChanged();
        },
        onClearSelection: () {
          selection.clearSelection();
          onSelectionChanged();
        },
        onCancel: () {
          selection.cancel();
          onSelectionChanged();
        },
      ),
    );
  }
}
