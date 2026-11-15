import 'library_scope_access.dart';
import 'library_query_failure.dart';
import 'package:smplayer_flutter/src/library/ui/library_load_failure.dart';
import 'package:smplayer_flutter/src/remote/music_share_access.dart';
import '../../remote/music_source_providers.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_interaction_colors.dart';
import '../../app/app_surface_colors.dart';
import '../../app/auto_hide_scrollbar_visibility.dart';
import '../../app/loading_state.dart';
import '../../app/smplayer_vector_icons.dart';
import '../../app/undoable_notification.dart';
import '../../app/workspace_app_bar_portal.dart';
import '../../i18n/app_i18n.dart';
import '../../playback/media_control_provider.dart';
import '../../playback/playback_queue_actions.dart';
import '../../playback/playing_wave.dart';
import '../data/library_models.dart';
import '../data/library_time_codec.dart';
import '../data/library_providers.dart';
import 'artwork_floating_action_button.dart';
import 'artists_page_model.dart' show getSongArtists;
import 'command_bar.dart';
import 'menu_flyout.dart';
import 'menu_flyout_helpers.dart';
import 'headered_playlist_model.dart' show getNextPlaylistName;
import 'library_page_actions.dart';
import 'music_dialog.dart';
import 'multi_select_command_bar.dart';
import 'page_selection_store.dart';
import 'quick_jump_tooltip.dart';
import 'song_display_helpers.dart' as song_display;
import 'song_artwork.dart';
import '../../platform/desktop_feature_service.dart';

part 'music_library_layout.dart';
part 'music_library_actions.dart';
part 'music_library_table.dart';
part 'music_library_table_rows.dart';
part 'music_library_row_overlays.dart';
part 'music_library_rows.dart';
part 'music_library_sort_bar.dart';
part 'music_library_quick_jump.dart';
part 'music_library_helpers.dart';

const _quickJumpKeys = [
  '#',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];
const _wideVirtualRowHeight = 58.0;
const _compactVirtualRowHeight = 76.0;
const _minColumnWidth = 86.0;

enum _LibraryColumn {
  artwork,
  title,
  artist,
  album,
  duration,
  favorite,
  playCount,
  dateAdded,
}

const _defaultColumnWidths = {
  _LibraryColumn.artwork: 66.0,
  _LibraryColumn.title: 280.0,
  _LibraryColumn.artist: 200.0,
  _LibraryColumn.album: 240.0,
  _LibraryColumn.duration: 110.0,
  _LibraryColumn.favorite: 96.0,
  _LibraryColumn.playCount: 120.0,
  _LibraryColumn.dateAdded: 170.0,
};

class MusicLibraryPage extends ConsumerStatefulWidget {
  const MusicLibraryPage({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  ConsumerState<MusicLibraryPage> createState() => _MusicLibraryPageState();
}

class _MusicLibraryPageState extends ConsumerState<MusicLibraryPage> {
  LibraryDataQuery get _pageQuery => LibraryDataQuery(
    LibraryQueryKind.songs,
    limit: 200,
    text: widget.searchQuery,
    substringSearch: true,
    order: _sortCriterion,
    descending: _sortDirection == MusicLibrarySortDirection.descending,
  );

  var _sortCriterion = MusicLibrarySortCriterion.title;
  var _snapshotSortCriterion = MusicLibrarySortCriterion.title;
  var _sortDirection = MusicLibrarySortDirection.ascending;
  var _quickJumpPanelOpen = false;
  String? _quickJumpPinnedKey;
  var _scrollOffset = 0.0;
  var _compactLayout = false;
  final _columnWidths = {..._defaultColumnWidths};
  final _scrollController = ScrollController();
  final _selection = PageSelectionController<int>.stored('music-library');
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;
  MusicDialogEntry? _musicDialog;
  LibraryDataQuery? _accessedPageQuery;
  (LibraryDataQuery, int)? _lastAnchor;
  Future<List<int>>? _scopeRead;
  LibraryDataQuery? _scopeReadQuery;

  @override
  void initState() {
    super.initState();
    _appBarPortalNotifier = ref.read(workspaceAppBarPortalProvider.notifier);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant MusicLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _selection.clearSelection();
    }
  }

  @override
  void dispose() {
    _clearAppBarPortalOwner();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _clearAppBarPortalOwner() {
    clearWorkspaceAppBarPortalOwnerAfterDispose(
      _appBarPortalNotifier,
      _appBarPortalOwner,
    );
  }

  void _syncAppBarPortal({
    required bool showPortal,
    required String routePath,
    required String title,
    required bool quickJumpActive,
    required bool multiSelect,
    required String multiSelectLabel,
    required String exitMultiSelectTooltip,
  }) {
    final signature =
        '$showPortal:$routePath:$title:$quickJumpActive:$multiSelect';
    if (_appBarPortalSignature == signature) {
      return;
    }
    _appBarPortalSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final notifier = ref.read(workspaceAppBarPortalProvider.notifier);
      if (!showPortal) {
        if (notifier.state?.owner == _appBarPortalOwner) {
          notifier.state = null;
        }
        return;
      }
      notifier.state = WorkspaceAppBarPortalEntry(
        owner: _appBarPortalOwner,
        routePath: routePath,
        title: title,
        content: CommandBar(
          style: CommandBarStyleVariant.appBar,
          dynamicOverflow: false,
          children: [
            CommandBarButton(
              key: const ValueKey('MusicLibrary.MultiSelectToggle'),
              icon: FluentIcons.multiselect_ltr_24_regular,
              label: multiSelectLabel,
              showLabel: false,
              active: multiSelect,
              activeMatchesHover: true,
              tooltip: multiSelect ? exitMultiSelectTooltip : multiSelectLabel,
              canOverflow: false,
              minWidth: 40,
              maxWidth: 40,
              horizontalPadding: 0,
              onPressed: () {
                setState(() {
                  _quickJumpPanelOpen = false;
                  _selection.toggleMultiSelect();
                });
              },
            ),
            CommandBarButton(
              key: const ValueKey('MusicLibrary.QuickJumpToggle'),
              label: '#-Z',
              active: quickJumpActive,
              canOverflow: false,
              minWidth: 40,
              maxWidth: 40,
              horizontalPadding: 0,
              onPressed: () {
                setState(() {
                  _quickJumpPanelOpen = !_quickJumpPanelOpen;
                });
              },
            ),
          ],
        ),
      );
    });
  }

  void _updateLibraryState(VoidCallback action) => setState(action);

  @override
  Widget build(BuildContext context) => _buildLibraryPage(context);
}
