import 'headered_playlist_control.dart';
import 'library_scope_access.dart';
import 'package:smplayer_flutter/src/remote/music_source_selector.dart';
import '../../playback/source_group_play.dart';
import 'package:smplayer_flutter/src/library/ui/library_load_failure.dart';
import '../../remote/music_source_providers.dart';
import '../../remote/music_share_access.dart' show canEditPlaylist;
import 'dart:async';
import 'dart:math';
import 'dart:ui' show ColorFilter, ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_interaction_colors.dart';
import '../../app/auto_hide_scrollbar_visibility.dart';
import '../../app/loading_state.dart';
import '../../app/input_dialog.dart';
import '../../app/shell_models.dart';
import '../../app/smplayer_vector_icons.dart';
import '../../app/undoable_notification.dart';
import '../../app/workspace_app_bar_portal.dart';
import '../../i18n/app_i18n.dart';
import '../../playback/media_control_provider.dart';
import '../../playback/media_control_model.dart'
    show PlaybackMode, shufflePlaybackQueueForCurrentTrack;
import '../../playback/playback_queue_actions.dart';
import '../../playback/playlist_control.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'album_tile.dart' show getAlbumArtworkSong;
import 'artists_page_model.dart';
import 'artists_navigation_provider.dart';
import 'artwork_floating_action_button.dart';
import 'command_bar.dart';
import 'menu_flyout.dart';
import 'menu_flyout_helpers.dart';
import 'multi_select_command_bar.dart';
import 'library_page_actions.dart';
import 'music_dialog.dart';
import 'page_selection_store.dart';
import 'page_search_history_panel.dart';
import 'song_artwork.dart';
import '../../platform/desktop_feature_service.dart';
import 'quick_jump_tooltip.dart';
import 'quick_jump_rail_column.dart';

part 'artists_master_detail.dart';
part 'artist_list_item.dart';
part 'artist_list_artwork.dart';
part 'artists_detail.dart';
part 'artist_detail_header_delegate.dart';
part 'artist_detail_header.dart';
part 'artist_detail_compact_command_row.dart';
part 'artist_header_action_button_style.dart';
part 'artist_album_sliver_section.dart';
part 'artist_album_song_row_shell.dart';
part 'artist_album_song_list_top_border_painter.dart';
part 'artists_page_state_helpers.dart';
part 'artists_page_playback_actions.dart';
part 'artists_master_metrics.dart';
part 'compact_artists_page.dart';
part 'artists_master.dart';
part 'artist_quick_jump.dart';
part 'artists_loading_master.dart';
part 'artists_detail_loading_state.dart';
part 'artists_custom_scrollbar.dart';
part 'artists_page_panel.dart';
part 'artists_empty_state.dart';
part 'artists_app_bar_search_actions.dart';
part 'artists_search_box.dart';
part 'artist_album_header.dart';
part 'artist_album_title_link.dart';
part 'album_artwork.dart';
part 'artists_colors.dart';
part 'artists_page_actions.dart';
part 'artists_page_browse_history.dart';
part 'artists_page_data.dart';
part 'artists_page_content.dart';
part 'artists_summary_format.dart';

const _artistsBackdropSaturate120 = ColorFilter.matrix([
  1.1574,
  -0.143,
  -0.0144,
  0,
  0,
  -0.0426,
  1.057,
  -0.0144,
  0,
  0,
  -0.0426,
  -0.143,
  1.1856,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

class ArtistsPage extends ConsumerStatefulWidget {
  const ArtistsPage({super.key, this.searchQuery = '', this.targetArtistName});

  final String searchQuery;
  final String? targetArtistName;

  @override
  ConsumerState<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends ConsumerState<ArtistsPage> {
  var _artistSearch = '';
  var _artistSearchFocused = false;
  var _appBarSearchOpen = false;
  String? _selectionSource;
  String? _detailArtistSource;
  var _selectedArtistName = '';
  var _artistSortCriterion = ArtistSortCriterion.name;
  var _reverseArtistDisplayOrder = false;
  String? _appliedTargetArtistName;
  String? _pendingOpenedArtistRoute;
  String? _notifiedMissingTargetArtistName;
  String? _locatedArtistName;
  String? _recordedBrowseArtistName;
  var _locateArtistPulse = 0;
  var _artistScrollTop = 0.0;
  String? _artistQuickJumpPinnedKey;
  var _artistQuickJumpJumping = false;
  final _selection = PageSelectionController<int>.stored('artists');
  final _artistListController = ScrollController();
  final _artistDetailController = ScrollController();
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;
  MusicDialogEntry? _musicDialog;

  @override
  void initState() {
    super.initState();
    _appBarPortalNotifier = ref.read(workspaceAppBarPortalProvider.notifier);
    _artistListController.addListener(_handleArtistListScroll);
  }

  @override
  void didUpdateWidget(ArtistsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetArtistName != widget.targetArtistName) {
      if (widget.targetArtistName == _pendingOpenedArtistRoute) {
        _appliedTargetArtistName = widget.targetArtistName;
        _selectedArtistName = widget.targetArtistName ?? '';
        _pendingOpenedArtistRoute = null;
      } else {
        _appliedTargetArtistName = null;
        _pendingOpenedArtistRoute = null;
      }
      _notifiedMissingTargetArtistName = null;
      if (widget.targetArtistName == null) {
        _selectedArtistName = '';
      }
    }
  }

  @override
  void dispose() {
    _clearAppBarPortalOwner();
    _artistListController.removeListener(_handleArtistListScroll);
    _artistListController.dispose();
    _artistDetailController.dispose();
    super.dispose();
  }

  void _syncAppBarPortal({
    required bool showPortal,
    required String routePath,
    required Widget content,
    required String compactTitle,
    String? titleTooltip,
    required String layoutSignature,
    required int searchSuggestionCount,
    required int searchHistoryCount,
    Widget? bottomContent,
  }) {
    _syncArtistsAppBarPortal(
      this,
      showPortal: showPortal,
      routePath: routePath,
      content: content,
      compactTitle: compactTitle,
      titleTooltip: titleTooltip,
      layoutSignature: layoutSignature,
      searchSuggestionCount: searchSuggestionCount,
      searchHistoryCount: searchHistoryCount,
      bottomContent: bottomContent,
    );
  }

  @override
  Widget build(BuildContext context) => _buildArtistsPage(context);
}

enum _ArtistGroupMenuType { artist, album }
