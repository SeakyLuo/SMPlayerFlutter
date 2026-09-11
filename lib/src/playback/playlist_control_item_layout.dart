part of 'playlist_control_item.dart';

extension _PlaylistControlItemLayout on _PlaylistControlItemState {
  Widget _buildRow(BuildContext context, BoxConstraints constraints) {
    final i18n = context.smPlayerI18n;
    final hasAlbumColumn = widget.showAlbum;
    final windowWidth = MediaQuery.sizeOf(context).width;
    final compactVariant = windowWidth <= 720;
    final defaultColors = widget.colors == null;
    final colors = widget.colors ?? _PlaylistControlItemColors.resolve(context);
    final narrowRow = constraints.maxWidth <= 720;
    final compact = PlaylistControlItemMetrics.isCompactRow(
      constraints.maxWidth,
    );
    final hoverActionsVisible = _hoverActive;
    final showActionSlot = !widget.selectionMode;
    final multiSelectSelected = widget.selectionMode && widget.selected;
    final transparentHover = colors.hover.withValues(alpha: 0);
    final rowHovered = _hoverActive;
    final opaqueHover = Color.alphaBlend(
      colors.hover,
      Theme.of(context).scaffoldBackgroundColor,
    );
    final rowBackgroundColor =
        multiSelectSelected
            ? opaqueHover
            : widget.current
            ? colors.current
            : widget.selected
            ? opaqueHover
            : rowHovered
            ? opaqueHover
            : transparentHover;
    final rowHeight = PlaylistControlItemMetrics.rowHeight(windowWidth);
    final artworkGap = compactVariant ? 12.0 : 14.0;
    final dropPosition = widget.dropPosition;
    final content = InkWell(
      key: const ValueKey('PlaylistControlItem.Row'),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      onTap: _activateRow,
      onSecondaryTapDown: (details) {
        unawaited(
          _openPinnedMenu(
            _PlaylistControlMenuPin.contextMenu,
            () => widget.onOpenContextMenu(details.globalPosition),
          ),
        );
      },
      child: Container(
        height: rowHeight,
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: rowBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border:
              widget.showBottomBorder
                  ? Border(bottom: BorderSide(color: colors.border))
                  : null,
          boxShadow:
              defaultColors
                  ? widget.selected || _hoverActive
                      ? [
                        if (widget.selected && !multiSelectSelected)
                          const BoxShadow(
                            color: _PlaylistControlItemColors.selectedInset,
                            offset: Offset(3, 0),
                          ),
                        if (colors.hoverBorder != Colors.transparent)
                          BoxShadow(color: colors.hoverBorder, spreadRadius: 1),
                      ]
                      : null
                  : widget.selected || _hoverActive
                  ? [BoxShadow(color: colors.hoverBorder, spreadRadius: 1)]
                  : null,
        ),
        child: Builder(
          builder: (context) {
            _swipeLayoutWidth = constraints.maxWidth;
            final baseRowPadding =
                compact
                    ? const EdgeInsets.all(10)
                    : const EdgeInsets.fromLTRB(18, 10, 22, 10);
            final showInlineActions = showActionSlot;
            final durationWidth =
                compact
                    ? PlaylistControlItemMetrics.nowPlayingCompactDurationWidth
                    : 74.0;
            final overlayActionCount =
                1 +
                (widget.showFavoriteAction &&
                        widget.onToggleFavoriteClick != null
                    ? 1
                    : 0) +
                (widget.onAddToPlaylistClick == null ? 0 : 1) +
                (widget.onPlayNextClick == null ? 0 : 1) +
                (widget.onRemoveFromListClick == null ? 0 : 1);
            final overlayActionsWidth =
                _queueActionSize * overlayActionCount +
                _queueActionGap * (overlayActionCount - 1);
            final artwork = _QueueArtwork(
              song: widget.song,
              current: widget.current,
              playing: widget.playing,
              hovered: _hoverActive,
              selectionMode: widget.selectionMode,
              selected: widget.selected,
              onPlayTrack: widget.onPlayTrack,
              onTogglePlayPause: widget.onTogglePlayPause,
              colors: colors,
            );
            final rowPadding = baseRowPadding;
            Widget queueActions({required bool compactCollapsed}) {
              return _QueueActions(
                favorite: widget.song.favorite,
                compact: compact,
                playNextLabel: widget.playNextLabel,
                removeLabel: widget.removeLabel,
                addToPlaylistLabel: widget.addToPlaylistLabel,
                favoriteLabel: widget.favoriteLabel,
                moreLabel: widget.moreLabel,
                compactVariant: compact,
                showHoverActions: hoverActionsVisible,
                onToggleFavoriteClick: widget.onToggleFavoriteClick,
                showFavoriteAction: widget.showFavoriteAction,
                favoriteAsHoverAction: compact,
                keepFavoriteActionInCompact: widget.keepFavoriteActionInCompact,
                keepAddToActionInCompact: widget.keepAddToActionInCompact,
                favoriteLoading: widget.favoriteLoading,
                favoriteHoverVisible: hoverActionsVisible,
                addMenuActive: _menuPin == _PlaylistControlMenuPin.addTo,
                moreMenuActive: _menuPin == _PlaylistControlMenuPin.more,
                onAddToPlaylistClick:
                    widget.onAddToPlaylistClick == null
                        ? null
                        : (buttonContext) {
                          unawaited(
                            _openPinnedMenu(
                              _PlaylistControlMenuPin.addTo,
                              () => widget.onAddToPlaylistClick!(buttonContext),
                            ),
                          );
                        },
                onPlayNextClick: widget.onPlayNextClick,
                onRemoveFromListClick: widget.onRemoveFromListClick,
                onOpenContextMenu: (position) {
                  unawaited(
                    _openPinnedMenu(
                      _PlaylistControlMenuPin.more,
                      () => widget.onOpenContextMenu(position),
                    ),
                  );
                },
                colors: colors,
                customColors: widget.colors != null,
                compactCollapsed: compactCollapsed,
                showCompactPrimaryActions:
                    compact || widget.showCompactPrimaryActions,
              );
            }

            Widget duration() {
              return _QueueDuration(
                song: widget.song,
                current: widget.current,
                compactVariant: compactVariant && compact,
                width: durationWidth,
                colors: colors,
              );
            }

            final rowContent = Padding(
              padding: rowPadding,
              child: Row(
                children: [
                  if (compactVariant)
                    SizedBox(
                      width: 58,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: artwork,
                      ),
                    )
                  else
                    artwork,
                  SizedBox(width: artworkGap),
                  Expanded(
                    flex: compact ? 1 : 12,
                    child: Transform.translate(
                      offset:
                          compactVariant ? const Offset(0, 0.83) : Offset.zero,
                      child: _QueueCopy(
                        song: widget.song,
                        searchQuery: widget.searchQuery,
                        current: widget.current,
                        showAlbum: widget.showAlbum && compact,
                        compactVariant: compactVariant,
                        onSeeAlbum: widget.onSeeAlbum,
                        onSeeArtist: widget.onSeeArtist,
                        colors: colors,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 170),
                      child:
                          showInlineActions
                              ? Center(
                                child: queueActions(compactCollapsed: false),
                              )
                              : null,
                    ),
                  ],
                  if (!compact && hasAlbumColumn) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 7,
                      child: _QueueMetadataLink(
                        key: const ValueKey('PlaylistControlItem.AlbumColumn'),
                        text: displayAlbum(widget.song, i18n),
                        searchQuery: widget.searchQuery,
                        foregroundColor:
                            widget.current
                                ? colors.currentMuted
                                : colors.textMuted,
                        hoverColor: colors.currentForeground,
                        onTap: widget.onSeeAlbum,
                      ),
                    ),
                  ],
                  SizedBox(width: compact ? 12 : 18),
                  duration(),
                ],
              ),
            );
            if (!compact || !showInlineActions) {
              return rowContent;
            }
            final overlayMaskColor = Color.alphaBlend(
              rowBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor,
            );
            return Stack(
              children: [
                rowContent,
                Positioned(
                  top: baseRowPadding.top,
                  right: baseRowPadding.right,
                  bottom: baseRowPadding.bottom,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      end: hoverActionsVisible ? overlayActionsWidth : 0,
                    ),
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: SizedBox(
                      width: overlayActionsWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              overlayMaskColor.withValues(alpha: 0),
                              overlayMaskColor,
                              overlayMaskColor,
                            ],
                            stops: [0, 28 / overlayActionsWidth, 1],
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: queueActions(compactCollapsed: false),
                        ),
                      ),
                    ),
                    builder:
                        (context, width, child) => IgnorePointer(
                          ignoring: !hoverActionsVisible,
                          child: SizedBox(
                            width: width,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.centerRight,
                                minWidth: overlayActionsWidth,
                                maxWidth: overlayActionsWidth,
                                child: child,
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final neutralSwipeBackground =
        dark ? const Color(0xff26384a) : const Color(0xffdbe8f2);
    final alternateSwipeBackground =
        dark ? const Color(0xff1f2f40) : const Color(0xffcdddea);
    final neutralSwipeForeground =
        dark
            ? const Color(0xfff4f8fc)
            : _PlaylistControlItemColors.accentStrong;
    final favoriteSwipeLabel = i18n.t(
      widget.song.favorite ? 'context.removeFavorite' : 'context.addFavorite',
    );
    final addToLabel =
        widget.addToPlaylistLabel ?? i18n.t('context.addToPlaylist');
    final playNextLabel = widget.playNextLabel ?? i18n.t('context.playNext');
    final removeLabel = widget.removeLabel ?? i18n.t('nowPlaying.remove');
    final moreLabel = widget.moreLabel ?? i18n.t('player.more');
    final startSwipeActions = <Widget>[
      if (_showFavoriteSwipeAction)
        _QueueSwipeAction(
          label: favoriteSwipeLabel,
          icon: Icon(
            widget.song.favorite
                ? FluentIcons.heart_20_filled
                : FluentIcons.heart_20_regular,
            size: 19,
          ),
          foregroundColor: Colors.white,
          backgroundColor: _PlaylistControlItemColors.favorite,
          toggled: widget.song.favorite,
          onPressed: () {
            _resetSwipe();
            widget.onToggleFavoriteClick!();
          },
        ),
      if (widget.onAddToPlaylistClick != null)
        Builder(
          builder:
              (buttonContext) => _QueueSwipeAction(
                label: addToLabel,
                icon: const Icon(FluentIcons.add_20_regular, size: 20),
                foregroundColor: neutralSwipeForeground,
                backgroundColor: neutralSwipeBackground,
                active: _menuPin == _PlaylistControlMenuPin.addTo,
                onPressed: () {
                  unawaited(
                    _openSwipePinnedMenu(
                      _PlaylistControlMenuPin.addTo,
                      () => widget.onAddToPlaylistClick!(buttonContext),
                    ),
                  );
                },
              ),
        ),
    ];
    final endSwipeActions = <Widget>[
      if (widget.onPlayNextClick != null)
        _QueueSwipeAction(
          label: playNextLabel,
          icon: const SmPlayerPlayNextIcon(size: 19),
          foregroundColor: neutralSwipeForeground,
          backgroundColor: neutralSwipeBackground,
          onPressed: () {
            _resetSwipe();
            widget.onPlayNextClick!();
          },
        ),
      Builder(
        builder:
            (buttonContext) => _QueueSwipeAction(
              label: moreLabel,
              icon: const SmPlayerMoreHorizontalIcon(size: 20),
              foregroundColor: neutralSwipeForeground,
              backgroundColor: alternateSwipeBackground,
              active: _menuPin == _PlaylistControlMenuPin.more,
              onPressed: () {
                final box = buttonContext.findRenderObject() as RenderBox;
                final offset = box.localToGlobal(
                  Offset(0, box.size.height + 8),
                );
                unawaited(
                  _openSwipePinnedMenu(
                    _PlaylistControlMenuPin.more,
                    () => widget.onOpenContextMenu(offset),
                  ),
                );
              },
            ),
      ),
      if (widget.onRemoveFromListClick != null)
        _QueueSwipeAction(
          label: removeLabel,
          icon: const Icon(FluentIcons.dismiss_20_regular, size: 20),
          foregroundColor: Colors.white,
          backgroundColor: _PlaylistControlItemColors.destructive,
          onPressed: () {
            _resetSwipe();
            widget.onRemoveFromListClick!();
          },
        ),
    ];
    final row = MouseRegion(
      opaque: false,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Listener(
        onPointerDown: (event) {
          if (!identical(_openPlaylistSwipeOwner.value, _swipeOwner)) {
            _openPlaylistSwipeOwner.value = null;
          }
          _pointerKind = event.kind;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart:
              _swipeConfigured
                  ? (details) {
                    _pointerKind = details.kind;
                    _swipeDragDirection = _swipeOffset.sign.toInt();
                  }
                  : null,
          onHorizontalDragUpdate: _swipeConfigured ? _updateSwipe : null,
          onHorizontalDragEnd:
              _swipeConfigured
                  ? (_) {
                    _settleSwipe();
                  }
                  : null,
          onHorizontalDragCancel: _swipeConfigured ? _resetSwipe : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: rowHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: _swipeOffset >= 0,
                      child: AnimatedOpacity(
                        opacity: _swipeOffset < 0 ? 1 : 0,
                        duration:
                            disableAnimations
                                ? Duration.zero
                                : const Duration(milliseconds: 90),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _QueueSwipeActionRail(
                            width: _endSwipeExtent,
                            actions: endSwipeActions,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: _swipeOffset <= 0,
                      child: AnimatedOpacity(
                        opacity: _swipeOffset > 0 ? 1 : 0,
                        duration:
                            disableAnimations
                                ? Duration.zero
                                : const Duration(milliseconds: 90),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _QueueSwipeActionRail(
                            width: _startSwipeExtent,
                            actions: startSwipeActions,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: _swipeOffset),
                    duration:
                        disableAnimations
                            ? Duration.zero
                            : _swipeDragDirection == 0
                            ? const Duration(milliseconds: 170)
                            : Duration.zero,
                    curve: Curves.easeOut,
                    builder:
                        (context, offset, child) => Transform.translate(
                          offset: Offset(offset * _physicalSwipeDirection, 0),
                          child: child,
                        ),
                    child: content,
                  ),
                  if (dropPosition != null)
                    Positioned(
                      left: compactVariant || narrowRow ? 8 : 18,
                      right: compactVariant || narrowRow ? 10 : 22,
                      top:
                          dropPosition == PlaylistControlDropPosition.before
                              ? 0
                              : null,
                      bottom:
                          dropPosition == PlaylistControlDropPosition.after
                              ? 0
                              : null,
                      child: const _QueueDropIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      child: MouseRegion(
        opaque: false,
        cursor: SystemMouseCursors.click,
        child: row,
      ),
    );
  }
}
