part of 'playlists_page.dart';

extension _PlaylistsPageDragActions on _PlaylistsPageState {
  void _previewPlaylistMoveToPoint(
    List<int> currentPlaylistIds,
    Offset pointerPosition,
  ) {
    _previewPlaylistMoveToDragRect(
      currentPlaylistIds,
      _playlistDragRectFor(pointerPosition),
    );
  }

  void _previewPlaylistMoveToDragRect(
    List<int> currentPlaylistIds,
    Rect dragRect,
  ) {
    final draggedPlaylistId = _draggingPlaylistId;
    if (draggedPlaylistId == null) {
      return;
    }

    final currentPreview = _previewPlaylistIds ?? currentPlaylistIds;
    final draggedIndex = currentPreview.indexOf(draggedPlaylistId);
    if (draggedIndex == -1) {
      return;
    }
    final targetSlots =
        currentPreview.indexed
            .where((entry) => entry.$2 != draggedPlaylistId)
            .map((entry) {
              final playlistId = entry.$2;
              final context = _playlistCardContexts[playlistId];
              final renderObject = context?.findRenderObject();
              if (renderObject is! RenderBox) {
                return null;
              }
              final topLeft = renderObject.localToGlobal(Offset.zero);
              return (
                playlistId: playlistId,
                rect: topLeft & renderObject.size,
              );
            })
            .whereType<({int playlistId, Rect rect})>()
            .toList();
    final nextIds =
        currentPreview
            .where((playlistId) => playlistId != draggedPlaylistId)
            .toList();
    final insertIndex = _playlistInsertIndexFromDragOverlap(
      nextIds: nextIds,
      targetSlots: targetSlots,
      dragRect: dragRect,
    );
    if (insertIndex == null) {
      return;
    }
    nextIds.insert(insertIndex, draggedPlaylistId);
    if (_idsEqual(currentPreview, nextIds)) {
      return;
    }

    _updateState(() {
      _previewPlaylistIds = nextIds;
    });
  }

  void _commitPlaylistPreview() {
    final nextPlaylistIds = _previewPlaylistIds;
    final startPlaylistIds = _dragStartPlaylistIds;
    if (nextPlaylistIds != null &&
        startPlaylistIds != null &&
        !_idsEqual(startPlaylistIds, nextPlaylistIds)) {
      _committedPlaylistIds = nextPlaylistIds;
      unawaited(_persistPlaylistOrder(nextPlaylistIds));
    }
    _clearPlaylistDrag();
  }

  Future<void> _persistPlaylistOrder(List<int> playlistIds) async {
    await ref.read(libraryRepositoryProvider).reorderPlaylists(playlistIds);
    ref.invalidate(libraryContentDataProvider);
  }

  void _clearPlaylistDrag() {
    _updateState(() {
      _draggingPlaylistId = null;
      _previewPlaylistIds = null;
      _dragStartPlaylistIds = null;
      _playlistDragAccepted = false;
      _playlistDragAnchorOffset = null;
    });
  }

  List<int>? _committedPlaylistIdsFor(List<int> currentPlaylistIds) {
    final committedPlaylistIds = _committedPlaylistIds;
    if (committedPlaylistIds == null) {
      return null;
    }
    if (!_idsContainSameItems(committedPlaylistIds, currentPlaylistIds)) {
      _committedPlaylistIds = null;
      return null;
    }
    return committedPlaylistIds;
  }

  Rect _playlistDragRectFor(Offset pointerPosition) {
    final anchor =
        _playlistDragAnchorOffset ??
        const Offset(_playlistCardWidth / 2, _playlistCardHeight / 2);
    return (pointerPosition - anchor) &
        const Size(_playlistCardWidth, _playlistCardHeight);
  }

  int? _playlistInsertIndexFromDragOverlap({
    required List<int> nextIds,
    required List<({int playlistId, Rect rect})> targetSlots,
    required Rect dragRect,
  }) {
    ({int playlistId, Rect rect, double ratio})? bestOverlap;
    for (final slot in targetSlots) {
      if (!dragRect.overlaps(slot.rect)) {
        continue;
      }
      final overlap = dragRect.intersect(slot.rect);
      final area = overlap.width * overlap.height;
      final ratio = area / (slot.rect.width * slot.rect.height);
      if (ratio < _playlistDragOverlapThreshold) {
        continue;
      }
      if (bestOverlap == null || ratio > bestOverlap.ratio) {
        bestOverlap = (
          playlistId: slot.playlistId,
          rect: slot.rect,
          ratio: ratio,
        );
      }
    }
    if (bestOverlap == null) {
      return null;
    }

    final nextIndex = nextIds.indexOf(bestOverlap.playlistId);
    if (nextIndex == -1) {
      return null;
    }
    final insertAfter =
        dragRect.center.dy >= bestOverlap.rect.top &&
                dragRect.center.dy <= bestOverlap.rect.bottom
            ? dragRect.center.dx > bestOverlap.rect.center.dx
            : dragRect.center.dy > bestOverlap.rect.center.dy;
    return insertAfter ? nextIndex + 1 : nextIndex;
  }
}
