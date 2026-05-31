# MediaControl Electron Alignment Target

This document is the acceptance target for aligning Flutter `MediaControl` to the Electron player. Electron remains the source of truth. Existing Flutter widgets and visual primitives may be reused where this target says "reuse style"; behavior, structure, enabled state, menu content, and responsive roles still must match Electron.

## Electron Evidence

| Area | Electron source |
| --- | --- |
| Player component and business flow | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/MediaControl.tsx` |
| Player CSS, hover, dark mode, compact nav-minimal rules | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/player.css` |
| 1200 / 800 responsive rules | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/responsive.css` |
| Playback mode labels and default artwork constant | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/mediaControlModel.ts` |
| Volume icon thresholds | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/volumeIcon.ts` |
| Bottom player call site | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/App.tsx` |
| Full now-playing surface reuse | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/NowPlayingFullPage.tsx` |

## Flutter Surfaces

| Area | Flutter owner |
| --- | --- |
| Bottom player entry | `lib/src/playback/media_control.dart` |
| Shared surface / transport / progress | `lib/src/playback/media_control_surface.dart` |
| Utility controls and volume popover | `lib/src/playback/media_control_utility.dart` |
| More menu and playback mode menu | `lib/src/playback/media_control_menus.dart` |
| Track, artwork, current lyric line | `lib/src/playback/media_control_track.dart`, `lib/src/playback/media_control_artwork.dart` |
| Player frame / artwork tint background | `lib/src/playback/media_control_frame.dart` |
| Menu positioning primitive | `lib/src/library/ui/menu_flyout.dart` |
| Shell call site | `lib/src/app/shell_page.dart` |
| Full now-playing player reuse | `lib/src/playback/now_playing_full_page.dart` |
| Targeted tests | `test/media_control_widget_test.dart`, `test/media_control_visual_verify_test.dart` |

## Acceptance Matrix

| ID | Electron rule | Flutter acceptance target | Style requirement | Proof |
| --- | --- | --- | --- | --- |
| MC-01 Host visibility | Bottom player is mounted from `App.tsx`; host is hidden while full now-playing page is open. | Shell bottom player exists once; full player route does not show duplicate bottom player. | Reuse current shell/player frame style. | Route/widget test or runtime screenshot. |
| MC-02 Track entry | Track button contains artwork, title, artist, optional current lyric; disabled when `track.id == null`; click opens full now-playing. | Same content and disabled/click behavior. No ID or debug text visible. | Reuse existing `_PlayerTrack` style. | Widget test plus screenshot. |
| MC-03 Artwork source | Uses resolved song artwork; failed image records failed URL, refreshes artwork, and falls back to default artwork. | Same refresh-on-error and default artwork behavior. | Reuse `DefaultAlbumArtwork` / `SongArtwork`. | Decode-error widget test. |
| MC-04 Artwork hover | Hover/focus on track shows fullscreen overlay over artwork only when track is enabled. | Overlay appears only for enabled track hover/focus. | Reuse current overlay visual. | Hover widget test or screenshot. |
| MC-05 Current lyric | Current lyric comes from current song lyrics source and progress; line animates with 240 ms slide-in. | Current lyric updates from shell-provided lyric line; no lyric leaves row absent. | Reuse existing text/animation if behavior matches. | Widget test. |
| MC-06 Transport | Previous, play/pause, next are centered; loading swaps primary icon for spinner; disabled state blocks callbacks. | Transport callbacks and disabled/loading state match Electron. | Existing button style can remain unless geometry fails. | Widget test. |
| MC-07 Seek progress | Dragging progress updates draft UI; release commits seek only if a seek began; duration <= 0 disables slider. | Begin/change/end semantics match Electron guards. | Reuse `Slider` styling. | Widget test. |
| MC-08 Duration fallback | `durationSeconds || currentSong.duration || 0`. | Display and slider max use current song duration when backend duration is missing. | N/A. | Unit/widget test. |
| MC-09 Main volume disabled | `MediaControlSurface` sets `volumeValue = disabled ? 0 : clamp(volume)` and disables main mute/slider/compact volume controls. | Main volume UI shows 0 and is disabled while surface disabled. | Reuse existing volume controls. | Widget test. |
| MC-10 Compact More volume | Compact More menu has separate volume item and remains available even when no current song exists. | Compact More volume slider is usable when player is empty/disabled. | Reuse current menu content widget style. | Widget test. |
| MC-11 Volume icon thresholds | Muted -> muted icon; volume 0 -> off; `<34` low; `<67` medium; otherwise high. | Same thresholds everywhere player/mini-mode use volume icons. | Existing Fluent icons can be used. | Unit/widget test. |
| MC-12 Favorite | Main favorite hidden when `trackId == null`; compact More favorite is disabled without song; active favorite uses filled heart. | Same visibility/disabled/active behavior. | Reuse existing heart icon style. | Widget test. |
| MC-13 Wide playback mode | Wide utility row shows shuffle, repeat, repeat-one independent buttons with active state and Electron titles. | Same buttons and callbacks; current checked mode is reflected. | Reuse existing button style. | Widget test. |
| MC-14 Compact playback mode | Compact mode button cycles `once -> shuffle -> repeat -> repeat-one -> once`; long press/context opens checked mode menu; selected current mode is no-op. | Same cycle order, long-press menu, no-op current item. | Reuse current menu style. | Widget test. |
| MC-15 Voice assistant | `MediaControlSurface` initializes `voiceAssistantAvailable` only when `window.smplayer.getAppInfo().platform === 'win32'`; the button is not added to More. | Flutter shell exposes `onOpenVoiceAssistant` only on Windows. macOS/iOS/Android narrow players do not show the mic button. | Reuse current dialog/flyout surface on Windows only. | Platform gate test plus widget test. |
| MC-16 More menu position | Player More opens above the button using anchor top minus 8 and menu height fallback. | Explicit player flyout position resolves above anchor, not below. | Reuse `MenuFlyout` style. | Geometry widget test. |
| MC-17 More empty player | More menu always starts with Quick Play; if no current song, wide menu stops there. Compact menu keeps playback mode, volume, favorite before stopping. | Same item list for wide and compact empty states. | Reuse existing menu rows. | Widget test. |
| MC-18 Add To | With song, More includes Add To. Wide Add To can include My Favorites if song is not favorite. Compact Add To excludes My Favorites because compact has its own favorite item. | Same inclusion/exclusion and callbacks. | Reuse shared Add To menu helper. | Menu widget test. |
| MC-19 Add to Now Playing undo | Add To Now Playing appends current song and undo removes only the inserted queue range. | Same queue-range undo behavior. | N/A. | Controller/repository test. |
| MC-20 Preference | Opening More refreshes current song preference state; preference item checked/undo reflects refreshed value. | Resolve preference on menu open, not via polling in build. | Reuse existing preference menu helper. | Async widget test. |
| MC-21 View submenu | View submenu contains See Artist, See Album, Music Info, Lyrics, Album Art, Local File. Info/Lyrics/Album Art keep menu open while opening dialog. | Same submenu grouping, order, callbacks, and keep-open behavior. | Reuse menu/dialog styles. | Menu widget test. |
| MC-22 Artist/album navigation | See Artist navigates to first parsed song artist; See Album navigates to album or unknown album fallback. | Same target route semantics. | N/A. | Shell route test. |
| MC-23 Full screen / mini mode | More contains Full Screen or Exit Full Screen based on window state, plus Mini Mode. | Same label/icon/callback switching. | Reuse native window bridge/UI. | Widget/native bridge test. |
| MC-24 Wide layout | Wide player grid: track column, center transport/progress, utility column. Track copy capped at `min(360px, 24vw)`. | Transport not pushed by long title or utility controls. | Existing frame style can remain. | Geometry widget test. |
| MC-25 1200 condensed | At 721-1200 non-minimal width, utility condenses: volume becomes compact popover, mode becomes compact button, wide mode/volume controls hide. | Same threshold and visible controls. | Reuse existing controls. | Width-specific widget test. |
| MC-26 800 compact | At <=800 and >=721 in non-minimal shell, `.player-bar` becomes three columns `minmax(168px, 1fr) minmax(174px, 228px) 80px`; rows are `74px 28px`; progress spans columns 1-3; transport is centered. | Flutter compact layout keeps track left, transport centered, utility right, and progress row spanning the full width. | Existing compact visual may remain. | Geometry widget test and screenshot. |
| MC-27 520 compact | At <=520, Electron columns are `minmax(112px, 1fr) minmax(136px, 176px) 68px`; rows `72px 28px`; padding `9px 12px 11px`; primary 48/12; utility buttons 34/5; More remains the rightmost visible player utility on macOS. | Flutter uses the same compact roles and button sizes; macOS does not add a voice button; no RenderFlex overflow. The current Flutter utility column uses measured width to avoid Flutter button overflow and must keep More right-aligned at the Electron edge. | Reuse current button visuals. | 520 width widget test and screenshot. |
| MC-28 Loading progress | Loading track shows indeterminate progress bar instead of slider. | Same loading bar behavior. | Reuse existing loading visual. | Widget test. |
| MC-29 Dark mode | Electron has separate night colors for player surface, text, progress/volume slider, hover/active/disabled states. | Dark theme must not show light-only text/surface states; all states remain legible. | Existing theme tokens can be reused if screenshots match. | Light/dark screenshot. |
| MC-30 Artwork tint | Player background tint uses artwork-derived color with default fallback and day/night layered wash. | Background tint follows current artwork and default fallback. | Existing `GlassContainer` may remain only if layer behavior visually matches. | Screenshot plus color/tint test. |
| MC-31 Full now-playing reuse | Full now-playing footer reuses `MediaControlSurface`; exit artwork button uses fullscreen-exit overlay. | Full page transport/progress/utility behavior stays consistent with bottom surface. | Reuse current full player frame. | Full route widget/screenshot. |

## Narrow Layout Acceptance Matrix

| ID | Width/state | Electron evidence | Flutter target | Current status |
| --- | --- | --- | --- | --- |
| NMC-01 | Bottom player, 721-800px | `responsive.css` sets `grid-template-columns: minmax(168px, 1fr) minmax(174px, 228px) 80px`, `grid-template-rows: 74px 28px`, `column-gap: 10px`, `padding: 8px 16px 10px`. | Track/transport/utility stay on row 1; progress spans row 2; play button center equals player center. | Covered by compact geometry tests; needs fresh screenshot. |
| NMC-02 | Bottom player, <=520px | `player.css` nav-minimal rule sets `minmax(112px, 1fr) minmax(136px, 176px) 68px`, `72px 28px`, `padding: 9px 12px 11px`, primary `48px`, utility `34px`. | Same row roles and button sizes; right utility never overflows; progress has 42px time columns and 8px gaps. | Partially covered by widget tests; screenshot pending. |
| NMC-03 | Full now-playing footer, <=800px | `responsive.css` gives `.now-playing-full-player-bar.player-bar` columns `80px minmax(174px, 1fr) 80px`; `.transport-row` centered. | Exit column left, transport center, utility right; progress row spans the footer; no duplicate bottom player. | Covered by 780/500 full-page tests; screenshot pending. |
| NMC-04 | Full now-playing footer, <=520px | `now-playing-full.css` media rule gives columns `68px minmax(136px, 1fr) 68px`; inherited player rule gives button size `34px`. | Exit button left, play button center, More at right edge, no overflow. Utility content may paint leftward like CSS flex overflow, but the side column and More right edge must stay at Electron coordinates. | Implemented with 68px side columns and right-aligned overflow for compact utility content; screenshot pending. |
| NMC-05 | Voice assistant platform | `MediaControlSurface` sets voice availability only for Electron `platform === 'win32'`. | macOS screenshot must not show the mic button; Windows may show voice + More as the last two utility buttons. | Implemented in `supportsVoiceAssistant`; direct component tests still cover the available case. |
| NMC-06 | Utility visibility | At <=800 `.player-mode-row button:not(:nth-last-child(-n + 2))` hides earlier mode buttons; voice is not a More item. | Visible utility buttons are only the Electron last-two result for the active platform and width. | Covered for voice-available minimal rows; macOS shell path covered by platform gate. |
| NMC-07 | Default artwork | `DefaultAlbumArtwork.tsx` uses `DEFAULT_ALBUM_ARTWORK_URL = './app-icon.png'`. | Flutter uses `assets/branding/app-icon.png` for missing art. | Implemented; screenshot left gray note is not the current Electron source target. |
| NMC-08 | Screenshot proof | Electron and Flutter must be compared at the same width, theme, platform, song/duration/lyrics/voice availability. | Save paired screenshots and mark any visual deltas explicitly. | Pending; no pixel-level completion claim. |

## Intentional Differences

| Difference | Reason |
| --- | --- |
| Existing Flutter control visuals may be reused. | User explicitly allowed existing components to keep their style. |
| Skip buttons may keep the current Flutter outer-size treatment if tests document it. | Prior requested target allowed the larger circular background. |
| Day disabled primary style may keep the current Flutter app behavior if explicitly requested. | Electron CSS differs, but this was previously protected as app behavior. |

Any other difference must be backed by an explicit user request or must remain listed as not aligned.

## Verification Plan

Run targeted checks before claiming alignment:

```sh
dart analyze lib/src/playback/media_control.dart lib/src/library/ui/menu_flyout.dart test/media_control_widget_test.dart
flutter test --no-pub test/media_control_widget_test.dart --plain-name MediaControl
```

For visual claims, capture Flutter and Electron at the same theme, window width, song state, loading state, and hover/open state. Code similarity or widget tests alone are not enough for pixel-level alignment.

## Current Known Evidence Gap

`test/media_control_visual_verify_test.dart` currently hangs while generating screenshots in this workspace. Rechecked on 2026-05-31 with `--concurrency=1`; the run stayed in `writes MediaControl alignment screenshots` for more than 60 seconds and the generated `/tmp/smplayer_media_control_wide_verify.png` remained empty. Until a reliable screenshot path is restored, any visual alignment claim must be limited to widget-test-proven behavior and source-level CSS parity.
