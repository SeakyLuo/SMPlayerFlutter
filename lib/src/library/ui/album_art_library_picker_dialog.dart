part of 'music_dialog.dart';

class _AlbumArtLibraryPickerDialog extends ConsumerStatefulWidget {
  const _AlbumArtLibraryPickerDialog({
    required this.albumName,
    required this.currentSong,
    required this.songs,
    required this.onApply,
    required this.onClose,
  });

  final String albumName;
  final LibrarySong currentSong;
  final List<LibrarySong> songs;
  final ValueChanged<AlbumArtLibraryChoice> onApply;
  final VoidCallback onClose;

  @override
  ConsumerState<_AlbumArtLibraryPickerDialog> createState() =>
      _AlbumArtLibraryPickerDialogState();
}

class _AlbumArtLibraryPickerDialogState
    extends ConsumerState<_AlbumArtLibraryPickerDialog> {
  final _queryController = TextEditingController();
  final _snapshotsBySongId = <int, SongArtworkSnapshot>{};
  var _query = '';
  var _loading = true;
  int? _selectedSongId;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_handleQueryChanged);
    _loadSnapshots();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    setState(() {
      _query = _queryController.text;
    });
    _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    final missingSongIds =
        _rankedSongs
            .take(320)
            .map((ranked) => ranked.song.id)
            .where((songId) => !_snapshotsBySongId.containsKey(songId))
            .toList();
    if (missingSongIds.isEmpty) {
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
    });
    final snapshots = await ref
        .read(libraryRepositoryProvider)
        .getSongArtworkSnapshots(missingSongIds);
    if (!mounted) {
      return;
    }

    setState(() {
      for (final snapshot in snapshots) {
        _snapshotsBySongId[snapshot.songId] = snapshot;
      }
      _loading = false;
    });
  }

  List<_RankedSong> get _rankedSongs {
    return _getRankedArtworkSourceSongs(
      songs: widget.songs,
      albumName: widget.albumName,
      currentSong: widget.currentSong,
      normalizedQuery: _normalizeSearchText(_query),
    );
  }

  List<AlbumArtLibraryChoice> get _choices {
    final choices =
        _rankedSongs
            .take(320)
            .map((ranked) {
              final snapshot = _snapshotsBySongId[ranked.song.id];
              if (snapshot == null ||
                  snapshot.source == SongArtworkSource.none ||
                  snapshot.sourcePath.isEmpty ||
                  snapshot.sourceUrl.isEmpty) {
                return null;
              }

              return AlbumArtLibraryChoice(
                song: ranked.song,
                artworkUrl: snapshot.artworkUrl,
                sourceUrl: snapshot.sourceUrl,
                sourcePath: snapshot.sourcePath,
              );
            })
            .whereType<AlbumArtLibraryChoice>()
            .toList();

    return _query.trim().isEmpty ? choices : choices.take(160).toList();
  }

  AlbumArtLibraryChoice? get _selectedChoice {
    final choices = _choices;
    return choices
            .where((choice) => choice.song.id == _selectedSongId)
            .firstOrNull ??
        choices.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final choices = _choices;
    final selectedChoice = _selectedChoice;

    return PopupDialog(
      overlayClassName: 'album-art-library-picker-overlay',
      className: 'album-art-library-picker-dialog ContentDialog',
      navClassName: 'album-art-library-picker-nav',
      navLabel: i18n.t('song.chooseArtworkFromLibrary'),
      ariaLabel: i18n.t('song.chooseArtworkFromLibrary'),
      width: 860,
      height: 680,
      onClose: widget.onClose,
      navChildren: [
        Expanded(
          child: Text(
            i18n.t('song.chooseArtworkFromLibrary'),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PopupDialogColors.textStrong,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onClose,
              child: Text(i18n.t('common.cancel')),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
                  selectedChoice == null
                      ? null
                      : () {
                        widget.onApply(selectedChoice);
                      },
              child: Text(i18n.t('song.useSelectedArtwork')),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                prefixIcon: const Icon(FluentIcons.search_20_regular),
                suffixIcon:
                    _query.isEmpty
                        ? null
                        : IconButton(
                          icon: const Icon(FluentIcons.dismiss_20_regular),
                          onPressed: _queryController.clear,
                        ),
                hintText: i18n.t('song.searchLibraryArtwork'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child:
                        _loading
                            ? const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : choices.isEmpty
                            ? Center(
                              child: Text(i18n.t('song.noLibraryArtwork')),
                            )
                            : ListView.separated(
                              itemCount: choices.length,
                              separatorBuilder:
                                  (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final choice = choices[index];
                                final selected =
                                    selectedChoice?.song.id == choice.song.id;
                                return _AlbumArtChoiceTile(
                                  choice: choice,
                                  selected: selected,
                                  onTap: () {
                                    setState(() {
                                      _selectedSongId = choice.song.id;
                                    });
                                  },
                                  onDoubleTap: () {
                                    widget.onApply(choice);
                                  },
                                );
                              },
                            ),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 220,
                    child:
                        selectedChoice == null
                            ? const SizedBox.shrink()
                            : _AlbumArtChoicePreview(choice: selectedChoice),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumArtChoiceTile extends StatelessWidget {
  const _AlbumArtChoiceTile({
    required this.choice,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final AlbumArtLibraryChoice choice;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              selected
                  ? PopupDialogColors.activeButtonSurface
                  : PopupDialogColors.buttonSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                selected
                    ? PopupDialogColors.activeButtonBorder
                    : PopupDialogColors.buttonBorder,
          ),
        ),
        child: Row(
          children: [
            _ArtworkImage(url: choice.artworkUrl, size: 58),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    choice.song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _getDisplayArtists(choice.song, i18n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PopupDialogColors.textMuted),
                  ),
                  Text(
                    song_display.displayAlbum(choice.song, i18n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PopupDialogColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumArtChoicePreview extends StatelessWidget {
  const _AlbumArtChoicePreview({required this.choice});

  final AlbumArtLibraryChoice choice;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArtworkImage(url: choice.artworkUrl, size: 220),
        const SizedBox(height: 12),
        Text(
          choice.song.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          _getDisplayArtists(choice.song, i18n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          song_display.displayAlbum(choice.song, i18n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            File(url).existsSync()
                ? Image.file(File(url), fit: BoxFit.cover)
                : const ColoredBox(color: Color(0xffe8eef5)),
      ),
    );
  }
}

class _ArtworkDeleteConfirm extends StatelessWidget {
  const _ArtworkDeleteConfirm({
    required this.message,
    required this.onConfirm,
    required this.onCancel,
  });

  final String message;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffff7ed),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffffd7aa)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(message)),
          const SizedBox(width: 10),
          FilledButton(onPressed: onConfirm, child: Text(i18n.t('common.yes'))),
          const SizedBox(width: 8),
          TextButton(onPressed: onCancel, child: Text(i18n.t('common.cancel'))),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}

String _formatDateTime(String value) {
  final dateTime = DateTime.tryParse(value);
  return dateTime == null ? value : dateTime.toLocal().toString();
}
