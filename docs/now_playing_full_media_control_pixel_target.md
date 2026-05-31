# NowPlayingFullPage MediaControl Pixel Target

Electron is the only source of truth for this target. This document is the
acceptance target, not proof that Flutter is already aligned.

## Electron Evidence

| Surface | Electron source |
| --- | --- |
| Full page footer call site | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/NowPlayingFullPage.tsx:802` |
| Shared transport/progress/utility DOM | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/MediaControl.tsx:322` |
| Base player layout CSS | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/player.css:1` |
| Base transport/progress CSS | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/player.css:226` |
| Nav-minimal compact CSS | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/player.css:650` |
| Full page footer overrides | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/now-playing-full.css:392` |
| Responsive compact override | `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/responsive.css:58` |

## Confirmed Electron Structure

| Slot | Electron rule |
| --- | --- |
| Footer | `footer.player-bar.now-playing-full-player-bar`, fixed to bottom, top radius only, three grid columns. |
| Left | `button.player-track.now-playing-full-player-exit`, only artwork shell + fullscreen-exit overlay; no title, artist, lyrics, ID, or debug text. |
| Center | `.player-center` contains `.transport-row` above `.progress-row`. |
| Right | `.player-utility` owns volume/favorite/mode/voice/more controls. |
| Loading | Full page passes `isLoading={false}` to `MediaControlSurface`; footer progress is not loading only because the track is loading. |

## CSS Dimension Target

| Area | Wide Electron target |
| --- | --- |
| Footer grid | `minmax(280px, 0.9fr) minmax(420px, 1fr) minmax(280px, 0.9fr)` |
| Footer rows | `52px 38px` |
| Footer padding | `10px 16px` |
| Footer gap | `0` |
| Transport row | height `52px`, gap `26px` |
| Skip buttons | `36px`, padding `6px` |
| Primary button | `56px`, padding `14px` |
| Progress row | height `36px`, columns `44px minmax(0, 1fr) 44px`, gap `12px` |
| Slider track/thumb | track `2px`, thumb `18px` |
| Utility | rows `44px 44px`, padding `0 16px 0 12px`, buttons `36px`, volume slider `148px`, volume gap `14px`, mode gap `14px` |
| Exit shell | `72px`, radius `10px`; fullscreen-exit icon `36px` |

## Responsive Target

| Width bucket | Electron target |
| --- | --- |
| `1200px >= width >= 721px`, not nav-minimal | columns `minmax(clamp(200px, 24vw, 280px), 0.9fr) minmax(clamp(280px, 40vw, 420px), 1fr) minmax(clamp(200px, 24vw, 280px), 0.9fr)`; utility padding `0 8px`; volume row `36px 36px`; mode gap `8px`. |
| `800px >= width >= 721px`, not nav-minimal | columns `minmax(168px, 1fr) minmax(174px, 228px) 80px`; rows `74px 28px`; column gap `10px`; padding `8px 16px 10px`; transport height `56px`; primary `52px`; progress columns `42px minmax(0, 1fr) 42px`; progress gap `8px`; progress padding `0 9px`; utility buttons `36px`. |
| nav-minimal full page | full page overrides columns to `80px minmax(174px, 1fr) 80px`; inherits nav-minimal padding `8px 16px 10px`, gap `10px`, transport height `56px`, primary `52px`, progress row `42px minmax(0, 1fr) 42px`, progress gap `8px`, progress padding `0 9px`. |
| `width <= 520px`, nav-minimal full page | full page overrides columns to `68px minmax(136px, 1fr) 68px`; it still inherits base nav-minimal `padding: 9px 12px 11px`, `column-gap: 8px`, and primary button `48px` with `12px` padding. |

## Numeric Acceptance Points

These are derived from the confirmed CSS above. They assume full page footer is
raised, device pixel ratio 1, and viewport width equals logical width.

| Viewport | Expected geometry |
| --- | --- |
| `500px` | footer padding left/right `12`; column gap `8`; exit column `12..80`; center column `88..412`; utility column `420..488`; exit top `651`; primary top `661`; utility top `668`; utility row is centered in that column so the two 34px buttons plus 6px gap render `417..491`; progress elapsed left `21`, width `42`; slider `71..429`; duration right `479`; primary target size `48`. |
| `780px` | footer padding left/right `16`; column gap `10`; exit column `16..96`; center column `106..674`; utility column `684..764`; exit top `651`; primary top `659`; utility top `667`; progress elapsed left `25`, slider `75..705`, duration right `755`; primary `52`; utility buttons `36`. |
| `1000px` | side min `240`, center min `400`, content `968`, extra `88`; side column `268.29`; center column `431.43`; utility right `984`; center play x `500`; progress center bounds `340.29..659.71`. |
| `1400px` | side min `280`, center min `420`, content `1368`, extra `388`; side column `404.71`; center column `558.57`; utility right `1384`; center play x `700`. |

## Flutter Current Differences To Audit

| Item | Status |
| --- | --- |
| `<=520px` primary button | Electron CSS target is `48px`; current Flutter geometry tests guard this value from `player.css @media (max-width: 520px)`. |
| Full visual pixel parity | Not confirmed. Needs paired Electron and Flutter screenshots with the same song, theme, viewport, player state, and raised footer state. |
| Runtime Electron screenshot | Not captured in this pass. CSS target is confirmed from source, but visual completion remains unproven. |
| Flutter liquid-glass rendering vs Electron CSS backdrop/filter | Not proven pixel-identical. Must be judged by paired screenshots, not by widget tests alone. |

## Acceptance Criteria Before Saying Aligned

1. Flutter footer geometry matches the numeric acceptance points above at `500`, `780`, `1000`, and `1400` logical pixels.
2. Primary, skip, progress, utility, and exit shell sizes match Electron CSS in every width bucket.
3. Day and night screenshots are captured for Electron and Flutter using the same data and viewport.
4. Screenshot comparison shows no visible layout drift in footer columns, transport center, progress row, utility containment, padding, or gaps.
5. Any mismatch remains listed as a difference; do not call the page pixel-aligned until the mismatch is fixed or Electron evidence proves the target should change.
