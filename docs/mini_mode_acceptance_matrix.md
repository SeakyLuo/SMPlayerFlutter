# Mini Mode Electron Parity Target

Electron source of truth:

- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/MiniModePage.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/mini-mode.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/electron/window-controller.ts`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/MediaControl.tsx`

## Acceptance Matrix

| Area | Electron rule | Flutter target | Verification |
|---|---|---|---|
| Entry | Player menu item `mini-mode` enters mini mode. | Keep existing `MediaControl` menu entry and shell `_enterMiniMode` flow. | `media_control_widget_test.dart` existing menu coverage. |
| Window | Mini mode window is 360x360, minimum 360x360, always on top, resizable, not maximizable. | Keep `DesktopFeatureService._enterMiniMode` mini bounds behavior. | Existing desktop bridge logic plus runtime window check. |
| Host | Mini mode replaces the normal shell. | `_buildMiniModeHost()` returns only `MiniModeSurface`. | Shell mini mode tests. |
| Background | Current artwork covers the full surface over `#050607`. | `MiniModeSurface` root is black and artwork is full-size cover. | Runtime screenshot at 360x360. |
| Controls overlay | Controls hidden by default; pointer/focus shows 75% black overlay and controls with 180ms fade; leave hides after 5s. | Stack overlay uses opacity 0/0.75 and existing 5s hide timer. | `mini mode track copy follows Electron control visibility`. |
| Titlebar drag | Transparent top drag region is 32px high. | Top positioned `ShellWindowDragRegion` height is 32. | Runtime drag behavior. |
| Exit action | Top action row is top 7, left/right 8; exit button is 34x34 circular arrow-left. | Positioned top action with 34x34 `_MiniModeButton`. | Widget geometry or screenshot. |
| Transport | Previous/play-next transport is centered at 50%/50%, gap 10, hidden until controls show. | Centered Row with 40/48/40 buttons and 10px gaps. | Runtime screenshot at controls-visible state. |
| Transport buttons | Previous/next are 40x40 padding 9; primary is 48x48 padding 12 and has 18% white background. | `_MiniModeButton` explicit size/padding. | Widget geometry or screenshot. |
| Track copy | Title/artist centered between transport and bottom controls; title 16/700, artist 13/500, single-line ellipsis. | `_MiniModeTrackCopy` styles match. | Widget style assertion or screenshot. |
| Lyrics strip | Current lyric shows in bottom 58px gradient strip when controls are hidden. | `_MiniModeLyricsStrip` matches height, padding and gradient. | Runtime lyric screenshot. |
| Control lyric | For height >=361px, current lyric also appears inside track copy when controls are visible. | LayoutBuilder gates track-copy lyric at 361px. | Widget height test. |
| Low height | For height <=249px, track copy is hidden. | LayoutBuilder hides track copy at 249px. | Widget height test. |
| Bottom actions | Bottom container is left/right 10, bottom 0; actions row is 34px, progress row 18px. | Positioned bottom Column with 34px action row then 18px slider row. | Runtime screenshot or geometry test. |
| Action states | Active repeat/volume use 18% white background; favorite active is transparent with favorite accent. | `_MiniModeButton.active` and `.favorite` states. | Widget state test. |
| Progress | Progress track is 2px; thumb is hidden until hover/focus/drag. | `_MiniModeProgressSlider` uses 2px track and 0/5px thumb radius. | Widget interaction test. |
| Volume popover | Volume popover is 48x116, right -4, bottom 50, dark background, radius 8. | `_MiniModeVolumePopover` is positioned and sized to match. | Runtime screenshot or geometry test. |
| Voice action | Voice action only exists where voice assistant is supported. | Keep existing `supportsVoiceAssistant()` gate. | Platform-specific runtime check. |

## Not Changed

- Voice assistant still opens through Flutter's existing shell dialog path; Electron's mini-mode flyout geometry remains a separate unverified item.
- Runtime screenshot proof is still required before claiming pixel-level completion.
