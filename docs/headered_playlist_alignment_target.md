# HeaderedPlaylistControl Alignment Target

Reference source:
- Electron component: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/HeaderedPlaylistControl.tsx`
- Electron styles: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/headered-playlist.css`
- Electron shared list/app-shell styles:
  - `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/playlist-control.css`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/now-playing.css`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/appbar.css`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/shell.css`
- Flutter component: `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/headered_playlist_control.dart`
- Flutter shared command/list styles:
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/command_bar.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/playback/playlist_control_item.dart`

Goal: Flutter `HeaderedPlaylistControl` should match the Electron implementation in visible UI, interaction behavior, and command/menu business logic unless a platform difference is explicitly documented.

## Next Alignment Target - 2026-05-24

This is the current working target after re-checking:

- Electron: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/HeaderedPlaylistControl.tsx`
- Electron CSS: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/headered-playlist.css`, plus `now-playing.css`, `appbar.css`, `shell.css`
- Flutter: `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/headered_playlist_control.dart`

### UI Targets

1. **Collapsed desktop header geometry**
   - Electron switches the desktop hero into fixed shell coordinates after collapse, based on workspace geometry.
   - Flutter currently uses a pinned sliver hero, which is visually close but not identical to Electron's fixed-position `.headered-playlist-hero`.
   - Target: verify and align collapsed desktop coordinates, width, left/right offsets, appbar overlap, and z-order against Electron screenshots.

2. **Compact collapsed behavior**
   - Electron hides the compact hero completely when collapsed and moves commands into the appbar portal.
   - Flutter also hides the compact hero, but the route/list transition still needs pixel verification against Electron: list should start at the top without residual hero spacing, with the appbar command portal carrying the collapsed controls.

3. **Header drag region**
   - Electron starts native drag only on non-interactive header space and explicitly excludes `button`, `input`, `textarea`, `select`, `a`, `[role="button"]`, and `.headered-playlist-scrollbar-thumb`.
   - Flutter currently has drag listeners on hero regions, but the exclusion model is not one-to-one.
   - Target: make drag start only from the same non-interactive hero/drag-strip surfaces and add regression coverage for command buttons, cover, title text, and scrollbar thumb.

4. **Row visual CSS parity**
   - Flutter row height matches, but row paint still needs visual parity against Electron's now-playing row CSS.
   - Target: hover/current/selected pseudo-layer color, selected left inset, action opacity, favorite-loading spinner, compact album action visibility, favorites action visibility, and night-mode alphas.

5. **List/header grid parity**
   - Electron uses CSS grid tracks:
     - no album: `64px minmax(190px, 1fr) minmax(170px, auto) 74px`
     - has album: `64px minmax(190px, 1.18fr) minmax(170px, auto) minmax(160px, 0.72fr) 74px`
     - <=1120px: `64px minmax(0, 1fr) max-content 20px`
   - Flutter approximates this with `Row`, `Expanded`, and fixed widths.
   - Target: compare desktop/narrow screenshots and tune the Flutter list header/row columns so song, action, album, and duration cells land in Electron positions.

6. **Compact list surface**
   - Electron compact list uses a blurred translucent panel with inset highlight.
   - Flutter approximates this with translucent color, border, and shadows.
   - Target: either reproduce the blur/inset more closely or document the Flutter equivalent after screenshot comparison.

7. **Artwork fallback and header color**
   - Flutter now uses `DefaultAlbumArtwork` and extracts/mixes artwork colors, but the exact failure/default and four-image settled-result path still needs verification.
   - Target: compare empty, 1-image, 3-image, and 4+-image playlists in day/night; ensure fallback fill, fallback surface, mosaic fourth tile, and backdrop color match Electron.

8. **Scrollbar metrics**
   - Flutter has Electron-like top/bottom/hover width, but Electron computes from workspace/player rectangles and supports thumb pointer drag from the fixed scrollbar.
   - Target: verify desktop/compact collapsed positions, bottom inset relative to player bar, thumb height, thumb drag behavior, and hover opacity/width.

### Business Logic Targets

1. **Row favorite toggle with undo**
   - Electron row favorite action always goes through `toggleSongFavoriteWithUndo`; in favorites it removes from the current favorites list with pending favorite loading state and undo.
   - Flutter row `onToggleFavoriteClick` currently calls `widget.onToggleFavorite` directly, so it can miss Electron undo/pending behavior.
   - Target: route row favorite toggles through the same undo path as the context menu, including favorites removal and loading state.

2. **Play Next fallback parity**
   - Electron row and context menu `Play next` fall back to inserting after the current now-playing track when `onPlayNext` is absent.
   - Flutter context menu has this fallback, but row `onPlayNextClick` only calls `widget.onPlayNext`.
   - Target: add the same fallback to row play-next.

3. **Header preference menu refresh**
   - Electron refreshes the preference snapshot before open and after set/undo via `onUpdated`.
   - Flutter reads only the current level, invalidates on undo, and delegates set through `widget.onSetPreferred`.
   - Target: refresh menu state after both set and undo, and ensure the display name rule matches Electron:
     - album: `Album - Artist`
     - playlist/favorites: title

4. **Song preference menu refresh**
   - Electron stores and refreshes `songPreferenceItem` after set/undo.
   - Flutter fetches a level on menu open and invalidates library data after set/undo.
   - Target: verify the visible menu state updates immediately after preference actions without requiring the menu to close/reopen.

5. **Add to Favorites from Add To menu**
   - Electron adds through playlist/favorite repository actions and shows an undo notification for Add to Favorites.
   - Flutter single-row Add To currently delegates to `widget.onToggleFavorite` in one path and may skip Electron's undo/message behavior.
   - Target: make Add to Favorites use the same shared add-with-undo path for row, context, and multi-select flows.

6. **Remove-from-current-list selection semantics**
   - Electron multi-select remove clears selection immediately and does not gate that clear on `hideMultiSelectCommandBarAfterOperation`.
   - Flutter calls `_removeSongsFromCurrentPlaylist`, which then calls `_hideSelectionAfterOperation`; this can differ when the setting is off.
   - Target: remove-from-current-list should clear selected IDs immediately like Electron, independent of the hide-after-operation setting.

7. **Virtual window parity**
   - Electron renders visible rows plus 10-row overscan with explicit top/bottom spacers.
   - Flutter uses `SliverList.builder`; it is lazy, but it is not the same visible-window/spacer model and may differ in scroll metrics for large playlists.
   - Target: decide whether to keep Flutter sliver laziness as the documented equivalent or implement the same overscan/spacer model. Verify with at least 500 songs.

8. **Context menu exact order and disabled states**
   - Flutter has broad menu coverage, but Electron ordering and disabled/loading states are still the source of truth.
   - Target: compare `getMusicMenuFlyoutItems` order and state for album, playlist, and favorites contexts:
     - play/pause/play next
     - add to playlist / now playing / favorites / create playlist
     - remove from current list
     - select
     - preference set/undo
     - move to folder
     - toggle favorite
     - see local
     - delete/hide
     - see artist / see album / music info / lyrics / album art

### Verification Targets

- Add focused widget tests for:
  - row play-next fallback
  - row favorite undo in favorites
  - Add to Favorites undo from Add To menu
  - remove-from-current-list selection clearing when hide-after-operation is off
  - header preference set/undo immediate refresh
  - header drag exclusion over buttons/scrollbar
- Add screenshot checks for:
  - desktop expanded/collapsed day and night
  - compact expanded/collapsed day and night
  - album, playlist, favorites
  - 0/1/3/4+ artwork sources
  - large playlist scroll position around first/middle/end

## Current Delta Snapshot - 2026-05-24

These are the remaining or recently observed differences after comparing the current Flutter file against Electron's `HeaderedPlaylistControl`.

- Header drag is close, but the target is stricter: dragging should start only from non-interactive hero space, matching Electron's exclusion of buttons, inputs, links, role buttons, and scrollbar thumb.
- Scroll/collapse in Flutter is driven by the route's single page scroll viewport (`HeaderedPlaylist.ScrollView`). Electron observes `.workspace-content`; Flutter does not have a separate outer workspace scroll container for this route, so collapse, appbar portal, and custom scrollbar must remain derived from the same route scroll controller.
- Flutter uses `SliverList.builder`, which avoids eager row building, but it does not mirror Electron's explicit visible-window plus 10-row overscan spacer model. Treat this as a performance and scroll-metric parity target, not just a rendering optimization.
- Header artwork color extraction now exists in Flutter, but it does not yet exactly match Electron's `extractArtworkColorRgb` behavior for URL/file failure, default fallback color, and the four-image settled-result mixing path.
- Header preference menu reads the current preference level directly, but Electron keeps a refreshed preference item snapshot and calls the update hook after set/undo. Flutter should match the refresh-after-set/undo behavior.
- Song context menu is now much closer: move to folder, hide file, delete, see local, preference, and music dialog entries exist. Keep the target focused on item ordering, enabled/disabled states, exact undo copy, and the play-next fallback.
- Multi-select hide-after-operation is wired through settings in several paths, but remove-from-current-list should be checked against Electron semantics: Electron clears selection immediately after remove and does not call `hideSelectionAfterOperation` for that path.
- Create-playlist-from-selection should be checked for undo/message parity. Electron creates the list without a songs-added undo notification; Flutter should not add an unrelated prompt unless Electron does.
- CSS parity must include the shared styles that affect the song rows and shell state, especially `playlist-control.css`, `now-playing.css`, `appbar.css`, and `shell.css`; do not use generic `commandbar.css` as the command-button target when `headered-playlist.css` overrides this surface.
- Header metadata should remain in the title copy column: `.headered-playlist-copy p` sits directly below the title, left-aligned on desktop and centered only in compact mode. Flutter currently follows this structure; keep it covered by visual/widget checks because this has regressed before.
- Desktop hero layout now uses Flutter's pinned sliver equivalent, but still is not a one-to-one port of Electron's sticky/fixed switch. Keep the target on Electron's normal-flow sticky hero, `margin: -50px -40px 0`, `width: calc(100% - 80px)` inner grid, and fixed shell coordinates only after collapse.
- Custom scrollbar metrics target: Electron starts from CSS variables (`--header-scrollbar-top: 358px`, bottom `player-height + 10px`) and recalculates from the workspace/player geometry. Flutter now uses the 358px desktop top, 4px -> 6px hover thumb, 140ms opacity transition, and a shell-provided player-relative bottom offset.
- Row height metrics are aligned at the widget level (`88px` desktop, `86px` compact), but the remaining row target is visual CSS parity: hover/current/selected pseudo-layer color, selected left inset, action opacity, favorite-loading spinner, night-mode alphas, and exact grid behavior.
- Compact CSS behavior is not just scaled desktop: Electron hides the hero completely when collapsed, makes the list start at the top, uses transparent compact command buttons, and gives the compact list a blurred translucent panel with inset highlight.
- App-shell CSS matters for the collapsed/compact state: Electron's minimal titlebar/workspace header uses immersive topbar blur, highlight, noise, and shadow variables that Flutter should either reproduce or intentionally document as a platform-specific equivalent.
- Header command buttons now target Electron's local override metrics: 40px/34px height, 10px radius, 13px/700 labels, 17px icons, and the Electron shadow. Keep this pinned to `headered-playlist.css`, not the generic command bar defaults.

## Selector Audit - 2026-05-24

Source of truth is `headered-playlist.css`; generic `commandbar.css` is not the target for expanded header buttons when this file overrides them.

- `.immersive-detail-page`, `.workspace-content:has(.immersive-detail-page)`: target is hidden native scrollbars and immersive surface. Flutter's equivalent is the route-level `HeaderedPlaylist.ScrollView` inside `SmPlayerWorkspace`; the native scrollbar is hidden and HeaderedPlaylist owns the page scroll metrics.
- `.headered-playlist-drag-region`: target is fixed 42px desktop drag strip, 34px compact strip, hidden in nav-minimal. Flutter drag handling exists inside hero and appbar portal; fixed external strip parity still needs shell-level verification.
- `.headered-playlist-control`: desktop target `gap: 18px`, `padding: 50px 40px 34px`; compact target zero gap/padding. Flutter uses sliver padding/hero spacing; needs full-route visual verification.
- `.headered-playlist-scrollbar`, `.headered-playlist-scrollbar-thumb`: Flutter now uses 358px desktop top, 4px/6px thumb widths, a 140ms opacity transition, and a shell override for the player-overlap bottom inset (`playerTopRadius + 10`).
- `.headered-playlist-backdrop`, `::before`: Flutter now has the two base radial layers, four-radial blurred/saturated layer, desktop bottom fade mask, compact `+72px` extent, compact collapse opacity, and the 721-900px fixed-width backdrop equivalent.
- `.headered-playlist-hero`: Flutter now applies Electron collapse variables for hero cover alpha, surface alpha, and 18px blur. Remaining target is exact fixed-position desktop collapsed geometry against the app shell.
- `.headered-playlist-hero-inner`: Flutter uses equivalent cover/copy layout and collapse gap. Remaining target is exact grid-width equivalence under very wide and intermediate route widths.
- `.headered-playlist-copy h2`, `.headered-playlist-copy p`: Flutter title/info sizing and info alignment are tied to collapse progress; compact title weight/line-height still needs pixel verification.
- `.headered-playlist-cover*`: Flutter uses mosaic/fallback `DefaultAlbumArtwork`, desktop/compact radius, and shadow targets. Remaining target is fallback image fill and night fallback surface exactness.
- `.headered-playlist-commandbar`, `.headered-playlist-commandbar button`: Flutter expanded command buttons follow the headered override dimensions/colors/order. Remaining target is exact hover/focus paint and disabled box-shadow behavior in night mode.
- `.headered-playlist-list`: Flutter matches desktop surface, border, radius, and shadow; compact surface now uses the CSS border/background/shadow colors plus a highlight approximation. Flutter has no native `BackdropFilter` sliver wrapper for `DecoratedSliver`; the documented equivalent is a translucent compact panel with Electron-matched alpha, border, shadow, and inset highlight while preserving lazy sliver rows.
- `.headered-playlist-list-header`: Flutter now follows the CSS column order: artwork placeholder, song/artist, actions placeholder, optional album, duration; it hides album at narrow widths and keeps the duration label uncropped. Remaining target is exact minmax track behavior because Flutter Row cannot express CSS `auto` identically.
- `.headered-playlist-song-list`: Flutter compact rows keep 2px gaps; desktop gap remains 0.
- `.playlist-detail-panel-headered`: still a target for embedded playlist detail panel verification.
- `body.night-mode ...`: Flutter has separate day/night color tokens for backdrop, hero, list, cover, buttons, and scrollbar. A macOS dark verification run now confirms the header/list remain rendered without obvious clipping; exact Electron screenshot comparison remains a visual QA item.

## Priority 0 - Current Known Parity Fixes

- Top command bar buttons use the same semantic icons as Electron:
  - `shuffle` -> shuffle icon
  - `multiSelect` -> `multiselect_ltr`
  - `preferenceSettings` -> star
  - `sort` -> sort icon
  - rename/delete/clear/edit artwork match Electron action meanings.
- Expanded and shy command bars must use the same command order as Electron:
  - `shuffle`, `multiSelect`, `preferenceSettings`, `sort`, `rename`, `clear`, `delete`, `editArtwork`.
- Sort command button is not an active/accent button just because the current criterion is selected. The active criterion is indicated inside the sort flyout with a checkmark.
- CommandBar container background remains transparent; button styling is handled by the shared command button rules.

## Priority 1 - UI Structure

- Root surface:
  - Electron uses `.headered-playlist-control` inside an immersive detail page with fixed padding and a hidden native scrollbar.
  - Flutter should match the same outer spacing, rounded panel behavior when embedded, and night-mode surface colors.
  - Desktop target from CSS: `gap: 18px`, `padding: 50px 40px 34px`, transparent native scrollbar on `.workspace-content`, and no-drag app region except declared drag areas.
  - Compact target from CSS: root `gap: 0`, `padding: 0`, transparent background, and a 34px drag strip offset from the right by 96px.
- Backdrop:
  - Electron derives `--header-cover-rgb` from the first four artwork images, falling back to default artwork color.
  - Flutter should extract/mix artwork color with the same default fallback and failure behavior, then drive the same radial backdrop intensity for day/night.
  - Desktop CSS uses a masked backdrop: two base radial gradients plus a blurred `::before` layer with four radial gradients, `filter: blur(54px) saturate(136%)`, `opacity: 0.96`, and a bottom fade mask.
  - Flutter should not approximate this with only two unblurred radial gradients; the blurred four-radial layer, saturation, scale, and fade mask materially affect the Electron look.
  - Compact CSS removes the mask, fixes the backdrop to the viewport, fades it by collapse progress, and shortens the extra height from `+110px` to `+72px`.
  - The 721-900px breakpoint fixes the backdrop to the viewport while keeping desktop layout; Flutter should have an equivalent intermediate-width treatment.
- Header hero:
  - Desktop target: 326px hero height, 50px top padding, 240px cover, 48px title, 30px command margin before collapse.
  - Compact target: 320px hero height, 180px cover, centered title and command bar.
  - Collapse target: interpolate exactly like Electron: desktop hero height 326 -> 126, cover 240 -> 86, title 48 -> 26; compact 320 -> 138, cover 180 -> 68, title 24 -> 20.
  - Desktop structural target: `.headered-playlist-hero` is sticky in normal flow with `margin: -50px -40px 0`, `padding: var(--header-hero-padding-top) 0 10px`, and the inner grid uses `grid-template-columns: cover minmax(0, 1fr)`, `gap: 42px -> 18px`, `width: calc(100% - 80px)`, `margin: 0 40px`.
  - Desktop collapsed CSS fixes the hero to app-shell coordinates with z-index 30; compact collapsed CSS sets hero height/padding to 0 and hides the hero inner/command bar instead of showing an in-page collapsed hero.
  - Hero background target: Electron varies `--header-hero-cover-alpha`, `--header-hero-surface-alpha`, and `--header-hero-blur` with collapse progress. Flutter should not keep an always-on static hero gradient; the hero surface must become a blurred/surface-backed collapsed header only as scroll progresses.
  - Desktop title CSS allows `overflow-wrap: anywhere` with max width 860px; compact title CSS uses max width `min(420px, 100%)`, font weight 800, and line-height 1.16.
  - Header info/counter CSS target: `.headered-playlist-copy p` has `margin: calc(8px - (4px * progress)) 0 0`, `font-size: calc(17px - (3px * progress))`, `font-weight: 650`, max height tied to collapse progress, and must remain in the same copy column as the title. It must not be horizontally separated from the title on desktop.
  - Collapsed desktop copy target: `.headered-playlist-copy` becomes a flex column with `justify-content: space-between`, `align-self: stretch`, and `height: var(--header-cover-size)`; the info line is `display: none` when collapsed.
- Cover:
  - Playlist/favorites mosaic uses up to four resolved artwork URLs; three images use colorful fallback in the fourth slot.
  - Album uses the album artwork only.
  - Empty/fallback artwork uses `DefaultAlbumArtwork`, not a custom placeholder.
  - Desktop cover shadow/inset target: `0 26px 58px rgba(54, 68, 86, 0.22)` plus a white inset border; compact cover shadow target is lighter, `0 8px 18px rgba(32, 45, 63, 0.13)`.
  - Fallback cover target: Electron wraps `DefaultAlbumArtwork` in a fallback surface with a diagonal accent/white background in day mode and sets the fallback SVG/image to fill the cover; Flutter should not render a differently framed fallback.
  - Compact cover target: compact uses a fixed 8px radius and the lighter compact shadow, not the desktop radius interpolation.
- Collapsed command bar:
  - Electron renders the shy command bar through `AppBarPortal`; it is tied to the app bar, not an in-content floating card.
  - Flutter target is to integrate with the app shell/app bar rather than overlaying a separate Material panel inside the playlist view.
  - The shy command bar is hidden by default CSS and only shown in `.app-shell.nav-minimal`; it uses 40px height, 40px minimum button width, 132px max labeled button width, and an icon-only 40px overflow button.
- Command bar CSS:
  - Expanded header buttons should follow the `headered-playlist.css` override: 40px min height, 10px radius, 13px/700 text, 17px icons, `rgba(255,255,255,0.66)` day background, and `0 10px 24px rgba(45,58,76,0.08)` shadow.
  - Compact header buttons override to transparent backgrounds, no border/shadow, 34px min height, 2px/1px margins, and `rgba(255,255,255,0.18)` day hover.
  - Night mode must use the Electron night border/background/hover colors for both expanded and appbar command buttons.
- List shell:
  - Desktop list is a translucent framed panel with header row and Electron grid tracks.
  - Compact list hides the header, uses `minmax(0, 1fr) 52px`, and keeps 2px row gaps.
  - Night mode should match Electron list border, background, and shadow opacity.
  - Desktop target: `padding: 0 10px`, radius 12, background `rgba(255,255,255,0.76)`, border `rgba(126,139,154,0.18)`, and shadow `0 14px 34px rgba(68,88,112,0.08)`.
  - Compact target: margin `0 2px`, padding `2px 0`, border `rgba(255,255,255,0.66)`, background `rgba(255,255,255,0.72)`, shadow `0 18px 42px rgba(33,45,62,0.1)` plus inset highlight, and `backdrop-filter: blur(18px) saturate(126%)`.
  - Header grid tracks must match both desktop variants and the container query:
    - no album: `64px minmax(190px, 1fr) minmax(170px, auto) 74px`
    - has album: `64px minmax(190px, 1.18fr) minmax(170px, auto) minmax(160px, 0.72fr) 74px`
    - container <= 1120px: `64px minmax(0, 1fr) max-content 20px`, hide the album header cell.
- Row CSS:
  - HeaderedPlaylist rows inherit the now-playing queue row model, including hover/current/selected backgrounds via pseudo-layer, selected left inset, favorite-loading spinner, hover actions opacity, and night-mode hover/current alphas.
  - Compact headered album rows intentionally keep more actions visible than other compact rows; favorites hide the favorite action until hover/focus.
  - Flutter `PlaylistControlItem.headeredPlaylist` should not use generic row metrics if they visibly diverge from Electron's headered/now-playing CSS.

## Priority 2 - Scroll And Virtualization

- Scroll source:
  - Electron observes the workspace scroll container, not an inner list controller.
  - Flutter's actual page scroll container for this route is `HeaderedPlaylist.ScrollView` inside `SmPlayerWorkspace`; collapse state, app bar portal state, and custom scrollbar metrics are all derived from its single controller.
- Collapse thresholds:
  - Expanded -> collapsed: desktop 224px, compact 112px.
  - Collapsed -> expanded hysteresis: desktop 186px, compact 76px.
- Immersive app bar variables:
  - Electron updates cover alpha, surface alpha, shadow alpha, blur, highlight alpha, and noise opacity on the app shell.
  - Flutter should produce equivalent app shell visual state or a clearly equivalent Flutter-specific app bar state.
- Custom scrollbar:
  - Electron has a fixed right scrollbar with calculated top/bottom/thumb height.
  - Flutter target is parity for visibility, thumb position, bottom offset relative to the player bar, opacity, and hover width/color. Electron uses a 10px track, 4px thumb, 6px hover width, 38px minimum thumb height, and opacity 0 when not scrollable.
- Virtual window:
  - Electron renders only visible rows plus 10-row overscan.
  - Row height target: desktop 88px, compact 86px.
  - Flutter should avoid rendering all rows for large playlists and keep spacer heights equivalent.

## Priority 3 - Command And Menu Business Logic

- Shuffle:
  - Calls `onRecordPlay` before playing shuffled queue.
  - Uses Electron Fisher-Yates shuffle behavior.
- Sort:
  - `Reverse` reverses current visible order and keeps active criterion.
  - Choosing current criterion reverses current visible order.
  - Choosing a different criterion sorts original `songs`, sets selected criterion, persists through `onSortSongs`.
- Rename:
  - Same validation: empty, length > 50, duplicate except current name, and invalid special strings.
  - Same title, placeholder, confirm label.
- Clear/delete:
  - Same confirm title/message/confirm label.
  - Clear is disabled when there are no songs.
- Preference menu:
  - Header preference menu should refresh the preference snapshot and use the Electron display name rule:
    - album: `"Album - Artist"`
    - playlist/favorites: title
  - Undo preference should refresh menu state after removal.
  - Set preference should also refresh menu state after the write, matching Electron's `onUpdated` callback flow.
- Song context menu:
  - Must include the same options as Electron `getMusicMenuFlyoutItems` for this context:
    - play/pause/play next
    - add to playlist / now playing / favorites / create playlist
    - remove from current list when removable
    - select
    - preference set/undo
    - move to folder
    - toggle favorite with undo
    - see local
    - delete from disk with confirmation
    - hide file with undo
    - see artist / see album / music info / lyrics / album art
  - Current Flutter has the broad menu coverage; remaining target is exact ordering, disabled states, favorite loading state in favorites, undo messages, and fallback play-next behavior when no callback is provided.

## Priority 4 - Add To And Undo Behavior

- Add to Now Playing:
  - Electron appends to `nowPlayingSongIds`, then undo removes exactly the inserted range.
  - Flutter should use the same undo message and range-removal semantics.
- Add to Favorites:
  - Electron adds to the favorites playlist and undo removes from favorites.
  - Flutter should match message text and undo action.
- Add to custom playlist:
  - Electron shows per-song or count-based message and undo removes from target playlist.
  - Flutter should match single/multiple messages through i18n count helpers.
- Remove from playlist/favorites:
  - Electron shows specific removed-from message and undo restores to playlist/favorites.
  - Flutter currently uses a generic operation-done message in some paths; target is Electron text.
- Multi-select hide-after-operation:
  - Electron reads `hideMultiSelectCommandBarAfterOperation` from store and hides only after operations that opt into it.
  - Flutter should match the same setting semantics across Add To, favorite, create playlist, play, and remove.
  - Remove-from-current-list is special: Electron clears selected IDs after invoking remove and does not gate that clear on the hide-after-operation setting.

## Priority 5 - Selection State

- Electron selection state is persisted per key:
  - `headered-playlist:${preferenceType ?? type}:${preferenceItemId ?? title}`
  - multi-select mode and selected song IDs are stored separately.
- Flutter currently uses `PageSelectionController.stored` with the same logical key shape; keep this as the required baseline.
- Target:
  - Restore selection mode and selected IDs for the same logical headered playlist.
  - Reset ordered song IDs and selected sort criterion when `songs` changes.
  - Effective selected IDs are always intersected with visible queue IDs.

## Priority 6 - App Integration

- Header drag:
  - Electron starts native window drag on header pointer down except over buttons/inputs/selects/links/scrollbar.
  - Flutter target should match desktop drag behavior where platform support exists, including the same interactive-child exclusions.
- Immersive title:
  - Electron dispatches `smplayer:immersive-title-change` only on compact collapsed header.
  - Flutter target should set the shell/app bar title equivalently.
- Embedded playlist detail panel:
  - Electron has separate `.playlist-detail-panel-headered .headered-playlist-control` styling.
  - Flutter should verify any embedded HeaderedPlaylistControl usage against the panel variant, not only full-page album/playlist routes.

## Verification Plan

- Add/adjust widget tests for:
  - command bar icon mapping and sort button non-active state
  - expanded command order: clear appears before delete
  - sort current criterion reverses current visible order
  - reverse sort persists active criterion
  - header preference set/undo refreshes state after the write
  - context menu contains move/hide/delete/preference/view entries in Electron order
  - multi-select Add To undo behavior and hide-after-operation behavior
  - remove-from-current-list clears selection independently of the hide-after-operation setting
  - selected IDs filtered by visible queue IDs
- Add visual verification targets:
  - desktop day/night, 1200x800
    - Current evidence: day and dark macOS verification runs render the header, command buttons, list, and scrollbar without obvious clipping.
  - compact day/night, 390x844
    - Verification command supports this via `--dart-define=SMPLAYER_HEADERED_VERIFY_WIDTH=390 --dart-define=SMPLAYER_HEADERED_VERIFY_HEIGHT=844`.
  - collapsed header on compact
  - playlist with 0, 1, 3, and 4+ artwork images
  - large playlist row virtualization, at least 500 songs

## Non-Goals

- Do not change database access patterns just to mirror React hooks.
- Do not expose item IDs in UI.
- Do not add defensive null handling for states that cannot occur in the Flutter data contract.
