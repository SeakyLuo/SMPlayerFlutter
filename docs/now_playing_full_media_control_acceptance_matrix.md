# NowPlayingFullPage MediaControl UI Layout Acceptance Matrix

Electron is the source of truth for this target. Existing Flutter visual
components may be reused; this matrix validates structure, layout roles,
states, menus, and responsive behavior.

This target is not a pixel-style rewrite. Existing Flutter components such as
the shared media-control buttons, sliders, menu flyouts, icons, artwork/default
artwork, and loading indicators can be reused when they preserve the same
layout slot, visibility rule, state, and interaction. Colors, shadows, radius,
and animation curves are acceptance requirements only when they change
visibility, hit area, ordering, alignment, disabled/active meaning, or
responsive behavior.

## Electron Evidence

| Area | Source |
| --- | --- |
| Full page footer call site | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/NowPlayingFullPage.tsx` |
| Shared player surface content | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/MediaControl.tsx` |
| Full page footer layout and theme overrides | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/now-playing-full.css` |
| Base player layout, transport, progress, utility rules | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/player.css` |
| 800px responsive full-footer override | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/responsive.css` |
| Playback mode labels and mode order | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/mediaControlModel.ts` |
| Volume icon thresholds | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/volumeIcon.ts` |

## Extracted Electron CSS Dimensions

| Area | Electron selector/source | Confirmed CSS dimensions |
| --- | --- | --- |
| Base footer shell | `player.css` `.player-bar` | `height: var(--player-height)`, `padding: 10px 16px`, grid columns `minmax(280px, 0.9fr) minmax(420px, 1fr) minmax(280px, 0.9fr)`, rows `52px 38px`, `gap: 0`, top radius only. |
| 1200-721px non-minimal footer | `responsive.css` `@media (max-width: 1200px) and (min-width: 721px)` | side min `clamp(200px, 24vw, 280px)`, center min `clamp(280px, 40vw, 420px)`, utility padding `0 8px`, condensed utility gaps `8px`. |
| 800-721px compact footer | `responsive.css` `@media (max-width: 800px) and (min-width: 721px)` | grid `minmax(168px, 1fr) minmax(174px, 228px) 80px`, rows `74px 28px`, `column-gap: 10px`, `padding: 8px 16px 10px`. |
| Full-page compact footer | `now-playing-full.css` `.app-shell.nav-minimal .now-playing-full-player-bar.player-bar` and responsive override | columns `80px minmax(174px, 1fr) 80px`; at `<=520px`, columns `68px minmax(136px, 1fr) 68px` and inherits base nav-minimal `column-gap: 8px`, `padding: 9px 12px 11px`. |
| Transport | `player.css` `.transport-row`, `.transport-button` plus nav-minimal rules | wide row height `52px`, gap `26px`, skip buttons `36px`, primary `56px`; compact/nav-minimal row height `56px`, gap `16px`, primary `52px`; at `<=520px` primary is `48px` with `12px` padding. |
| Progress | `player.css` `.progress-row` plus nav-minimal rules | wide columns `44px minmax(0, 1fr) 44px`, height `36px`, gap `12px`; compact columns `42px minmax(0, 1fr) 42px`, height `28px`, gap `8px`, padding `0 9px`. |
| Utility | `player.css` `.player-utility`, `.player-volume-row`, `.player-mode-row` plus compact rules | wide utility rows `44px 44px`, padding `0 16px 0 12px`; buttons `36px`; volume row columns `36px 148px 36px`, gap `14px`; mode row gap `14px`; compact/minimal utility width `80px` or `68px` at `<=520px`, mode gap `6px`, button size `36px` until `<=520px`, then `34px`. |

## Component Reuse Policy

| Component area | Electron source role | Flutter reuse allowed | Acceptance boundary |
| --- | --- | --- | --- |
| Footer shell | `footer.player-bar.now-playing-full-player-bar` hosts the whole immersive control. | Reuse Flutter full-page footer/container component. | Must keep fixed bottom placement, top-only radius, raised/idle transform role, and three layout columns. |
| Exit control | `button.player-track.now-playing-full-player-exit` contains only artwork shell plus fullscreen-exit overlay. | Reuse existing icon/artwork shell widgets. | Must stay in the left column, keep the same hit area role, and not display title/artist text in the immersive footer. |
| Transport controls | `MediaControlSurface` renders previous, primary play/pause/loading, next. | Reuse existing transport button components. | Must preserve order, center alignment, primary size per breakpoint, disabled/loading states, and callbacks. |
| Progress row | `MediaControlSurface` renders elapsed time, range input/loading strip, duration time. | Reuse existing progress/slider implementation. | Must preserve row order, fixed time columns, full-width center slider, draft seek behavior, and disabled duration handling. |
| Utility controls | `MediaControlSurface` renders wide volume/favorite/modes plus compact mode/voice/more. | Reuse existing utility buttons, volume slider, and menus. | Must preserve which controls are visible at each width and the right-column containment. |
| Menus/flyouts | More, compact playback mode, compact volume, and voice flyouts open from player controls. | Reuse `MenuFlyout` and Flutter flyout helpers. | Must preserve anchor side, checked items, disabled states, and footer pinning while open. |

## Flutter Surfaces

| Area | Source |
| --- | --- |
| Full page host and footer state | `lib/src/playback/now_playing_full_page.dart` |
| Shared player frame | `lib/src/playback/media_control_frame.dart` |
| Transport and progress | `lib/src/playback/media_control_surface.dart` |
| Utility controls | `lib/src/playback/media_control_utility.dart` |
| Player menus | `lib/src/playback/media_control_menus.dart` |
| Full page tests | `test/now_playing_page_test.dart` |
| Shared media control tests | `test/media_control_widget_test.dart` |

## Content And Behavior Matrix

| ID | Electron rule | Flutter target | Proof |
| --- | --- | --- | --- |
| NPF-MC-01 | Full page footer renders a `player-bar now-playing-full-player-bar` with a left exit button and a shared `MediaControlSurface`. | Full page footer has exactly one player surface: exit button on the left, transport/progress in the center, utility on the right. | Widget geometry test and screenshot. |
| NPF-MC-02 | Exit button label/title is `nowPlaying.exitImmersiveMode`; click calls `goBack`. | Exit button leaves immersive route and does not expose song ID or debug text. | Widget route/callback test. |
| NPF-MC-03 | Full page passes `isLoading={false}` into `MediaControlSurface`. | Full footer never shows the loading progress bar solely because the shared controller is loading. | Existing widget test. |
| NPF-MC-04 | Disabled state comes from no current song. | With no current song, transport, progress, wide volume, compact volume, and favorite are disabled/hidden like Electron. | Widget test. |
| NPF-MC-05 | Transport order is previous, play/pause, next. | Buttons keep order and callbacks; previous long-hold behavior may remain only where backed by the playback model. | Widget test. |
| NPF-MC-06 | Progress uses draft seek while dragging and commits only after a seek began. | Drag updates displayed progress; release without begin does not call seek. | Shared media control widget test. |
| NPF-MC-07 | Duration fallback is `durationSeconds || currentSong.duration || 0`. | Backend duration 0 falls back to current song duration. | Widget test. |
| NPF-MC-08 | Disabled surface uses volume value 0. | Disabled full footer shows disabled volume controls with value 0. | Widget test. |
| NPF-MC-09 | Favorite is hidden when `trackId == null`; active uses filled heart. | No song hides main favorite; current song toggles favorite. | Widget test. |
| NPF-MC-10 | Wide mode row exposes shuffle, repeat, repeat-one independently. | Wide full footer has independent mode buttons and active state. | Widget test. |
| NPF-MC-11 | Compact mode cycles once, shuffle, repeat, repeat-one, once; long press opens checked mode menu. | Compact full footer follows the same cycle and menu checked state. | Widget test. |
| NPF-MC-12 | Voice assistant appears only on Windows from `platform === 'win32'`. | macOS path omits voice; when shell exposes voice, utility keeps voice plus More without overflow. | Widget test. |
| NPF-MC-13 | More opens above the player button and keeps the full footer raised. | Opening More does not allow footer auto-hide until menu closes. | Widget test. |
| NPF-MC-14 | Full page More has queue-level actions: Quick Play, Random Play, Save Playlist, Clear Now Playing. | These items are present; Random Play is disabled when both queue and library are empty. | Widget/menu test. |
| NPF-MC-15 | Compact More also includes Playback Mode, Volume, Favorite. | At compact widths, More includes those utility substitutes; Favorite is disabled without a current song. | Widget/menu test. |
| NPF-MC-16 | Add To exists only with a current song; compact excludes the Favorites shortcut because compact has its own Favorite item. | Shared Add To helper is used with `includeFavorites: !isCompact && !currentSong.favorite`. | Widget/menu test. |
| NPF-MC-17 | Preference state is refreshed after More opens. | Preference lookup is async and updates the existing menu; no repeated build-time database calls. | Widget/menu test. |
| NPF-MC-18 | Full page More includes Play Artist and Play Album as direct current-song actions. | Keep Play Artist and Play Album outside the View submenu, matching `getNowPlayingFullMoreItems`. | Widget/menu test. |
| NPF-MC-19 | View submenu in the current full page opens Music Info, Lyrics, Album Art dialogs. | Keep those three confirmed dialog entries; do not add unconfirmed global bottom-player view entries here. | Widget/menu test. |
| NPF-MC-20 | Clear Now Playing closes full page and replaces the queue with empty. | Clear action exits immersive page and clears queue. | Widget test. |
| NPF-MC-21 | Add to Now Playing undo removes only the inserted queue range. | Undo does not remove existing duplicate song IDs. | Unit/widget test. |

## UI Layout Matrix

| ID | Electron rule | Flutter target | Proof |
| --- | --- | --- | --- |
| NPF-UI-01 | The immersive footer is `footer.player-bar.now-playing-full-player-bar` with `position: fixed`, `left/right/bottom: 0`, `z-index: 260`, top-only radius, and no bottom radius. | Footer stays bottom-aligned, independent from lyric/queue scrolling, with top-only rounded corners and no detached card wrapper. | Screenshot or widget rect test at desktop and compact widths. |
| NPF-UI-02 | Idle footer is translated down with `translateY(calc(100% - 10px))` and `opacity: 0.24`; `.is-player-bar-raised` resets transform and opacity to 1. | Idle and raised states match the interaction role; dialogs or menus pin the bar, queue panel alone does not. | Widget state test plus screenshot. |
| NPF-UI-03 | The footer has three semantic columns: left exit, center `MediaControlSurface`, right utility. Full-page CSS forces `.player-center` to column 2 and `.player-utility` to column 3. | Exit, play/pause center, progress row, and More/utility controls keep Electron column ownership. | Geometry test at 1000, 780, and 500 width. |
| NPF-UI-04 | In wide base layout, `.player-bar` grid is `minmax(280px, 0.9fr) minmax(420px, 1fr) minmax(280px, 0.9fr)` with rows `52px 38px`. | Flutter wide full footer keeps a large center player area with transport over progress and utility on the right. | Widget geometry test above 800px. |
| NPF-UI-05 | At compact immersive widths, full footer columns are `80px minmax(174px, 1fr) 80px`; base compact player rows are `74px 28px`. | At 721-800px or nav-minimal compact mode, exit shell occupies the left side, play button center equals viewport center, and utility remains inside the right 80px side. | Widget geometry test at 780/800. |
| NPF-UI-06 | At <=520px, full footer columns are `68px minmax(136px, 1fr) 68px` with `column-gap: 8px` and `padding: 9px 12px 11px`; base compact player columns are `minmax(112px, 1fr) minmax(136px, 176px) 68px`. Nav-minimal `.player-utility` centers the 74px two-button mode row inside the 68px column. | At 500/520 widths, exit column is 68px, center controls do not overflow, and utility buttons keep the Electron-centered overhang. | Widget geometry test at 500/520. |
| NPF-UI-07 | Wide transport row is horizontal previous, primary play/pause/loading, next with 26px gap and 52px row height. | Transport order is previous, play/pause, next; play button remains visually centered between skip buttons. | Widget order and center alignment test. |
| NPF-UI-08 | Compact/nav-minimal transport row uses 16px gap, 56px row height, and remains in the center column. | Compact skip buttons stay balanced around primary and do not collide with exit or utility columns. | Widget geometry test at 780 and 500. |
| NPF-UI-09 | Primary play button is 56px in wide layout, 52px in compact/nav-minimal layout, and 48px at `<=520px`. Loading state replaces icon with spinner inside the same primary slot. | Flutter primary button follows the Electron size bucket and does not shift layout when loading. | Widget size test for normal/loading states. |
| NPF-UI-10 | Skip transport buttons are 36px; base utility buttons are 36px. At <=520px compact utility buttons are 34px. | Previous/next, mode, voice, compact volume, and More use the Electron hit-area sizes for their width bucket. | Widget size test. |
| NPF-UI-11 | Wide progress row is `44px minmax(0, 1fr) 44px` with elapsed time, slider/loading strip, duration; compact progress row is `42px minmax(0, 1fr) 42px`. | Time labels keep fixed columns; the slider fills the center track and never compresses transport or utility controls. | Widget geometry test and seek test. |
| NPF-UI-12 | Full page passes `isLoading={false}` to `MediaControlSurface`, so the immersive footer does not show a loading strip just because the track object is loading. | Full footer progress row shows normal progress unless the full-page source explicitly confirms loading behavior. | Widget test for no loading strip in full page footer. |
| NPF-UI-13 | Exit button is `player-track now-playing-full-player-exit`; inside it only `player-artwork-shell`, `album-swatch`, and `player-artwork-overlay` with fullscreen-exit icon are rendered. | Immersive footer exit slot does not render title, artist, lyrics, or song ID; it only shows the exit shell. | Widget content absence/presence test. |
| NPF-UI-14 | Exit artwork shell is 72px in base player rules and 68px in compact/nav-minimal full footer; fullscreen-exit icon is 36px. | Flutter exit shell and icon follow these buckets or equivalent component constraints. | Widget size test. |
| NPF-UI-15 | Exit hover/focus keeps the button background transparent and changes only the inner artwork shell background/border/shadow. | Hover test sees shell state change, not a full left-column hover card. | Widget hover test. |
| NPF-UI-16 | Wide utility has two rows: top volume row with compact-volume placeholder hidden, volume toggle, 148px volume slider, favorite; bottom mode row with shuffle, repeat, repeat-one, hidden compact mode, optional voice, More. | Wide footer exposes independent wide controls in the same row grouping and order. | Widget order/visibility test above 800px. |
| NPF-UI-17 | Compact utility hides `.player-volume-row`; `.player-mode-row button:not(:nth-last-child(-n + 2))` is hidden, leaving compact mode plus optional voice plus More depending platform. | Compact footer shows compact mode, voice if available, and More, without wide volume/favorite/mode buttons taking space. | Widget visibility test at <=800px and platform variants. |
| NPF-UI-18 | Compact playback-mode button cycles once -> shuffle -> repeat -> repeat-one -> once; context menu or 520ms long press opens checked mode menu above the button. | Existing Flutter menu/flyout can be reused but must keep cycle order, checked item, and anchor relation. | Widget menu and long-press test. |
| NPF-UI-19 | Compact volume is a hidden wide replacement that opens a vertical `mini-mode-volume-popover player-compact-volume-popover` above the compact volume button. | If compact volume is exposed in Flutter, it opens from the compact utility slot and does not resize the footer. | Widget/flyout geometry test. |
| NPF-UI-20 | Voice assistant appears only when app info platform is `win32`; the flyout is separate from the footer but controlled by the utility button. | Non-Windows Flutter builds omit voice; Windows-capable shell keeps voice before More without overflowing the right column. | Platform-gated widget test. |
| NPF-UI-21 | More opens from the More utility button; full page pins the player bar while `moreMenu !== null`. | More menu keeps footer raised and closes without leaving pinned state. | Widget state/menu test. |
| NPF-UI-22 | Day full footer is cover-tinted and light; controls, time labels, and slider are readable with dark text/accent. | Existing Flutter styling may differ, but day mode must preserve readable text, progress contrast, active states, and control visibility. | Screenshot at matching song/theme/width. |
| NPF-UI-23 | Night full footer is dark and cover-tinted; controls, time labels, and slider are readable with light text. | Existing Flutter styling may differ, but night mode must preserve readable text, progress contrast, active states, and control visibility. | Screenshot at matching song/theme/width. |
| NPF-UI-24 | Favorite active state uses favorite accent and remains distinct from normal active mode buttons in day and night. | Favorite active state is not confused with shuffle/repeat active state. | Widget/screenshot test. |
| NPF-UI-25 | Disabled state comes from no current song; transport, progress, volume, compact volume, favorite, mode controls, and More-contained substitutes must be disabled/hidden according to Electron behavior. | Disabled controls are visibly disabled, do not call callbacks, and do not expose fallback actions. | Widget disabled-state test. |

## Not Confirmed For This Target

| Item | Reason |
| --- | --- |
| Adding the bottom-player global View entries See Artist, See Album, Local File into the full page More menu | The full page currently builds its own More menu; only Music Info, Lyrics, and Album Art are confirmed in that full-page menu path. |
| Pixel-perfect visual completion | Requires paired Electron and Flutter screenshots with the same song, theme, width, and platform. |

## Verification Commands

```sh
dart analyze lib/src/playback/now_playing_full_page.dart lib/src/playback/media_control.dart test/now_playing_page_test.dart
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage compact footer reuses nav-minimal surface"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage compact footer matches Electron column geometry"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage compact footer keeps voice and More inside utility"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage mid-width footer uses compact utility like Electron"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage wide footer uses Electron 0.9fr side columns"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage keeps wide layout with compact menu at 780px"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage wide More matches Electron queue and current song items"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage compact More includes Electron utility substitutes"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage compact More disables Favorite without current song"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage no active track disables full footer volume like Electron"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage Clear Now Playing exits fullscreen and clears queue"
flutter test --no-pub test/now_playing_page_test.dart --plain-name "NowPlayingFullPage More pins player bar while menu is open"
```

Screenshot proof remains required before claiming pixel-level visual alignment.
