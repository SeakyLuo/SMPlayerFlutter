# PlaylistControlItem Acceptance Matrix

Electron is the only source of truth for behavior and content in this matrix.
The user constraint for this target is that existing Flutter components may be
reused and visual styling does not need to be pixel-identical to Electron. Style
items below are acceptance requirements only when they affect content,
discoverability, layout order, state, or interaction behavior.

## Evidence Scope

Electron source:

- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/PlaylistControlItem.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/now-playing.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/headered-playlist.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/artists.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/local-table.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/NowPlayingPage.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/NowPlayingFullPlaylist.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/HeaderedPlaylistControl.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/SearchPage.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/ArtistsPage.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalGridContent.tsx`

Flutter corresponding source:

- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/playback/playlist_control_item.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/playback/playlist_control_item_overlays.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/playback/now_playing_page.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/playback/now_playing_full_page.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/headered_playlist_layout.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/search_page.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/artists_detail.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_grid_content.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/test/playlist_control_item_test.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/test/playlist_control_item_visual_verify_test.dart`

## Acceptance Rules

- Do not add content, actions, fallback behavior, or user-visible debug data
  unless Electron has the same behavior.
- Existing Flutter visual components can be reused. Pixel-perfect shadows,
  colors, border radii, and animation curves are not required unless a row below
  marks them as a content/state/discoverability requirement.
- Every click/tap/key/menu/drag behavior must map to an Electron prop, handler,
  or calling-page flow.
- If a calling page omits a callback in Electron, Flutter should omit or disable
  the corresponding user action instead of inventing one.
- Raw IDs must not be shown. Song IDs may only be used internally for callbacks,
  selection, queue construction, keys, and tests.

## Phase 1 Development Target

This phase aligns the shared component contract before page-specific queue
flows:

| Item | Electron rule | Flutter target | Status |
|---|---|---|---|
| More/context menu | `onContextMenu` is required and the More action is always rendered. Row secondary click and More both call the same menu entry with the pointer/action anchor. | `PlaylistControlItem.onOpenContextMenu` is required; right-click and More call it without nullable fallback. | Implemented and covered by `PlaylistControlItem keeps Electron required More action and optional Play Next`. |
| Play Next action | `onPlayNextClick` is optional; the action only renders when the caller provides it. | `PlaylistControlItem.onPlayNextClick` is optional and `_QueueActions` hides Play Next when absent. | Implemented and covered by the same widget test. |
| Existing page callbacks | Electron page call sites decide whether Add To, Favorite, Play Next, Remove, artist, album, and queue actions exist. | Existing Flutter page call sites keep their current callbacks; this phase does not add page-specific actions. | Verified by targeted analyze and `playlist_control_item_test.dart`. |

## Reuse Surface Matrix

| Surface | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Now Playing page queue | `NowPlayingPage` renders virtualized queue rows with `PlaylistControlItem`; current row can be tracked by `containerRef`; row uses queue index when selected queue index is available. | Now Playing queue rows reuse Flutter `PlaylistControlItem` and preserve current/playing/selection/queue-index semantics. | Queue row click plays the correct track and queue; current row state follows selected track or queue index. | Covered indirectly by NowPlaying tests; dedicated queue-index/current test may be added if behavior changes. |
| Now Playing full playlist | Full playlist uses `playlist-control-compact`, supports drag reorder, touch reorder, remove undo, Add To, context menu, artist/album navigation, and close-after-navigation behavior. | Full playlist compact rows reuse `PlaylistControlItem` and keep the same queue mutation, undo, menu, and navigation side effects. | Drag/touch reorder changes queue order; remove shows undo; artist/album clicks navigate and close the full playlist route when Electron does. | Partially covered by existing playback tests; touch reorder needs explicit coverage if not already present. |
| Headered playlist lists | `HeaderedPlaylistControl` renders headered rows with `draggable=false`, optional album column, favorite toggle, Add To, Play Next, context menu, and selection mode. | Album/detail/playlist/favorites pages reuse `PlaylistControlItem.headeredPlaylist` and keep callbacks exactly as Electron page supplies them. | Row actions use headered playlist callbacks; album column appears only when `showAlbum` is true; favorites pending state disables/shows loading for favorite action. | Covered by `album_detail_page_test.dart` and `playlist_control_item_test.dart` duration/action metrics. |
| Search songs | Search song results render `PlaylistControlItem` with `draggable=false`, `showAlbum`, favorite, Add To, Play Next, song menu, artist route, and album route. | Search page rows expose the same actions and routes, without local queue reorder behavior. | Search row play uses the search queue; Add To opens at action anchor; artist/album clicks route to the matching page. | Covered by `search_page_test.dart` for variant; route/action coverage should be checked before claiming complete. |
| Artists page album song list | Artist album song rows render inside `playlist-control-compact`, set `showAlbum=false`, use selected artist queue IDs, and route artist/album clicks through the artist route helpers. | Artist detail/list song rows reuse compact `PlaylistControlItem`; album inline content is hidden when `showAlbum=false`. | Song row title/artists show; album column/inline album is absent; row queue is the selected artist song queue; Add To/Play Next/context menu work. | Covered by ArtistsPage PlaylistControlItem action tests and artist separator tests. |
| Local compact songs/tree songs | Local compact layout renders direct songs and compact tree songs with `PlaylistControlItem`, `showAlbum`, optional `openQueueSongIds` for direct folder rows, and local Add/PlayNext/context behavior. | Local compact rows reuse `PlaylistControlItem`; direct-folder row open queue can differ from displayed queue when Electron passes `openQueueSongIds`. | Direct song click plays with folder queue; compact tree song click plays with tree/local queue; local song menus target local actions. | Covered by Local compact/list tests in `local_page_test.dart`; add direct `openQueueSongIds` coverage if changed. |

## Content And Rendering Matrix

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Required inputs | Component requires `song`, translator, `current`, `playing`, `selected`, `selectionMode`, `dropPosition`, `queueSongIds`, `onPlayTrack`, `onToggleSelection`, and `onContextMenu`. Optional callbacks control optional actions. | Flutter widget props should mirror these behavior gates; no action appears just because Flutter has a generic control. | Instantiate rows with each optional callback omitted and verify corresponding action is absent while required row behavior remains. | Existing widget tests cover many optional actions; callback omission matrix still needs complete coverage. |
| Song title | Title is `song.title`, rendered as the primary text and used as title/tooltip in Electron. | Flutter row primary text is the song title, single-line/truncated if needed, no IDs or path shown. | Long title truncates; title text is present; song ID/path is absent. | Covered indirectly by widget/page tests; add no-ID assertion if needed. |
| Artists | Artists come from `getSongArtists(song, t('common.artistUnknown'))`, joined with `t('common.artistSeparator')`; each artist is a clickable button. | Flutter must use the same artist extraction, unknown fallback, localized separator, and artist click callback. | Multi-artist song shows localized separator; unknown artist shows localized unknown; clicking an artist calls/routes with that artist. | Covered by ArtistsPage artist separator tests; base widget artist click should remain covered. |
| Album label | Album label is `song.album || t('common.albumUnknown')`. | Flutter uses localized unknown album fallback and never exposes empty/null/raw values. | Empty album displays unknown album; album click routes/calls with fallback label where Electron does. | Covered in several page tests; keep direct widget coverage for fallback. |
| Artist/album combined label | Electron builds `artistAlbumLabel` for tooltip; when `showAlbum` is true inline metadata combines artists, bullet separator, and album. | Flutter compact metadata uses the same semantic content and separator; exact typography can reuse existing text widgets. | With `showAlbum=true`, metadata contains artist separator and album separator; with `showAlbum=false`, album content is absent. | `PlaylistControlItem metadata uses Electron album separator` exists; `showAlbum=false` is covered in Artists tests. |
| Artwork | Electron loads `useSongArtwork(song.id, song.artworkUrl)`, refreshes on image error, and renders `DefaultAlbumArtwork` fallback. | Flutter can reuse existing artwork resolver/default artwork, but must show song artwork when available and default artwork when missing/error. | Valid artwork renders; missing/broken artwork renders default album artwork; no raw artwork URL is shown. | Visual and widget tests cover default artwork; image-error refresh parity should be checked before claiming complete. |
| Current/playing overlay | If row is current and not in selection mode, Electron shows a centered playing overlay with a four-bar wave. Wave animates only when `current && playing`; paused current row has static bars. | Flutter keeps the current/playing indication visible and uses existing overlay implementation; animation/static state must match. | Current playing row shows animated wave; current paused row shows static bars; selection mode hides playing overlay. | Covered by `PlaylistControlItem animates current playing wave like Electron`, `keeps current paused wave static`, and hover overlay tests. |
| Selection mark | In selection mode, Electron shows a select mark over artwork; selected rows show a check. | Flutter selection mode shows an equivalent mark and check state, and suppresses normal artwork play overlay. | Selection mode selected/unselected rows show correct mark; normal play overlay is absent. | Existing tests cover selection behavior indirectly; add direct mark test if needed. |
| Duration | Electron displays `formatDuration(song.duration)` in a trailing `time` element with tabular numerals. Width changes by variant/container: desktop rows use wider duration column; compact/narrow rows use narrow duration column. | Flutter uses the same formatter and keeps duration one-line in the correct trailing slot. | Durations like `3:47` stay one line; desktop/headered wide width and compact/narrow width match semantic layout targets. | Covered by multiple `PlaylistControlItem ... duration mirrors Electron ...` tests. |
| Album column | With `showAlbum=true`, Electron can show a separate album button on wide rows; on narrower rows it hides separate album and shows inline album. With `showAlbum=false`, album is not shown. | Flutter must preserve visible/hidden album semantics, but may reuse existing layout components. | Wide `showAlbum=true` has album action; narrow `showAlbum=true` has inline album; `showAlbum=false` has no album text/action. | Partially covered by page tests; add direct width-specific album visibility checks if needed. |

## Interaction Matrix

| Interaction | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Row click | If `selectionMode` is false, row click calls `onPlayTrack(song.id, openQueueSongIds ?? queueSongIds)`. If `selectionMode` is true, row click calls `onToggleSelection()`. | Flutter row activation follows the same mode switch and open-queue override. | Normal row click plays song with expected queue; selection row click toggles selection; direct Local compact row honors `openQueueSongIds`. | Keyboard activation and selection are covered; explicit `openQueueSongIds` should be kept covered. |
| Keyboard activation | Electron row has `role="button"`, `tabIndex=0`; Enter and Space prevent default and call the same open behavior. | Flutter row remains keyboard accessible and Enter/Space match click behavior. | Focus row, press Enter and Space, verify same play/selection action. | `PlaylistControlItem activates with keyboard like Electron` covers Enter; Space should remain covered if not already. |
| Artwork play button | Outside selection mode, artwork overlay button calls pause when current+playing and `onTogglePlayPause` exists; otherwise plays `song.id` with `queueSongIds`. It stops row click propagation. | Flutter artwork play/pause button follows the same decision tree and does not also activate the row. | Current playing artwork click pauses; non-current artwork click plays with row queue; row click count does not double. | Covered by overlay tests and playback tests; double-propagation coverage should be preserved. |
| Context menu | Right-click row calls `onContextMenu(song, event.clientX, event.clientY)` and prevents browser default. More action calls the same callback at button `rect.left`, `rect.bottom + 8`. | Flutter right-click/secondary tap and More action both open the song menu at the user/action anchor. | Secondary click passes pointer position; More passes button anchor; no default menu or duplicate row activation. | `PlaylistControlItem keeps Electron required More action and optional Play Next` covers required More; add anchor-position tests if menu placement changes. |
| Favorite action | Favorite action only exists when `onToggleFavorite` is provided. It toggles `!song.favorite`, can show loading with `favoriteLoading`, and is disabled while loading. | Flutter favorite action appears only when callback is supplied, shows active/loading state, and calls with toggled value/semantic equivalent. | Favorite absent without callback; active favorite visible; loading disables action; click toggles favorite. | Covered by action/night/favorites tests; callback omission coverage should be verified. |
| Add To action | Add To action only exists when `onAddToPlaylistClick` is provided. Click stops propagation and passes song plus button anchor. | Flutter Add To action appears only with callback and opens menu at action anchor. | Button absent without callback; click opens Add To for exactly this song at the action position. | Covered by action tests; anchor exactness should be checked if menu placement changes. |
| Play Next action | Play Next action only exists when `onPlayNextClick` is provided. Click stops propagation and passes song. | Flutter Play Next action appears only with callback and calls the supplied song action. | Button absent without callback; click inserts/calls song exactly once; row play is not triggered. | `PlaylistControlItem play next action uses Electron icon`, `PlaylistControlItem keeps Electron required More action and optional Play Next`, and page tests cover behavior. |
| Remove action | Remove hover action only exists when `onRemoveFromListClick` is provided. Click stops propagation and passes song. | Flutter remove action appears only in removable queues and triggers the same undo/remove flow at the page layer. | Removable Now Playing rows show remove; non-removable rows hide it; clicking remove does not play row. | Swipe/remove tests cover parts; page undo flow should remain covered. |
| Touch swipe remove | Touch swipe starts only for touch primary pointer, outside form/button/a targets, not in selection mode, and only when remove or touch reorder exists. Left swipe beyond trigger opens remove action. Clicking while swipe is open resets or removes depending target. | Flutter touch swipe matches Electron thresholds semantically and does not conflict with row click/selection. | Touch swipe left opens remove; tapping remove deletes; tapping row while swiped closes/reset; selection mode disables swipe. | `PlaylistControlItem opens shared swipe remove action` covers swipe remove; reset/selection-mode cases need coverage if not already. |
| Touch reorder | If touch vertical movement wins axis test and `onTouchReorderStart` exists, Electron enters reorder mode and calls start/move/end/cancel callbacks. | Flutter touch reorder is supported where the page supplies reorder callbacks; absent elsewhere. | Vertical touch gesture starts reorder; move/end/cancel callbacks fire; horizontal swipe and vertical reorder do not cross-trigger. | Needs explicit coverage unless covered in full queue tests. |
| Drag reorder | Electron forwards drag start/over/leave/drop/end callbacks and uses `dropPosition` for row state. | Flutter forwards drag/drop behavior where rows are draggable/reorderable and suppresses it where Electron sets `draggable=false`. | Headered/Search/Artists rows are not draggable; queue rows drag/drop reorder; drop indicator follows before/after. | Drop indicator covered by widget tests; page drag reorder should remain covered. |
| Artist click | Artist text click stops propagation and calls `onSeeArtist(artist)` if supplied. | Flutter artist click routes/calls like the calling Electron page; absent callback should not invent navigation. | Artist click navigates on pages that pass callback; row play is not triggered. | Covered in page route tests; base widget click coverage should be kept. |
| Album click | Inline/separate album button stops propagation and calls `onSeeAlbum(song)` if supplied. | Flutter album action routes/calls like Electron and uses unknown album fallback. | Album click navigates/calls; row play is not triggered; empty album uses unknown album route/label. | Covered in several page tests; keep fallback check. |

## Responsive And State Matrix

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Desktop queue layout | Standard wide row grid includes artwork, copy, action column, optional album column, and duration. | Flutter standard variant keeps the same order and content slots. | At wide width, title/artists/actions/album/duration are all accessible in Electron order. | Standard wide duration test exists; add full slot order test if needed. |
| Container narrow layout | At container max-width 800, Electron uses compact grid, hides separate album, and shows inline album. At max-width 720 it hides favorite action. | Flutter switches to equivalent narrow behavior based on row/container width, not a guessed global page state. | At narrow width, album moves inline; favorite hidden at narrow threshold; duration remains one line. | Duration and compact action tests exist; favorite/album threshold coverage should be checked. |
| `playlist-control-compact` layout | Compact rows use 58px artwork, title copy, 76px action area and 50px duration in wide compact; at max-width 1120 actions collapse to 34px and hover/focus expands hover actions. | Flutter compact variant preserves action availability/collapse semantics; exact visual style may reuse existing actions. | Wide compact action width/centering; narrow compact collapses; hover/focus expands actions. | Covered by compact action width, centering, collapse, and hover-expansion tests. |
| Coarse pointer compact | Electron hides compact Play Next action on max-width 720 and coarse pointer. | Flutter should mirror only if platform pointer/media query information is available; otherwise mark unconfirmed. | Simulate coarse pointer or platform equivalent and verify Play Next is hidden. | Not confirmed in current Flutter tests. |
| Headered playlist wide/narrow | Headered list header and row columns follow `showAlbum`; at max-width 1120 album header/column collapses. | Flutter headered variant keeps same column semantics and duration widths. | Wide headered rows show album column and wide duration; narrow headered rows hide album column and use narrow duration. | Covered by headered duration tests and album detail tests. |
| Current state | Current row has accent semantics; current+playing adds animated wave. Current+selected has combined current/selected state. | Flutter can reuse existing selected/current styling, but state must be distinguishable and not remove content/actions. | Current row identifiable; selected row identifiable; current+selected does not lose selection or current indicators. | Current/selected tests exist in widget and page suites. |
| Hover/focus actions | Electron shows hover-only actions on hover/focus; favorite can remain always visible depending surface, and some surfaces make favorite hover-only. | Flutter preserves which actions are discoverable in each variant; style can differ. | Hover/focus reveals Add To/Play Next/Remove/More as Electron allows; actions hidden/collapsed before hover where Electron hides them. | Covered by action hover style and compact hover tests. |
| Night mode | Electron night mode changes row, hover, selected, current, text, artwork background, and action hover colors. | Flutter may reuse existing night palette, but must preserve readable content and distinct current/selected/action states. | Night mode row text/action/current/selected remain readable and state-distinct. | Covered by `PlaylistControlItem default colors follow Electron night mode`; visual screenshots exist. |
| Drop indicator | Electron before/after indicator is shown when `dropPosition` is before/after; inset differs for desktop vs compact. | Flutter shows a before/after indicator in the same state and does not show it when null. | Before and after states render at correct slot; null state absent; compact inset follows compact target. | Drop indicator tests exist for standard/desktop; compact after-state should be checked if needed. |

## Current Flutter Evidence To Keep Green

The following existing tests are useful as acceptance evidence for this target:

- `flutter test test/playlist_control_item_test.dart`
- `flutter test test/playlist_control_item_visual_verify_test.dart`
- `flutter test test/artists_page_test.dart --plain-name 'ArtistsPage song row uses PlaylistControlItem actions'`
- `flutter test test/artists_page_test.dart --plain-name 'ArtistsPage song row uses Electron artist separator'`
- `flutter test test/album_detail_page_test.dart --plain-name 'HeaderedPlaylistControl reuses Electron metrics for playlists'`
- `flutter test test/search_page_test.dart` for SearchPage row variant coverage

## Explicit Non-Goals For This Matrix

- Pixel-perfect row colors, shadows, border radius, and animation curves are not
  required by this target unless the difference hides content, changes action
  discoverability, or changes a state transition.
- The matrix does not require replacing existing Flutter artwork, icon, button,
  or menu components when they already provide the same content and behavior.
- The matrix does not approve adding fallback actions or compatibility branches
  not present in Electron. Missing Electron evidence remains unconfirmed.
