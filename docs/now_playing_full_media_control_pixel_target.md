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
| Left | `button.player-track.now-playing-full-player-exit`, only artwork shell + transparent album swatch + fullscreen-exit overlay; no title, artist, lyrics, ID, debug text, or real song artwork. |
| Center | `.player-center` contains `.transport-row` above `.progress-row`. |
| Right | `.player-utility` owns volume/favorite/mode/voice/more controls. |
| Loading | Full page passes `isLoading={false}` to `MediaControlSurface`; footer progress is not loading only because the track is loading. |

## CSS Dimension Target

| Area | Wide Electron target |
| --- | --- |
| Footer position | fixed to bottom with `left: 0`, `right: 0`, `bottom: 0`, `height: var(--player-height)` / 120px; wide full-page z-index target is 260, but compact `max-width: 800px` / nav-minimal player cascade lowers `.player-bar` to z-index 110, below the queue popover z-index 220 |
| Idle footer | `translateY(calc(100% - 10px))`, so a 120px footer renders at `viewportBottom - 10` with only 10px visible; opacity `0.24`; raised transform is `0` and opacity `1` |
| Footer grid | `minmax(280px, 0.9fr) minmax(420px, 1fr) minmax(280px, 0.9fr)` |
| Footer rows | `52px 38px` |
| Footer padding | `10px 16px` |
| Footer border | wide/base footer keeps the `1px` border on all four sides; nav-minimal/compact keeps top border only from the nav-minimal CSS override |
| Footer backdrop | wide night is controlled by the later `body.night-mode .app-shell .player-bar` cascade from `player.css`: `blur(28px)`, border `var(--night-border)`, surface `rgba(17,22,28,0.9)`, cover wash `rgba(var(--player-cover-rgb),0.22)`, highlight `rgba(255,255,255,0.055)` to `rgba(var(--accent-rgb),0.12)`, shadow `0 -18px 48px rgba(0,0,0,0.34)`, and top inset `rgba(255,255,255,0.045)`; night compact/nav-minimal uses `blur(28px) saturate(145%)` from the later nav-minimal `player.css` cascade; day uses `blur(18px) saturate(140%)` and top inset `rgba(255,255,255,0.78)` |
| Footer gap | `0` |
| Center stack | `.player-center` is a column centered in rows `1 / 3` with `gap: 4px` |
| Transport row | height `52px`, gap `26px` |
| Skip buttons | `36px`, padding `6px`; previous/next icon drawing is explicitly preserved from the current Flutter implementation per user request and is not changed in this pass |
| Primary button | `56px`, padding `14px`; full-page night/default border `rgba(var(--accent-rgb), 0.42)` and shadow `0 12px 26px rgba(0, 0, 0, 0.32)`; full-page day border `transparent` and shadow `0 12px 26px var(--accent-shadow)` |
| Non-primary transport/utility buttons | full-page foreground starts from `.now-playing-full-player-bar`: night/default `rgba(255,255,255,0.86)`, day `var(--text-strong)`. Because `player.css` loads after `now-playing-full.css`, night/default non-favorite utility hover resolves to `rgba(var(--accent-rgb),0.18)` and active utility resolves to `rgba(var(--accent-rgb),0.22)`; day full-page hover/active resolves to `rgba(var(--accent-rgb),0.1)`. Favorite keeps the later full-page override below. Disabled keeps the foreground bucket and dims through `opacity: 0.65` |
| Progress row | height `36px`, columns `44px minmax(0, 1fr) 44px`, gap `12px`; full-page night/default label color `rgba(255,255,255,0.66)`, full-page day label color `var(--text-muted)` |
| Slider input/track/thumb | input height `18px`, track `2px`, thumb `18px`; disabled input opacity `0.65`, disabled thumb opacity `0.8` |
| Utility | rows `44px 44px`, padding `0 16px 0 12px`, buttons `36px`, volume slider `148px`, volume gap `14px`, mode gap `14px`; volume button icon is driven by Electron's live slider value, not only the last persisted parent volume; compact mode cycle/menu interactions close the compact volume popover first |
| Wide volume tooltip | bottom edge `8px` above the `22px` slider wrap |
| Exit shell | `72px`, radius `10px`; fullscreen-exit icon `36px` |

## Responsive Target

| Width bucket | Electron target |
| --- | --- |
| `1200px >= width >= 721px`, not nav-minimal | columns `minmax(clamp(200px, 24vw, 280px), 0.9fr) minmax(clamp(280px, 40vw, 420px), 1fr) minmax(clamp(200px, 24vw, 280px), 0.9fr)`; utility padding `0 8px`; compact volume + favorite only in volume row; compact mode + More only in mode row; both rows use 8px gaps. If voice is present, the utility row needs at least `140px` (`36 + 8 + 36 + 8 + 36` plus `8px` side padding). At `1201px`, this media query no longer applies and wide volume/mode controls return. |
| `800px >= width >= 721px`, not nav-minimal | columns `minmax(168px, 1fr) minmax(174px, 228px) 80px`; rows `74px 28px`; column gap `10px`; padding `8px 16px 10px`; transport height `56px`; primary `52px`; progress columns `42px minmax(0, 1fr) 42px`; progress gap `8px`; progress padding `0 9px`; utility buttons `36px`; volume row hidden. At `801px`, this media query no longer applies, so the 1200px condensed utility returns with volume row visible and primary `56px`. |
| nav-minimal full page | full page overrides columns to `80px minmax(174px, 1fr) 80px`; inherits nav-minimal padding `8px 16px 10px`, gap `10px`, transport height `56px`, primary `52px`, progress row `42px minmax(0, 1fr) 42px`, progress gap `8px`, progress padding `0 9px`. This full-page override continues below the `800px >= width >= 721px` responsive rule until the `<=520px` full-page override changes the side columns. |
| `width <= 520px`, nav-minimal full page | full page overrides columns to `68px minmax(136px, 1fr) 68px`; it still inherits base nav-minimal `padding: 9px 12px 11px`, `column-gap: 8px`, and primary button `48px` with `12px` padding. |

## Numeric Acceptance Points

These are derived from the confirmed CSS above. They assume full page footer is
raised, device pixel ratio 1, and viewport width equals logical width.

| Viewport | Expected geometry |
| --- | --- |
| `500px` | footer padding left/right `12`; column gap `8`; exit column `12..80`; center column `88..412`; utility column `420..488`; exit top `651`; transport row `88..412`, top `657`, height `56`; primary top `661`; utility top `668`; utility row is centered in that column so the two 34px buttons plus 6px gap render `417..491`; compact More menu clamps to viewport bounds with right `492` and bottom `752` without resizing the footer; progress row top `721`, height `28`; progress elapsed left `21`, width `42`; slider `71..429`; duration right `479`; primary target size `48`. |
| `520px` | still in the `max-width: 520px` bucket: exit column `12..80`, center column `88..432`, utility column `440..508`; transport row `88..432`; primary remains `48`; More right edge `511`; progress row `88..432`, top `721`, height `28`. |
| `521px` | exits the `max-width: 520px` bucket while staying nav-minimal full page: exit column `16..96`, center column `106..415`, utility column `425..505`; transport row `106..415`; primary returns to `52`; More right edge `504`; progress row `106..415`, top `722`, height `28`. |
| `720px` | below the Electron `800px >= width >= 721px` non-minimal media rule but still inside the full-page nav-minimal column override: exit column `16..96`, center column `106..614`, utility column `624..704`; transport row `106..614`, top `657`, height `56`; primary `52`; More right edge `703`; progress row `106..614`, top `722`, height `28`; volume row hidden. |
| `721px` | last pixel of the Electron `800px >= width >= 721px` rule and also full-page nav-minimal: exit column `16..96`, center column `106..615`, utility column `625..705`; transport row `106..615`, top `657`, height `56`; primary `52`; More right edge `704`; progress row `106..615`, top `722`, height `28`; volume row hidden. |
| `780px` | footer padding left/right `16`; column gap `10`; exit column `16..96`; center column `106..674`; utility column `684..764`; exit top `651`; transport row `106..674`, top `657`, height `56`; primary top `659`; utility top `667`; progress row top `722`, height `28`; progress elapsed left `25`, slider `75..705`, duration right `755`; primary `52`; volume row and wide mode buttons hidden; utility row is centered in the 80px column so compact mode + More render `685..763` with a 6px gap and 36px buttons. If voice assistant is available, Electron's `nth-last-child(-n + 2)` rule instead keeps voice + More in the same `685..763` span and hides compact mode. Night compact uses the later nav-minimal cascade: border `var(--night-border)`, shadow `0 -12px 36px rgba(0,0,0,0.34)`, inset `rgba(255,255,255,0.045)`, and `blur(28px) saturate(145%)`. |
| `801px` | first pixel after the Electron `max-width: 800px` rule, so it uses the `1200px >= width >= 721px` condensed utility bucket: side column `215.62`; center column `337.76`; transport/progress width `337.76`; volume row returns as compact volume + favorite with an 8px gap and right edge `777`; compact mode + More use the same 8px gap and right edge `777`; primary returns to `56`; no utility Row overflow is allowed. |
| `1000px` | side min `240`, center min `400`, content `968`, extra `88`; side column `268.29`; center column `431.43`; transport row is `431.43 x 52`, progress row is `431.43 x 36`, and their vertical gap is `4`; utility right `984`; utility inner row width `252.29`; compact volume + favorite are `36 + 8 + 36` and right-align at `976`; compact volume popover is `48 x 116`, overlays outside the footer frame, right edge is compact volume button right + `6`, and bottom edge is compact volume button top - `8`, matching Electron `right: -6px` and `bottom: 44px`; compact mode + More use 8px gap and More right-aligns at `976`; center play x `500`; primary top `652`; progress row top `710`; progress center bounds `340.29..659.71`. |
| `1200px` | last pixel of Electron condensed utility: side min `280`, center min `420`, content `1168`, extra `188`; side column `340.43`; center column `487.14`; transport/progress widths are `487.14`; utility column right `1184`; compact volume + favorite use 8px gap and right-align at `1176`; compact mode + More use 8px gap and More right-aligns at `1176`; wide volume slider and wide mode buttons are hidden. |
| `1201px` | first pixel after Electron condensed utility rule: side min `280`, center min `420`, content `1169`, extra `189`; side column `340.75`; center column `487.5`; transport/progress widths are `487.5`; wide volume row returns with `36 + 14 + 148 + 14 + 36` and right-aligns at `1169`; wide mode row uses 14px gaps and More right-aligns at `1169`; compact volume and compact mode are hidden. |
| `1400px` | side min `280`, center min `420`, content `1368`, extra `388`; side column `404.71`; center column `558.57`; transport row is `558.57 x 52`, progress row is `558.57 x 36`, and their vertical gap is `4`; progress elapsed column starts at `420.71` with width `44`, slider spans `476.71..923.29`, duration column ends at `979.29` with width `44`, progress gaps are `12`, and label font size is `13`; utility inner row width `376.71`; volume row content is `36 + 14 + 148 + 14 + 36` and right-aligns at `1368`; mode row buttons use 14px gaps and More right-aligns at `1368`; center play x `700`. |

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
