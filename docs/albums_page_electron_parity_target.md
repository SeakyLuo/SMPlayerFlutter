# AlbumsPage Electron Parity Target

This document is the acceptance target for aligning `SMPlayerFlutter` AlbumsPage with `SMPlayerElectron`.

Electron is the only source of truth for this parity task. Items without runtime evidence are marked as unconfirmed and must not be treated as complete until verified.

## Confirmed Electron Evidence

### Page And Data Flow

- `SMPlayerElectron/src/pages/AlbumsPage.tsx`
  - `AlbumsPage` owns album grouping, search, sorting, virtualized grid, quick jump, multi-select, context menus, and album-art preview.
  - Album groups are built from `songs`.
  - Local route opens album detail as `/albums?album={encodedAlbum}`.
  - Data-source route opens album detail as `{routeBase}/albums/{encodedAlbum}`.
- `SMPlayerElectron/src/pages/LibraryDataSourceAlbumsPage.tsx`
  - Remote/data-source albums reuse `AlbumsPage`.
  - Remote/data-source page passes `recentSearches={[]}`.
  - Remote/data-source page uses no-op search removal and no-op `onRecordAlbumPlayed`.
- `SMPlayerElectron/src/AppRoutes.tsx`
  - Local `/albums` renders `AlbumDetailRoute` when query param `album` exists.
  - Otherwise local `/albums` renders `AlbumsPage`.
- `SMPlayerElectron/src/AppRouteComponents.tsx`
  - `AlbumDetailRoute` filters songs by `(song.album || t('common.albumUnknown')) === routeAlbumName`.

### Shared Components

- `SMPlayerElectron/src/components/AlbumTile.tsx`
  - Shared album tile used by AlbumsPage and search/recent surfaces.
  - Tile click opens album unless multi-select mode is active.
  - Hover actions expose play and add buttons.
  - Right click opens the page-provided context menu.
- `SMPlayerElectron/src/components/AlbumArtControl.tsx`
  - Uses song artwork through `useSongArtwork`.
  - Falls back to `DefaultAlbumArtwork`.
- `SMPlayerElectron/src/components/DefaultAlbumArtwork.tsx`
  - Uses shared default album artwork asset.
- `SMPlayerElectron/src/components/CommandBar.tsx`
  - Albums toolbar uses shared UWP-style command bar.
  - Overflowed command buttons move into a shared `MenuFlyout`.
- `SMPlayerElectron/src/components/AppBarPortal.tsx`
  - Albums page contributes appbar search and sort actions through portals.
- `SMPlayerElectron/src/components/MultiSelectCommandBar.tsx`
  - Albums page uses shared bottom multi-select command bar.
- `SMPlayerElectron/src/components/MenuFlyoutHelper.ts`
  - Albums page uses shared Add To and Preference menu item builders.

### Styles

- `SMPlayerElectron/src/styles/albums.css`
  - Page layout, toolbar, quick jump, virtualized grid, progress bar, multi-select bar, and dark-mode rules.
- `SMPlayerElectron/src/styles/album-tile.css`
  - Album tile dimensions, artwork, copy, hover actions, selection mark, preview dialog, and dark-mode rules.
- `SMPlayerElectron/src/styles/artists.css`
  - Shared page search field and search suggestions styles used by AlbumsPage.
- `SMPlayerElectron/src/styles/appbar.css`
  - AppBar search behavior and minimal-nav layout.
- `SMPlayerElectron/src/styles/commandbar.css`
  - Shared command bar visual rules.
- `SMPlayerElectron/src/styles/sidebar-search.css`
  - Shared search history panel styles.
- `SMPlayerElectron/src/styles/menus-actions.css`
  - Shared menu flyout styles and menu positioning layer.

## Functional Matrix

| Area | Electron Rule | Acceptance Criteria |
| --- | --- | --- |
| Local data source | Local `/albums` builds album views from `snapshot.songs`. | AlbumsPage content is derived from library songs, not from a separately invented local page model. |
| Remote/data-source reuse | Remote/data-source albums reuse the same `AlbumsPage`. `recentSearches` is empty, search removal handlers are no-op, and `onRecordAlbumPlayed` is no-op. | Remote albums visually and behaviorally reuse the same album grid while not recording recent searches or recent album playback. |
| Album grouping | Group key is `song.album || t('common.albumUnknown')`. | Songs with empty album show under the localized unknown-album label. No raw ID is shown. |
| Album song ordering | Songs inside each album are sorted by `compareLocalText(left.title, right.title)`. | Playing an album queues its songs in localized title order. |
| Album artist list | Artists are collected with `getSongArtists(song, t('common.artistUnknown'))`. Artist counts are sorted by count descending, then `compareLocalText`. | Card subtitle shows the highest-frequency artist; ties use localized text comparison. |
| Artwork selection | Album artwork is the first song in the album with `artworkUrl`; otherwise empty and falls back to default artwork. | Card and preview use the same selected artwork. Missing artwork shows the shared default album artwork. |
| Default artwork | `DefaultAlbumArtwork` is used inside `.album-art-control-fallback-image`; logo uses the shared 68% sizing rule. | No custom fallback artwork or different logo scale is introduced. |
| Search draft/query split | Typing updates `searchDraft`; submitting trims and commits to `searchQuery`. | Unsubmitted text only drives suggestions; committed query drives the filtered grid. |
| Search submit | Enter or search button calls `submitSearch`; non-empty query records `addRecentSearch(query, 'albums')`; result scrolls to top. | Search submission records only non-empty trimmed queries and resets scroll to top. |
| AppBar search submit | AppBar search submit also closes the AppBar search panel. | AppBar search closes after submit while page search stays in place. |
| Search matching | Search only scores `album.name`, not artist. Score order: exact, case-insensitive exact, prefix, case-insensitive prefix, contains, case-insensitive contains, query contains value, edit-distance ratio. | Artist-only keywords do not match unless the album name itself matches. Results sort by score descending. |
| Search suggestions | While focused and draft is non-empty, suggestions are `searchAlbums(albums, searchDraft).slice(0, 8)`. | At most 8 suggestions appear. Selecting one commits that album name, records search, closes focus/appbar search, and scrolls to top. |
| Search history | While focused and draft is empty, show recent entries where `entry.type === 'albums'`, limited to 10. | History panel only contains Albums search history. It supports select, remove one, and clear all visible entries. |
| Clear search | Clear button appears when `searchDraft || searchQuery`; click clears both and scrolls top. | Clearing search restores sorted full album list. |
| Sorting menu order | Sort menu options are `reverse`, `default`, `name`, `artist`. | Menu order must match Electron. |
| Sort persistence | `default`, `name`, and `artist` update `albumsSort`; `reverse` only toggles `reverseDisplayOrder`. | Reverse does not persist into settings. Other sort choices do persist. |
| Sort behavior | `artist` sorts by artist then name. `name` and `default` sort by name then artist. Unknown/default case returns original order. | Sort output follows this exact comparison chain. |
| Quick jump keys | Keys are `#ABCDEFGHIJKLMNOPQRSTUVWXYZ`. | Quick jump always renders all keys in that order. |
| Quick jump bucket | Bucket is based on album name via shared local-text quick-jump bucket. | Disabled letters have no album bucket; enabled letters jump to the first album with that bucket. |
| Quick jump active state | Active key is target key if the target row is the top row; otherwise it follows the first visible/top-row album bucket. | Active marker updates while scrolling and after clicking a quick-jump key. |
| Virtual grid columns | Column count is `floor((gridWidth + 30) / (180 + 30))`, minimum 1. | Album cards stay on 180px tracks with 30px column gap. |
| Virtual grid rows | Row height is 250 normally, 234 at `max-width: 720px`; overscan is 2 rows. | Runtime layout uses virtualized rows with Electron row heights and overscan. |
| Open album | Normal tile click navigates to album detail. | Clicking the tile surface does not play music; it opens detail. |
| Play album hover action | Hover play button records album playback and plays first song with the album queue. | Hover play uses sorted album song IDs and records local album playback where Electron does. |
| Add album hover action | Hover add button opens Add To menu at click position with all album song IDs and default playlist name equal to album name. | Add menu contains the same eligible targets as Electron. |
| Context menu open | Right click prevents browser default and opens `MenuFlyout` at pointer position. | Right click on a tile opens the album menu, not the system/browser menu. |
| Album context menu | Items are Shuffle, Add To, Select, Preference, See Album Art. | Menu item order and labels match Electron locale text. |
| Context Shuffle | Shuffle copies album song IDs, shuffles them, records album playback, then plays shuffled queue starting at first shuffled ID. | Context shuffle is not the same as hover play; it randomizes order. |
| Add To menu | Add To can include Now Playing, My Favorites, separator, New Playlist, and custom playlists. Built-in playlists are excluded from custom list. | Add To submenu eligibility and order match `getAddToPlaylistMenuFlyoutItem`. |
| Favorites eligibility | Favorites item appears only if at least one target song is not already favorite. | Fully favorited album does not show My Favorites in Add To. |
| Preference menu | Preference submenu levels are `do-not-appear`, `dislike`, `normal`, `high`, `higher`, `very-high`; current level shows check; existing preference adds Undo Prefer plus separator. | Preference menu mirrors shared helper behavior. |
| See Album Art | Context menu opens centered album-art preview dialog. | Preview dialog shows selected album artwork/fallback and album name. |
| Preview close | Clicking backdrop or close button closes preview; clicking dialog content does not close it. | Dialog close behavior matches Electron. |
| Multi-select entry | CommandBar Multi Select button sets multi-select true. | Multi-select mode starts from toolbar action, not by long press or unrelated gesture. |
| Multi-select compact behavior | If `max-width: 720px` and multi-select is active, Electron closes multi-select and clears selected names. | Narrow layout must not keep AlbumsPage multi-select active. |
| Multi-select tile click | In multi-select mode, tile click toggles selection instead of opening detail. | Selected set toggles by album name. |
| Multi-select selected albums | `selectedAlbums` is computed from visible albums only. | Bulk actions act only on selected albums that are currently visible in the filtered/sorted list. |
| Multi-select selected song IDs | Selected song IDs are flattened from selected albums' songs. | Bulk play/add uses all songs from selected visible albums. |
| Multi-select bottom bar | Actions are Cancel, Play, Add To, Select All, Invert, Clear Selection, with More menu on narrow widths. | Disabled state follows selected count. More menu contains overflowed selection actions. |
| Multi-select play | Plays first selected song ID with all selected song IDs. | Play is disabled when selected count is 0. |
| Multi-select Add To | Opens Add To menu above the action button, default playlist name is localized `common.albums`. | Add menu uses selected song IDs and hides selection after operation if setting is enabled. |
| Select all | Selects every visible album name. | Search/filter affects select-all scope. |
| Invert selection | Selects every visible album not currently selected and deselects currently selected visible albums. | Invert only considers visible albums. |
| Cancel | Cancels multi-select and clears selection. | Bottom bar disappears and selection marks clear. |
| Loading/scanning/processing | `loading || scanning || processing` shows `.albums-progress`; if visible list is empty, `LoadingState compact` is shown. | Progress strip and compact loading state match Electron states. |
| Processing delay | Search/sort operations set processing true for 180ms. | Short progress feedback appears for search/sort operations. |
| Empty no albums | With no query and no albums, show `collection.noAlbums` and `collection.scanFirst`. | Empty library text differs from search no-match text. |
| Empty no match | With query and no visible albums, show `albums.noMatch` and `albums.noMatchCopy`. | Search-empty state uses album-search copy. |
| Route memory/sidebar back | App treats `/albums?album=...` as album detail; sidebar back from album detail at depth 0 navigates to `/albums`. | Album detail navigation returns to AlbumsPage like Electron. |

## UI And Style Matrix

| Surface | Electron Style Rule | Acceptance Criteria |
| --- | --- | --- |
| Page container | `.albums-page`: `position: relative`, `height: 100%`, `padding: 0 24px`, `overflow: hidden`, transparent background. | AlbumsPage fills workspace, does not create page-level scroll, and keeps 24px horizontal padding in normal shell. |
| Toolbar | `.albums-toolbar`: display block, min-height 44px, margin-bottom 2px. | Normal shell shows top toolbar with search content and command buttons. |
| Search shell | `.albums-search-shell`: width `min(360px, 100%)`. | Search width caps at 360px. |
| CommandBar | `.uwp-commandbar`: min-height 48px, transparent, content left, primary actions right. Buttons min 44x40, margin `4px 3px`, padding `0 14px`, radius 10. | Albums toolbar uses shared command bar visual language, not custom page buttons. |
| CommandBar button active | Active button uses accent border/background and accent-strong text. | Multi Select button visibly active when multi-select mode is on. |
| Sort button | Page toolbar sort is a CommandBar button; AppBar sort is `.appbar-icon-button albums-appbar-sort-button`. | Normal and minimal shells expose sort in the same places as Electron. |
| AppBar icon button | 40x40, radius 12, transparent background; hover/focus accent tint; icon 19x19. | Minimal AppBar action icons match size and hover behavior. |
| Page search form | Grid columns `40px 1fr`; with query `40px 1fr 24px`; height 40; radius 10; subtle inset border. | Search icon, input, and clear button align to Electron dimensions. |
| Page search focus | Focus background white in light mode; accent inset border and 3px accent glow. | Focus state is visually distinct and matches Electron. |
| Search input | Font inherited, 14px, no browser search decoration/cancel button. | No native search cancel affordance appears. |
| Search submit button | 40x40, no radius, transparent base; icon 19x19; hover accent tint. | Search icon area is exactly 40px wide. |
| Search clear button | 24x24, radius 6, accent-tinted background; icon 14x14. | Clear button is compact, not a full-size icon button. |
| Suggestions panel | Absolute below search, z-index 121, padding 8, radius 14, blurred light surface, max height `min(360px, 100vh - 190px)`. | Suggestions overlay sits above page content and below menu flyouts. |
| Suggestion row | Min-height 38, radius 10, padding `5px 10px`, 14px/560 text, ellipsis. | Long album names truncate on one line. |
| Search history panel | Same absolute panel dimensions as search suggestions; header min-height 30, 12px/600 muted text, clear button on right. | Recent-search history matches shared panel. |
| Grid shell | `.albums-grid-shell`: flex, min-height 0, gap 4. | Quick jump and grid are horizontally adjacent. |
| Quick jump | Width 22, 27 equal rows, padding `12px 0 18px`. Buttons width 20, radius 5, font 10px/650. | `#ABCDEFGHIJKLMNOPQRSTUVWXYZ` fills the vertical rail. |
| Quick jump states | Enabled hover/active uses accent tint and accent-strong text. Disabled uses muted 24% color, opacity 0.62, no hover background. | Disabled keys cannot look active or clickable. |
| Grid scroll area | `.albums-grid`: overflow auto, padding `8px 8px calc(var(--player-top-radius) + 12px) 14px`, stable scrollbar gutter. | Bottom padding clears the player bar. |
| Grid window | Absolute grid, row gap 26, column gap 30, tracks 180px, `align-items: start`. | Cards align to a strict 180px grid. |
| Album tile | Width/min-width 180, min-height 232, padding 10, radius 12, transparent base. | Card footprint matches Electron. |
| Album tile hover/focus/selected | Background `var(--surface-card-hover)` and `var(--card-hover-shadow)`. | Hover and selected state share the same card surface treatment. |
| Tile surface | Grid rows `160px auto`, row gap 12, no border/background, full width. | Artwork and copy stack exactly as Electron. |
| Artwork | `.album-art-control`: 160px height, width 100%, radius 8, object-fit cover, `var(--surface-artwork)`, `var(--artwork-shadow)`. | Album art is square 160x160 inside the 180px card. |
| Fallback artwork | Fallback is centered grid, overflow hidden; default logo image is 68% by shared rule. | Missing art does not use custom text/icon unless Electron does. |
| Tile copy | Width 160, centered, single-line ellipsis. Title 15px/600/1.35; subtitle margin-top 3, 12px/400/1.35 muted. | Text never wraps or changes card width. |
| Hover actions | Absolute at left 90/top 90; grid two 48px columns; gap 10; opacity 0 by default. | Play and add buttons center over the artwork. |
| Hover action buttons | 48x48 circles, dark translucent background, white icons, blur, shadow; hover scale 1.1. | Hover actions look like Electron overlay controls. |
| Selection mode hover | `.album-tile.is-selection-mode .album-hover-actions` stays hidden. | Play/add hover controls are not visible in multi-select mode. |
| Selection mark | Absolute right 12/top 12, 18x18, radius 5, border muted; selected uses accent background and check 13x13. | Selection mark size and position match Electron. |
| Multi-select bottom bar | Fixed, left/width computed from workspace content, bottom above player bar, height 64, padding `0 18px 0 26px`, radius `17px 17px 0 0`, blur 30px. | Bottom command bar attaches to workspace and player, not page content. |
| Multi-select buttons | Height 36, min-width 72, radius 8, 13px/640, icon 16px. | Button sizing matches Electron bottom bar. |
| Multi-select responsive 760 | Hides selection actions and shows More button. | At <=760px, Select All/Invert/Clear move to More menu. |
| Multi-select responsive 520 | Count max width 96; cancel text hidden; More button 40x40; overflow actions hidden. | Very narrow layout keeps bottom bar usable without text overflow. |
| Progress strip | Height 3, margin `-6px 0 10px`, radius 999, accent animated bar width 34%, animation 900ms. | Loading/search/sort processing shows Electron progress strip. |
| Minimal shell page | `.app-shell.nav-minimal .albums-page`: padding `6px 14px 0 14px`; toolbar hidden. | Minimal shell only shows AppBar controls, not normal toolbar. |
| Minimal quick jump | Padding `2px 0 calc(var(--player-top-radius) + 12px)`, no visible scrollbar. | Quick jump remains left rail in minimal shell. |
| Minimal grid | Grid padding `8px 0 bottom 14px`, hidden native scrollbar, custom scrollbar appears on hover/focus. | Minimal shell scrollbars match Electron behavior. |
| AppBar search default | `.appbar-page-search` display none unless minimal open state. | AppBar search control follows Electron visibility rules. |
| AppBar search open minimal | Search becomes flex, title hidden, other AppBar page actions hidden, panel inline height 36. | Open search replaces AppBar title/action space. |
| AppBar search panel normal | Absolute, top `100% + 8px`, right 0, width `min(360px, 100vw - 16px)`, padding 8, radius 14. | Normal shell AppBar search opens as a floating panel. |
| AppBar search minimal form | Height 36, radius 10, no outer panel border, transparent panel. | Minimal form is compact and inline. |
| Preview backdrop | Fixed full screen, z-index 60, grid center, padding 28, dark translucent backdrop, blur 18px. | Preview modal centers and dims background. |
| Preview dialog | Width `min(420px, 86vw)`, padding 24, gap 14, radius 18, dialog surface and panel shadow. | Preview dialog does not exceed viewport and uses Electron radius. |
| Preview artwork | Dialog artwork is `min(320px, 70vw)` square. | Preview art is larger than tile and remains square. |
| Preview close | Absolute top/right 12, 32x32, radius 8, surface-control background, hover accent. | Close affordance matches Electron. |
| Menu flyout | Fixed z-index 240, min-width 206, max-width `min(280px, 100vw - 16px)`, padding 6, radius 10, menu surface. | Context/add/sort menus use shared flyout treatment. |
| Menu item | Min-height 34, grid `20px 1fr`, gap 10, padding `0 10px`, radius 7, 13px text. | Menu rows and submenu rows match Electron. |
| Night page background | Albums route workspace uses `var(--night-shell-bg)`. | Dark mode page background follows Electron. |
| Night command/search | Command buttons/search fields use night border, translucent white background, night text/muted colors, accent focus. | Dark mode does not use light-mode white controls. |
| Night quick jump | Buttons use night muted; hover/active use accent mixed with light text; disabled uses `rgba(222,231,242,0.25)`. | Dark quick-jump active/disabled states are visually distinct. |
| Night multi-select | Bottom bar uses dark gradient, night border, dark shadow, night button surfaces. | Multi-select bottom bar is not light glass in night mode. |
| Night preview | Backdrop `rgba(4,8,13,0.62)`, dialog night border/surface and stronger dark shadow. | Preview dialog matches Electron dark mode. |

## Text And Locale Keys

The UI must use the same locale keys as Electron:

- Search placeholder: `albums.searchAlbumPlaceholder`
- No match title/copy: `albums.noMatch`, `albums.noMatchCopy`
- Empty albums title/copy: `collection.noAlbums`, `collection.scanFirst`
- Sort labels: `local.sortReverseList`, `albums.sort.default`, `albums.sort.name`, `albums.sort.artist`
- Toolbar: `common.multiSelect`, `player.more`
- Album hover/add/context: `detail.playAlbum`, `context.addToPlaylist`, `context.select`, `context.seeAlbumArt`
- Multi-select: `albums.selectedCount`, `albums.playSelected`, `albums.addSelectedTo`, `albums.selectAll`, `albums.reverseSelection`, `albums.clearSelection`, `common.cancel`
- Add To menu: `common.nowPlaying`, `common.myFavorites`, `playlists.newPlaylist`, `playlists.newName`, `playlists.namePlaceholder`
- Preference menu: `settings.preferenceSettings`, `preferences.undoPrefer`, `preferences.level.do-not-appear`, `preferences.level.dislike`, `preferences.level.normal`, `preferences.level.high`, `preferences.level.higher`, `preferences.level.very-high`
- Quick jump tooltip: `quickJump.enabled`, `quickJump.disabled`, `quickJump.letterGroup`, `quickJump.symbolGroup`

## Implementation Boundary For Flutter Changes

When modifying Flutter against this target:

1. Start from Electron evidence in this document and reopen the cited files before editing.
2. Audit current Flutter call sites before patching:
   - `lib/src/library/ui/albums_page.dart`
   - `lib/src/library/ui/album_tile.dart`
   - `lib/src/library/ui/album_detail_page.dart`
   - shared command bar, search history, menu flyout, quick jump, artwork, and route shell code used by AlbumsPage.
3. Only patch confirmed differences from this document.
4. Do not add defensive null checks, input normalization, fallback behavior, or unrelated refactors unless Electron has the same behavior or the user explicitly approves.
5. Do not expose IDs or development/debug information in UI.
6. Do not claim completion from analyzer/test results alone for UI parity.

## Required Verification

Before reporting parity complete:

1. Capture or provide runtime evidence for Electron AlbumsPage in the same theme, viewport size, and data state used for Flutter comparison.
2. Capture or provide runtime evidence for Flutter AlbumsPage after changes.
3. Verify at least these states:
   - Normal light mode album grid.
   - Dark mode album grid.
   - Hovered album tile with play/add actions.
   - Multi-select mode with selected and unselected tiles.
   - Sort menu.
   - Search suggestions and search history.
   - Empty no-match state.
   - Minimal/narrow AppBar search and sort behavior.
   - Album-art preview dialog.
4. Run targeted static/tests for touched Flutter files.
5. List remaining unconfirmed items if runtime evidence is missing.

## Unconfirmed Items

These are not yet verified by runtime screenshots in this task:

- Exact Electron rendered screenshots for hover state, dark mode, minimal/narrow AppBar search, menu placement, and preview dialog.
- Exact Flutter current differences against this target.

These items must remain unconfirmed until Electron and Flutter runtime evidence is collected under matching theme, viewport, and data state.
