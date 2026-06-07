part of 'music_dialog.dart';

class AlbumArtLibraryPickerDialog extends ConsumerStatefulWidget {
  const AlbumArtLibraryPickerDialog({
    super.key,
    required this.albumName,
    required this.currentSong,
    required this.songs,
    required this.onApply,
    required this.onClose,
  });

  final String albumName;
  final LibrarySong? currentSong;
  final List<LibrarySong> songs;
  final ValueChanged<AlbumArtLibraryChoice> onApply;
  final VoidCallback onClose;

  @override
  ConsumerState<AlbumArtLibraryPickerDialog> createState() =>
      _AlbumArtLibraryPickerDialogState();
}

class _AlbumArtLibraryPickerDialogState
    extends ConsumerState<AlbumArtLibraryPickerDialog> {
  final _pickerFocusNode = FocusNode(debugLabel: 'AlbumArtLibraryPicker');
  final _snapshotsBySongId = <int, SongArtworkSnapshot>{};
  var _query = '';
  var _loading = true;
  var _searchFocused = false;
  var _snapshotLoadGeneration = 0;
  int? _selectedSongId;

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_searchFocused) {
        _pickerFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pickerFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AlbumArtLibraryPickerDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songs != widget.songs ||
        oldWidget.albumName != widget.albumName ||
        oldWidget.currentSong?.id != widget.currentSong?.id) {
      _loadSnapshots();
    }
  }

  void _handleQueryChanged(String query) {
    setState(() {
      _query = query;
    });
    _loadSnapshots();
  }

  void _commitSearch([String? value]) {
    final query = (value ?? _query).trim();
    if (query.isNotEmpty) {
      unawaited(
        ref
            .read(libraryRepositoryProvider)
            .addRecentSearch(query, SearchHistoryType.sidebar)
            .then((_) {
              ref.invalidate(libraryContentDataProvider);
            }),
      );
    }
    setState(() {
      _searchFocused = false;
    });
  }

  void _selectRecentSearch(SearchHistoryEntry entry) {
    setState(() {
      _query = entry.query;
    });
    _commitSearch(entry.query);
  }

  void _removeRecentSearch(int entryId) {
    unawaited(
      ref.read(libraryRepositoryProvider).removeRecentSearches([entryId]).then((
        _,
      ) {
        ref.invalidate(libraryContentDataProvider);
      }),
    );
  }

  void _clearRecentSearches() {
    unawaited(
      ref.read(libraryRepositoryProvider).clearRecentSearches().then((_) {
        ref.invalidate(libraryContentDataProvider);
      }),
    );
  }

  Future<void> _loadSnapshots() async {
    final generation = ++_snapshotLoadGeneration;
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
    try {
      final snapshots = await ref
          .read(libraryRepositoryProvider)
          .getSongArtworkSnapshots(missingSongIds);
      if (!mounted || generation != _snapshotLoadGeneration) {
        return;
      }

      setState(() {
        for (final snapshot in snapshots) {
          _snapshotsBySongId[snapshot.songId] = snapshot;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _snapshotLoadGeneration) {
        setState(() {
          _loading = false;
        });
      }
    }
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
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final choices = _choices;
    final selectedChoice = _selectedChoice;
    final recentSearches =
        latestSearchHistoryEntries(
          ref.watch(libraryContentDataProvider).valueOrNull?.recentSearches ??
              const <SearchHistoryEntry>[],
          SearchHistoryType.sidebar,
        ).toList();
    final showRecentSearches = _searchFocused && recentSearches.isNotEmpty;

    return Focus(
      focusNode: _pickerFocusNode,
      autofocus: true,
      child: PopupDialog(
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
              key: const ValueKey('AlbumArtLibraryPicker.Title'),
              i18n.t('song.chooseArtworkFromLibrary'),
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
          key: const ValueKey('AlbumArtLibraryPicker.Footer'),
          padding:
              mobile
                  ? const EdgeInsets.fromLTRB(12, 12, 12, 20)
                  : const EdgeInsets.fromLTRB(28, 18, 28, 24),
          child: _AlbumArtLibraryPickerFooterButtonTheme(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 10,
              children: [
                SmPlayerTextIconButton(
                  key: const ValueKey('AlbumArtLibraryPicker.CancelButton'),
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
                  key: const ValueKey('AlbumArtLibraryPicker.ApplyButton'),
                  label: i18n.t('song.useSelectedArtwork'),
                  minWidth: 44,
                  height: 40,
                  horizontalPadding: 14,
                  borderRadius: 10,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation.weight(720)],
                  active: selectedChoice != null,
                  disabled: selectedChoice == null,
                  onPressed:
                      selectedChoice == null
                          ? null
                          : () {
                            widget.onApply(selectedChoice);
                          },
                ),
              ],
            ),
          ),
        ),
        child: Padding(
          key: const ValueKey('AlbumArtLibraryPicker.Body'),
          padding:
              mobile
                  ? const EdgeInsets.fromLTRB(12, 0, 12, 0)
                  : const EdgeInsets.fromLTRB(28, 0, 28, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  PageSearchField(
                    key: const ValueKey('AlbumArtLibraryPicker.SearchField'),
                    value: _query,
                    hintText: i18n.t('song.searchLibraryArtwork'),
                    focused: _searchFocused,
                    height: 40,
                    searchSurface:
                        nightMode
                            ? const Color(0x0bffffff)
                            : const Color(0x090d1826),
                    insetHighlight:
                        nightMode
                            ? const Color(0x0affffff)
                            : const Color(0x61ffffff),
                    searchTooltip: i18n.t('common.search'),
                    clearTooltip: i18n.t('common.clear'),
                    searchIcon: const _ElectronIcon(
                      _ElectronIconName.search,
                      size: 19,
                    ),
                    onChanged: _handleQueryChanged,
                    onFocusChanged: (focused) {
                      setState(() {
                        _searchFocused = focused;
                      });
                    },
                    onSubmitted: _commitSearch,
                    onClear: () {
                      _handleQueryChanged('');
                      setState(() {
                        _searchFocused = true;
                      });
                    },
                  ),
                  SizedBox(
                    key: const ValueKey('AlbumArtLibraryPicker.SearchGap'),
                    height: mobile ? 12 : 16,
                  ),
                  Expanded(
                    child: _AlbumArtLibraryPickerContent(
                      loading: _loading,
                      choices: choices,
                      selectedChoice: selectedChoice,
                      mobile: mobile,
                      onSelect: (choice) {
                        setState(() {
                          _selectedSongId = choice.song.id;
                        });
                      },
                      onApply: widget.onApply,
                    ),
                  ),
                ],
              ),
              if (showRecentSearches)
                Positioned.fill(
                  child: Listener(
                    key: const ValueKey(
                      'AlbumArtLibraryPicker.SearchHistoryDismissLayer',
                    ),
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) {
                      setState(() {
                        _searchFocused = false;
                      });
                    },
                  ),
                ),
              if (showRecentSearches)
                Positioned(
                  top: 48,
                  left: 0,
                  right: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: SearchHistoryPanel<SearchHistoryEntry>(
                      panelKey: const ValueKey(
                        'AlbumArtLibraryPicker.SearchHistoryPanel',
                      ),
                      includeBorderInset: true,
                      useElectronPanelStyle: true,
                      title: i18n.t('sidebar.recentSearches'),
                      clearLabel: i18n.t('common.clear'),
                      items: [
                        for (final entry in recentSearches)
                          SearchHistoryPanelItem(
                            key: entry.id.toString(),
                            label: entry.query,
                            value: entry,
                          ),
                      ],
                      onClear: _clearRecentSearches,
                      onSelect: (item) {
                        _selectRecentSearch(item.value);
                      },
                      onRemove: (item) {
                        _removeRecentSearch(item.value.id);
                      },
                      getRemoveLabel:
                          (item) => i18n.t('sidebar.removeRecentSearch', {
                            'query': item.value.query,
                          }),
                      itemKeyBuilder:
                          (item) => ValueKey(
                            'AlbumArtLibraryPicker.SearchHistoryItem.${item.key}',
                          ),
                      selectKeyBuilder:
                          (item) => ValueKey(
                            'AlbumArtLibraryPicker.SearchHistorySelect.${item.key}',
                          ),
                      removeKeyBuilder:
                          (item) => ValueKey(
                            'AlbumArtLibraryPicker.SearchHistoryRemove.${item.key}',
                          ),
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

class _AlbumArtLibraryPickerFooterButtonTheme extends StatelessWidget {
  const _AlbumArtLibraryPickerFooterButtonTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseColors = SmPlayerTextIconButtonColors.of(context);
    final dialogColors = PopupDialogColors.resolve(context);
    return SmPlayerTextIconButtonTheme(
      colors: baseColors.copyWith(
        commandText:
            dark ? baseColors.commandText : CommandBarColors.textStrong,
        commandTextHover: baseColors.commandTextHover,
        control: dark ? baseColors.control : CommandBarColors.buttonSurface,
        controlHover: baseColors.controlHover,
        controlHoverBorder: baseColors.controlHoverBorder,
        controlBorder:
            dark ? baseColors.controlBorder : CommandBarColors.buttonBorder,
        controlActive: dialogColors.accent,
        accentStrong: Colors.white,
      ),
      child: child,
    );
  }
}

class _AlbumArtLibraryPickerContent extends StatelessWidget {
  const _AlbumArtLibraryPickerContent({
    required this.loading,
    required this.choices,
    required this.selectedChoice,
    required this.mobile,
    required this.onSelect,
    required this.onApply,
  });

  final bool loading;
  final List<AlbumArtLibraryChoice> choices;
  final AlbumArtLibraryChoice? selectedChoice;
  final bool mobile;
  final ValueChanged<AlbumArtLibraryChoice> onSelect;
  final ValueChanged<AlbumArtLibraryChoice> onApply;

  @override
  Widget build(BuildContext context) {
    final list = _AlbumArtLibraryPickerScrollableList(
      loading: loading,
      choices: choices,
      selectedChoice: selectedChoice,
      mobile: mobile,
      onSelect: onSelect,
      onApply: onApply,
    );
    if (mobile) {
      return list;
    }
    return Row(
      children: [
        Expanded(flex: 3, child: list),
        const SizedBox(width: 18),
        SizedBox(
          key: const ValueKey('AlbumArtLibraryPicker.PreviewColumn'),
          width: 240,
          child: _AlbumArtChoicePreview(choice: selectedChoice),
        ),
      ],
    );
  }
}

class _AlbumArtLibraryPickerScrollableList extends StatefulWidget {
  const _AlbumArtLibraryPickerScrollableList({
    required this.loading,
    required this.choices,
    required this.selectedChoice,
    required this.mobile,
    required this.onSelect,
    required this.onApply,
  });

  final bool loading;
  final List<AlbumArtLibraryChoice> choices;
  final AlbumArtLibraryChoice? selectedChoice;
  final bool mobile;
  final ValueChanged<AlbumArtLibraryChoice> onSelect;
  final ValueChanged<AlbumArtLibraryChoice> onApply;

  @override
  State<_AlbumArtLibraryPickerScrollableList> createState() =>
      _AlbumArtLibraryPickerScrollableListState();
}

class _AlbumArtLibraryPickerScrollableListState
    extends State<_AlbumArtLibraryPickerScrollableList> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final listPadding =
        widget.mobile
            ? const EdgeInsets.fromLTRB(0, 4, 0, 12)
            : const EdgeInsets.only(right: 10);
    final list =
        widget.loading
            ? ListView(
              controller: _controller,
              padding: listPadding,
              children: [
                _AlbumArtLibraryPickerMessage(
                  text: i18n.t('nowPlaying.loading'),
                ),
              ],
            )
            : widget.choices.isEmpty
            ? ListView(
              controller: _controller,
              padding: listPadding,
              children: [
                _AlbumArtLibraryPickerMessage(
                  text: i18n.t('song.noLibraryArtwork'),
                ),
              ],
            )
            : ListView.separated(
              controller: _controller,
              padding: listPadding,
              itemCount: widget.choices.length,
              separatorBuilder:
                  (context, index) => SizedBox(height: widget.mobile ? 8 : 6),
              itemBuilder: (context, index) {
                final choice = widget.choices[index];
                return _AlbumArtChoiceTile(
                  choice: choice,
                  selected: widget.selectedChoice?.song.id == choice.song.id,
                  mobile: widget.mobile,
                  onTap: () {
                    widget.onSelect(choice);
                  },
                  onDoubleTap: () {
                    widget.onApply(choice);
                  },
                );
              },
            );

    return _SongDialogScrollbarHost(
      controller: _controller,
      right: widget.mobile ? -12 : -5,
      bottom: 4,
      trackWidth: widget.mobile ? 16 : 9,
      normalThumbLeft: widget.mobile ? 5 : 2,
      normalThumbRight: widget.mobile ? 6 : 2,
      hoverThumbLeft: widget.mobile ? 4 : 1,
      hoverThumbRight: widget.mobile ? 5 : 1,
      frameKey: const ValueKey('AlbumArtLibraryPicker.ListFrame'),
      positionKey: const ValueKey('AlbumArtLibraryPicker.Scrollbar.Position'),
      thumbKey: const ValueKey('AlbumArtLibraryPicker.Scrollbar.Thumb'),
      child: list,
    );
  }
}

class _AlbumArtChoiceTile extends StatefulWidget {
  const _AlbumArtChoiceTile({
    required this.choice,
    required this.selected,
    required this.mobile,
    required this.onTap,
    required this.onDoubleTap,
  });

  final AlbumArtLibraryChoice choice;
  final bool selected;
  final bool mobile;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  State<_AlbumArtChoiceTile> createState() => _AlbumArtChoiceTileState();
}

class _AlbumArtChoiceTileState extends State<_AlbumArtChoiceTile> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final highlighted = widget.selected || _hovered || _focused;
    final tileHeight = widget.mobile ? 92.0 : 74.0;
    final artworkSize = widget.mobile ? 84.0 : 64.0;
    final horizontalGap = widget.mobile ? 10.0 : 12.0;
    final selectedBackground =
        widget.mobile
            ? Color.alphaBlend(
              GlobalUI.sourceListMobileSelectedBgColor,
              colors.surface,
            )
            : GlobalUI.sourceListSelectedBgColor;
    final selectedBorder = GlobalUI.sourceListSelectedBorderColor;
    final selectedShadow =
        widget.mobile && highlighted
            ? GlobalUI.sourceListMobileSelectedShadow
            : GlobalUI.sourceListSelectedShadow;

    return Focus(
      key: ValueKey('AlbumArtLibraryPicker.Choice.${widget.choice.song.id}'),
      onFocusChange: (focused) {
        setState(() {
          _focused = focused;
        });
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onDoubleTap();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.space) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
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
        child: InkWell(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          borderRadius: BorderRadius.circular(widget.mobile ? 9 : 8),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          child: AnimatedContainer(
            key: ValueKey(
              'AlbumArtLibraryPicker.ChoiceSurface.${widget.choice.song.id}',
            ),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: tileHeight,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: highlighted ? selectedBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.mobile ? 9 : 8),
              border:
                  widget.mobile
                      ? null
                      : Border.all(
                        color:
                            highlighted ? selectedBorder : Colors.transparent,
                      ),
              boxShadow: selectedShadow,
            ),
            child: Row(
              children: [
                _ArtworkImage(
                  decorationKey: ValueKey(
                    'AlbumArtLibraryPicker.ChoiceArtwork.${widget.choice.song.id}',
                  ),
                  url: widget.choice.artworkUrl,
                  size: artworkSize,
                  borderRadius: 6,
                  showShadow: false,
                  forceLightSurface: true,
                ),
                SizedBox(width: horizontalGap),
                Expanded(
                  child: SizedBox(
                    height: artworkSize,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          key: ValueKey(
                            'AlbumArtLibraryPicker.ChoiceTitle.${widget.choice.song.id}',
                          ),
                          widget.choice.song.title,
                          maxLines: widget.mobile ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 18 / 15,
                          ),
                        ),
                        Text(
                          _getDisplayArtists(widget.choice.song, i18n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 13,
                            height: 16 / 13,
                          ),
                        ),
                        Text(
                          song_display.displayAlbum(widget.choice.song, i18n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 13,
                            height: 16 / 13,
                          ),
                        ),
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
}

class _AlbumArtChoicePreview extends StatelessWidget {
  const _AlbumArtChoicePreview({required this.choice});

  final AlbumArtLibraryChoice? choice;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final choice = this.choice;

    return Padding(
      key: const ValueKey('AlbumArtLibraryPicker.Preview'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (choice != null) ...[
            _ArtworkImage(
              decorationKey: const ValueKey(
                'AlbumArtLibraryPicker.PreviewArtwork',
              ),
              url: choice.artworkUrl,
              size: 220,
            ),
            const SizedBox(height: 8),
            Text(
              key: const ValueKey('AlbumArtLibraryPicker.PreviewTitle'),
              choice.song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 22.5 / 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getDisplayArtists(choice.song, i18n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                height: 16 / 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song_display.displayAlbum(choice.song, i18n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                height: 16 / 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlbumArtLibraryPickerMessage extends StatelessWidget {
  const _AlbumArtLibraryPickerMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Padding(
      key: const ValueKey('AlbumArtLibraryPicker.Message'),
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Text(
        key: const ValueKey('AlbumArtLibraryPicker.MessageText'),
        text,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({
    required this.url,
    required this.size,
    this.decorationKey,
    this.borderRadius = 8,
    this.showShadow = true,
    this.forceLightSurface = false,
  });

  final String url;
  final double size;
  final Key? decorationKey;
  final double borderRadius;
  final bool showShadow;
  final bool forceLightSurface;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (showShadow)
            _ArtworkImageShadow(size: size, borderRadius: borderRadius),
          DecoratedBox(
            key: decorationKey,
            decoration: BoxDecoration(
              color:
                  nightMode && !forceLightSurface
                      ? const Color(0x14ffffff)
                      : const Color(0xb8ffffff),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child:
                  File(url).existsSync()
                      ? Image.file(File(url), fit: BoxFit.cover)
                      : ColoredBox(
                        color:
                            nightMode
                                ? colors.fieldDisabledSurface
                                : const Color(0xffe8eef5),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkImageShadow extends StatelessWidget {
  const _ArtworkImageShadow({required this.size, required this.borderRadius});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -32,
      top: -32,
      right: -32,
      bottom: -32,
      child: IgnorePointer(
        child: CustomPaint(
          key: const ValueKey('AlbumArtLibraryPicker.PreviewArtworkShadow'),
          painter: _ArtworkImageShadowPainter(
            size: size,
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }
}

class _ArtworkImageShadowPainter extends CustomPainter {
  const _ArtworkImageShadowPainter({
    required this.size,
    required this.borderRadius,
  });

  final double size;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final left = (canvasSize.width - size) / 2;
    final top = (canvasSize.height - size) / 2 + 8;
    final paint =
        Paint()
          ..color = const Color(0x21202d3f)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, size, size),
        Radius.circular(borderRadius),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArtworkImageShadowPainter oldDelegate) {
    return oldDelegate.size != size || oldDelegate.borderRadius != borderRadius;
  }
}

class _ArtworkDeleteConfirm extends StatelessWidget {
  const _ArtworkDeleteConfirm({
    required this.message,
    required this.disabled,
    required this.onConfirm,
    required this.onCancel,
  });

  final String message;
  final bool disabled;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 360,
      child: Container(
        key: const ValueKey('MusicDialog.ArtworkDeleteConfirm'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: nightMode ? const Color(0x52582720) : const Color(0xebfff5f2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                nightMode ? const Color(0x47ffbca6) : const Color(0x52b0584a),
          ),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            Text(
              key: const ValueKey('MusicDialog.ArtworkDeleteConfirmText'),
              message,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            _MusicDialogCommandButton(
              key: const ValueKey('MusicDialog.ArtworkDeleteConfirmYes'),
              label: i18n.t('common.yes'),
              disabled: disabled,
              onPressed: onConfirm,
            ),
            _MusicDialogCommandButton(
              key: const ValueKey('MusicDialog.ArtworkDeleteConfirmCancel'),
              label: i18n.t('common.cancel'),
              disabled: disabled,
              onPressed: onCancel,
            ),
          ],
        ),
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
  if (dateTime == null) {
    return value;
  }
  final localDateTime = dateTime.toLocal();
  return '${localDateTime.year}/${localDateTime.month}/${localDateTime.day} '
      '${localDateTime.hour.toString().padLeft(2, '0')}:'
      '${localDateTime.minute.toString().padLeft(2, '0')}:'
      '${localDateTime.second.toString().padLeft(2, '0')}';
}
