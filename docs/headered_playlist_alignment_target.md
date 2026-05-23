# HeaderedPlaylistControl Alignment Target

Reference source:
- Electron component: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/HeaderedPlaylistControl.tsx`
- Electron styles: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/headered-playlist.css`
- Flutter component: `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/headered_playlist_control.dart`

Goal: Flutter `HeaderedPlaylistControl` should match the Electron implementation in visible UI, interaction behavior, and command/menu business logic unless a platform difference is explicitly documented.

## Priority 0 - Current Known Parity Fixes

- Top command bar buttons use the same semantic icons as Electron:
  - `shuffle` -> shuffle icon
  - `multiSelect` -> `multiselect_ltr`
  - `preferenceSettings` -> star
  - `sort` -> sort icon
  - rename/delete/clear/edit artwork match Electron action meanings.
- Sort command button is not an active/accent button just because the current criterion is selected. The active criterion is indicated inside the sort flyout with a checkmark.
- CommandBar container background remains transparent; button styling is handled by the shared command button rules.

## Priority 1 - UI Structure

- Root surface:
  - Electron uses `.headered-playlist-control` inside an immersive detail page with fixed padding and a hidden native scrollbar.
  - Flutter should match the same outer spacing, rounded panel behavior when embedded, and night-mode surface colors.
- Backdrop:
  - Electron derives `--header-cover-rgb` from the first four artwork images, falling back to default artwork color.
  - Flutter currently uses static palette values; target is to extract/mix artwork color and drive the same radial backdrop intensity for day/night.
- Header hero:
  - Desktop target: 326px hero height, 50px top padding, 240px cover, 48px title, 30px command margin before collapse.
  - Compact target: 320px hero height, 180px cover, centered title and command bar.
  - Collapse target: interpolate exactly like Electron: desktop hero height 326 -> 126, cover 240 -> 86, title 48 -> 26; compact 320 -> 138, cover 180 -> 68, title 24 -> 20.
- Cover:
  - Playlist/favorites mosaic uses up to four resolved artwork URLs; three images use colorful fallback in the fourth slot.
  - Album uses the album artwork only.
  - Empty/fallback artwork uses `DefaultAlbumArtwork`, not a custom placeholder.
- Collapsed command bar:
  - Electron renders the shy command bar through `AppBarPortal`; it is tied to the app bar, not an in-content floating card.
  - Flutter target is to integrate with the app shell/app bar rather than overlaying a separate Material panel inside the playlist view.
- List shell:
  - Desktop list is a translucent framed panel with header row and Electron grid tracks.
  - Compact list hides the header, uses `minmax(0, 1fr) 52px`, and keeps 2px row gaps.
  - Night mode should match Electron list border, background, and shadow opacity.

## Priority 2 - Scroll And Virtualization

- Scroll source:
  - Electron observes the workspace scroll container, not an inner list controller.
  - Flutter should align collapse state, app bar state, and scrollbar metrics to the actual page scroll container.
- Collapse thresholds:
  - Expanded -> collapsed: desktop 224px, compact 112px.
  - Collapsed -> expanded hysteresis: desktop 186px, compact 76px.
- Immersive app bar variables:
  - Electron updates cover alpha, surface alpha, shadow alpha, blur, highlight alpha, and noise opacity on the app shell.
  - Flutter should produce equivalent app shell visual state or a clearly equivalent Flutter-specific app bar state.
- Custom scrollbar:
  - Electron has a fixed right scrollbar with calculated top/bottom/thumb height.
  - Flutter target is parity for visibility and thumb position, or an explicit decision to keep platform scrollbar hidden.
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
  - Current Flutter is missing or diverges on move-to-folder, hide-file, some undo messages, and fallback play-next behavior when no callback is provided.

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

## Priority 5 - Selection State

- Electron selection state is persisted per key:
  - `headered-playlist:${preferenceType ?? type}:${preferenceItemId ?? title}`
  - multi-select mode and selected song IDs are stored separately.
- Flutter currently uses local `PageSelectionController` state.
- Target:
  - Restore selection mode and selected IDs for the same logical headered playlist.
  - Reset ordered song IDs and selected sort criterion when `songs` changes.
  - Effective selected IDs are always intersected with visible queue IDs.

## Priority 6 - App Integration

- Header drag:
  - Electron starts native window drag on header pointer down except over buttons/inputs/selects/links/scrollbar.
  - Flutter target should match desktop drag behavior where platform support exists.
- Immersive title:
  - Electron dispatches `smplayer:immersive-title-change` only on compact collapsed header.
  - Flutter target should set the shell/app bar title equivalently.
- Embedded playlist detail panel:
  - Electron has separate `.playlist-detail-panel-headered .headered-playlist-control` styling.
  - Flutter should verify any embedded HeaderedPlaylistControl usage against the panel variant, not only full-page album/playlist routes.

## Verification Plan

- Add/adjust widget tests for:
  - command bar icon mapping and sort button non-active state
  - sort current criterion reverses current visible order
  - reverse sort persists active criterion
  - header preference display name for album
  - context menu contains move/hide/delete/preference/view entries
  - multi-select Add To undo behavior and hide-after-operation behavior
  - selected IDs filtered by visible queue IDs
- Add visual verification targets:
  - desktop day/night, 1200x800
  - compact day/night, 390x844
  - collapsed header on compact
  - playlist with 0, 1, 3, and 4+ artwork images
  - large playlist row virtualization, at least 500 songs

## Non-Goals

- Do not change database access patterns just to mirror React hooks.
- Do not expose item IDs in UI.
- Do not add defensive null handling for states that cannot occur in the Flutter data contract.
