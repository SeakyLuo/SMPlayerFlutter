part of 'headered_playlist_control.dart';

extension _HeaderedPlaylistControlCommandBar on _HeaderedPlaylistControlState {
  Widget _buildCommandBar(
    BuildContext context,
    SmPlayerI18n i18n,
    List<LibrarySong> visibleSongs,
    List<int> queueSongIds,
    PlaylistSortCriterion activeSortCriterion,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
  ) {
    final colors = HeaderedPlaylistThemeColors.of(context);
    final compact = MediaQuery.sizeOf(context).width <= 720;
    return SmPlayerTextIconButtonTheme(
      colors: SmPlayerTextIconButtonColors.of(context).copyWith(
        commandText: colors.commandText,
        control: colors.commandControl,
        controlHover: colors.commandControlHover,
        controlBorder: colors.commandControlBorder,
      ),
      child: CommandBar(
        key: const ValueKey('HeaderedPlaylist.CommandBar'),
        style: CommandBarStyleVariant.headeredPlaylist,
        overflowLabel: i18n.t('player.more'),
        primaryAlignment:
            compact
                ? CommandBarPrimaryAlignment.center
                : CommandBarPrimaryAlignment.start,
        children: [
          CommandBarButton(
            iconWidget: const ShuffleIcon(),
            useShuffleIcon: true,
            label: captionForHeaderedPlaylist(i18n, 'shuffle'),
            disabled: visibleSongs.isEmpty,
            onPressed: () {
              _shuffle(queueSongIds);
            },
          ),
          CommandBarButton(
            icon: FluentIcons.multiselect_ltr_20_regular,
            label: captionForHeaderedPlaylist(i18n, 'multiSelect'),
            active: _selection.multiSelect,
            activeMatchesHover: true,
            tooltip:
                _selection.multiSelect
                    ? i18n.t('common.exitMultiSelectTooltip')
                    : null,
            disabled: visibleSongs.isEmpty,
            onPressed: () {
              _updateState(() {
                _selection.toggleMultiSelect();
              });
            },
          ),
          if (widget.canSetPreferred && widget.onSetPreferred != null)
            CommandBarButton(
              icon: FluentIcons.star_20_regular,
              label: captionForHeaderedPlaylist(i18n, 'preferenceSettings'),
              onOverflowPressedWithContext: (buttonContext) {
                unawaited(_showHeaderPreferenceMenu(buttonContext, i18n));
              },
              onPressedWithContext: (buttonContext) {
                unawaited(_showHeaderPreferenceMenu(buttonContext, i18n));
              },
            ),
          CommandBarButton(
            icon: FluentIcons.arrow_sort_20_regular,
            label: captionForHeaderedPlaylist(i18n, 'sort'),
            disabled: visibleSongs.isEmpty,
            overflowSubmenu: _sortMenuItems(i18n, activeSortCriterion),
            onPressedWithContext: (buttonContext) {
              showMenuFlyout(
                buttonContext,
                items: _sortMenuItems(i18n, activeSortCriterion),
              );
            },
          ),
          if (widget.canRename)
            CommandBarButton(
              icon: FluentIcons.edit_20_regular,
              label: captionForHeaderedPlaylist(i18n, 'rename'),
              onPressed: () {
                unawaited(_requestRename(i18n));
              },
            ),
          if (widget.canClear)
            CommandBarButton(
              icon: FluentIcons.broom_20_regular,
              label: captionForHeaderedPlaylist(i18n, 'clear'),
              disabled: visibleSongs.isEmpty,
              onPressed: () {
                unawaited(_requestClear(i18n));
              },
            ),
          if (widget.canDelete)
            CommandBarButton(
              icon: FluentIcons.delete_20_regular,
              label: captionForHeaderedPlaylist(i18n, 'delete'),
              onPressed: () {
                unawaited(_requestDelete(i18n));
              },
            ),
          if (widget.canEditArtwork && widget.onEditArtwork != null)
            CommandBarButton(
              icon: FluentIcons.image_edit_20_regular,
              label: captionForHeaderedPlaylist(i18n, 'editArtwork'),
              onPressed: widget.onEditArtwork,
            ),
        ],
      ),
    );
  }

  Widget _buildShyCommandBar(
    BuildContext context,
    SmPlayerI18n i18n,
    List<LibrarySong> visibleSongs,
    List<int> queueSongIds,
    PlaylistSortCriterion activeSortCriterion,
  ) {
    return CommandBar(
      style: CommandBarStyleVariant.appBar,
      dynamicOverflow: false,
      overflowItems: [
        MenuFlyoutItem(
          key: 'multi-select',
          text: captionForHeaderedPlaylist(i18n, 'multiSelect'),
          icon: FluentIcons.multiselect_ltr_20_regular,
          disabled: visibleSongs.isEmpty,
          onPressed: () {
            _updateState(() {
              _selection.toggleMultiSelect();
            });
          },
        ),
        if (widget.canSetPreferred && widget.onSetPreferred != null)
          MenuFlyoutItem(
            key: 'preference-settings',
            text: captionForHeaderedPlaylist(i18n, 'preferenceSettings'),
            icon: FluentIcons.star_20_regular,
            onPressed: () {},
            onPressedWithContext: (buttonContext) {
              unawaited(_showHeaderPreferenceMenu(buttonContext, i18n));
            },
          ),
        MenuFlyoutItem(
          key: 'sort',
          text: captionForHeaderedPlaylist(i18n, 'sort'),
          icon: FluentIcons.arrow_sort_20_regular,
          disabled: visibleSongs.isEmpty,
          submenu: _sortMenuItems(i18n, activeSortCriterion),
        ),
        if (widget.canRename)
          MenuFlyoutItem(
            key: 'rename',
            text: captionForHeaderedPlaylist(i18n, 'rename'),
            icon: FluentIcons.edit_20_regular,
            onPressed: () {
              unawaited(_requestRename(i18n));
            },
          ),
        if (widget.canClear)
          MenuFlyoutItem(
            key: 'clear',
            text: captionForHeaderedPlaylist(i18n, 'clear'),
            icon: FluentIcons.broom_20_regular,
            disabled: visibleSongs.isEmpty,
            onPressed: () {
              unawaited(_requestClear(i18n));
            },
          ),
        if (widget.canDelete)
          MenuFlyoutItem(
            key: 'delete',
            text: captionForHeaderedPlaylist(i18n, 'delete'),
            icon: FluentIcons.delete_20_regular,
            onPressed: () {
              unawaited(_requestDelete(i18n));
            },
          ),
        if (widget.canEditArtwork && widget.onEditArtwork != null)
          MenuFlyoutItem(
            key: 'edit-artwork',
            text: captionForHeaderedPlaylist(i18n, 'editArtwork'),
            icon: FluentIcons.image_edit_20_regular,
            onPressed: widget.onEditArtwork,
          ),
      ],
      overflowLabel: i18n.t('player.more'),
      children: [
        CommandBarButton(
          iconWidget: const ShuffleIcon(),
          useShuffleIcon: true,
          label: captionForHeaderedPlaylist(i18n, 'shuffle'),
          disabled: visibleSongs.isEmpty,
          onPressed: () {
            _shuffle(queueSongIds);
          },
        ),
      ],
    );
  }

  List<MenuFlyoutItem> _sortMenuItems(
    SmPlayerI18n i18n,
    PlaylistSortCriterion activeSortCriterion,
  ) {
    return [
      MenuFlyoutItem(
        key: 'reverse',
        text: captionForHeaderedPlaylist(i18n, 'sort.reverse'),
        onPressed: _reverseSort,
      ),
      const MenuFlyoutItem.separator(key: 'sort-separator'),
      for (final criterion in sortOptions)
        MenuFlyoutItem(
          key: criterion.name,
          text: captionForHeaderedPlaylist(i18n, sortCaptionKey(criterion)),
          icon:
              criterion == activeSortCriterion
                  ? FluentIcons.checkmark_20_regular
                  : null,
          onPressed: () {
            _commitSort(criterion, activeSortCriterion);
          },
        ),
    ];
  }

  Future<void> _showHeaderPreferenceMenu(
    BuildContext context,
    SmPlayerI18n i18n,
  ) async {
    final preferenceType = widget.preferenceType;
    final preferenceItemId = widget.preferenceItemId;
    final preferenceLevel =
        preferenceType == null || preferenceItemId == null
            ? null
            : await ref
                .read(libraryRepositoryProvider)
                .getPreferenceLevel(preferenceType, preferenceItemId);
    if (!context.mounted) {
      return;
    }

    final preferenceItem = buildPreferenceMenuFlyoutItem(
      i18n: i18n,
      key: 'preference',
      preferenceLevel: preferenceLevel,
      onUndoPreference:
          preferenceType == null ||
                  preferenceItemId == null ||
                  preferenceLevel == null
              ? null
              : () async {
                await ref
                    .read(libraryRepositoryProvider)
                    .removePreferenceItem(preferenceType, preferenceItemId);
              },
      onSetPreference: (level) async {
        await widget.onSetPreferred!(level);
      },
    );
    showMenuFlyout(context, items: preferenceItem.submenu);
  }
}
