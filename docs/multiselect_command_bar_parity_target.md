# MultiSelectCommandBar Electron Parity Target

This document is the acceptance target for aligning Flutter `MultiSelectCommandBar` with Electron.

Electron is the only source of truth. Items without runtime screenshot or interaction proof are marked as unconfirmed and must not be reported as aligned.

## Confirmed Electron Evidence

- Component source: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/MultiSelectCommandBar.tsx`
  - Exports `MULTI_SELECT_COMMAND_BAR_SCROLL_SPACER = 108`.
  - Renders a body-level portal and measures the nearest `.workspace-content` or `.now-playing-full-page`.
  - Bottom offset is derived from `.player-bar` when present, otherwise `12px`.
  - Visibility is controlled by `.is-visible`; the bar remains mounted and animates opacity/translate.
  - Cancel clears selection and exits multi-select.
  - Direct Play, Remove, Add-To select, and extra actions that opt in call `hideIfNeeded`.
  - More menu is anchored to the More button at `rect.left`, `rect.top - 8`.
- Style source: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/albums.css`
  - `.multi-select-command-bar` is fixed, width equals measured content host width, height `64px`.
  - Desktop spacing: `gap: 18px`, padding `0 18px 0 26px`, count min-width `154px`, action gap `9px`.
  - Border: top-only rounded `17px 17px 0 0`, border bottom removed.
  - Day surface: gradient `rgba(249,252,255,.78)` to `rgba(234,241,249,.58)` over `rgba(246,250,255,.68)`.
  - Blur: `blur(30px) saturate(165%)`.
  - Shadow: `0 -16px 44px rgba(42,54,72,.18)` plus inset top highlight.
  - Buttons/selects: min-width `72px`, height `36px`, radius `8px`, padding `0 12px`, gap `7px`, font size `13px`, weight `640`.
  - Icons are `16px`.
  - Separator is `1px x 28px`, background `rgba(92,103,118,.22)`.
  - Hover changes border/background/text/shadow; disabled opacity is `.46`.
  - More button is hidden by default.
- Responsive source: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/albums.css`
  - `max-width: 760px`: bar gap `12px`, padding `0 12px 0 18px`, count min-width `112px`, selection actions and selection separator hidden, More shown at `44px x 36px`.
  - `max-width: 520px`: gap `8px`, padding left `12px`, padding right `10px`, count max-width `96px`, separators hidden, button min-width `40px`, Add-To max-width `88px`, Add-To chevron hidden, remove/extra/selection actions hidden, Cancel becomes icon-only `40px`, More becomes `40px x 36px`.
- Night style source: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/albums.css`
  - Night bar uses dark gradient `rgba(31,38,48,.92)` to `rgba(19,24,31,.84)` over `rgba(18,24,31,.88)`.
  - Night border is `rgba(255,255,255,.09)`.
  - Night shadow is `0 -16px 44px rgba(0,0,0,.32)`.
  - Night buttons use `var(--night-border)`, `rgba(255,255,255,.065)`, and `var(--night-text)`.
  - Night hover uses accent-tinted background and accent-mixed text.
- Electron call sites:
  - Albums, Artists, Local, Search, Recent, Now Playing, Now Playing Full Playlist, and HeaderedPlaylistControl all reuse the same shared component.
  - List/grid content uses the exported `108px` spacer when multi-select is visible.

## Flutter Implementation Evidence

- Shared Flutter component: `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/multi_select_command_bar.dart`
  - Exports `multiSelectCommandBarScrollSpacer = 108.0`.
  - Uses `Align(alignment: Alignment.bottomCenter)` inside the caller's layout instead of a measured body-level portal.
  - Returns `SizedBox.shrink()` when not visible, so hidden-state animation is not preserved.
  - Uses `ClipRRect`, `BackdropFilter`, and a `Container` with Electron-like day colors.
  - Uses a `SingleChildScrollView` for horizontal action overflow.
  - Uses `MediaQuery` breakpoints at `760` and `520`.
  - Uses Flutter `TextButton.icon` and `IconButton` styles, but hover/pressed/night variants are not encoded to match Electron CSS.
- Flutter call sites:
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/albums_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/artists_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/search_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/headered_playlist_layout.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/recent/recent_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/playback/now_playing_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/playback/now_playing_full_page.dart`

## Acceptance Matrix

| Area | Electron Rule | Flutter Gap | Target |
| --- | --- | --- | --- |
| Mounting and animation | Bar remains mounted and toggles opacity/pointer-events/translate. | Flutter removes the widget when `visible == false`; entry/exit animation cannot match Electron. | Keep the surface mounted in callers while visible state controls opacity, pointer behavior, and slide. |
| Placement | Fixed to measured content host left/width; bottom is above player bar or `12px`. | Flutter is bottom-aligned within each caller and may not equal workspace width/player-bar offset. | Shared Flutter primitive must receive or measure the same host geometry and align to the same bottom rule on every call site. |
| Size | Height `64px`, scroll spacer `108px`. | Spacer matches; height matches. | Preserve both values. |
| Border | Top radius `17px`; bottom border removed. | Flutter `Border.all` draws bottom border too. | Remove bottom border visually while preserving top/side border. |
| Day surface | CSS gradient, surface color, blur, shadow, inset highlight. | Day constants mostly mirror Electron, but Flutter uses blur without saturation and different rendering primitives. | Match observable day rendering with screenshot proof; saturation difference must be visually checked. |
| Night surface | Dedicated dark gradient, border, shadow, button, hover rules. | Flutter shared colors are day-only in this component. | Add theme-aware night visuals matching Electron CSS. |
| Desktop layout | Count min-width `154px`; action gap `9px`; no horizontal scroll; selection actions visible; More hidden. | Flutter wraps actions in a horizontal `SingleChildScrollView`; separators also add horizontal margin. | Desktop must be a fixed flex row with Electron gaps and no visible scroll behavior. |
| `<=760px` layout | Count min-width `112px`; selection actions hidden; More `44px`. | Flutter hides selection actions and shows More, but scroll container remains. | Keep the same visible action set and remove scroll-based overflow behavior. |
| `<=520px` layout | Count max-width `96px`; all separators hidden; Cancel icon-only; remove/extra/selection hidden; Add-To keeps truncated label up to `88px`; More `40px`. | Flutter hides Add-To label entirely when compact; Electron keeps a truncated Add-To label. | Add-To compact behavior must match Electron: text may ellipsize, chevron hidden, button max-width `88px`. |
| Buttons | Min `72px`, height `36px`, radius `8px`, padding `12px`, gap `7px`, font `13px/640`, icon `16px`. | Flutter close but uses `FontWeight.w600`, TextButton defaults may affect hover/pressed layout. | Encode explicit style and geometry assertions for button size, padding, icon size, and label style. |
| Hover | Hover border/background/text/shadow changes. | Flutter hover color is mostly transparent or default; not Electron-specific. | Add Electron hover state for buttons/selects in day and night. |
| Disabled | Disabled opacity `.46`; disabled cursor default in Electron. | Flutter wraps action in `Opacity(.46)` and disables callback. | Preserve opacity `.46`; verify disabled text/icon/background match screenshots. |
| More menu | Anchored above More button at `top - 8`; includes remove, extra actions, separator, select-all, reverse, clear. | Flutter uses `localToGlobal(0, -8)` and same item intent. | Keep menu content and anchor; verify exact position and overflow set at both breakpoints. |
| Add-To action | Electron can be button invoking external menu or native hidden select; Albums/Artists use external menu. | Flutter uses shared flyout builder and richer Add-To targets in several pages. | For UI target, match action geometry/visibility; business eligibility remains page-specific and must be checked per page before changes. |
| Hide-after-operation | Component-level direct actions call hide only when setting is enabled; cancel always clears and exits. | Flutter passes `hideAfterOperation` and mirrors this in many direct actions. | Preserve only confirmed per-call-site behavior; do not add fallback hiding to unverified flows. |
| Shared usage | One shared component across all listed Electron pages. | Flutter has one shared component, but host placement differs by caller. | Fix in the shared primitive and only adjust callers where geometry requires it. |

## Confirmed Remaining Differences

- Placement is caller-local instead of Electron's measured workspace/player-bar fixed placement.
- Runtime screenshot parity is still unconfirmed.
- Exact body-level portal semantics remain page/caller dependent.

## Screenshot-Driven Target: Oversized Bottom Bar

User screenshot `截屏2026-06-01 23.44.06.png` shows the Flutter bottom bar rendered visually heavier than Electron:

- Buttons read as large Material controls instead of Electron's compact `36px` command buttons.
- Button labels read much larger/bolder than Electron's `13px / 640` labels.
- Icons read larger than Electron's `16px` command icons.
- The whole bar visually dominates the bottom area instead of reading as a compact glass command surface.

Confirmed Electron CSS target:

- Button visual height must be exactly `36px`.
- Material tap target expansion must not increase the rendered button box.
- Button label style must be explicitly constrained to `font-size: 13px`, `font-weight: 640`, `line-height: 1`.
- Button icon theme must be explicitly constrained to `16px`.
- The command bar surface stays `64px` high.

Implementation target:

- Disable Material's padded tap target for this command surface.
- Apply the Electron label style at the button content layer, not only through inherited page typography.
- Add widget assertions for rendered button height, label font size, and tap target mode.

## Unconfirmed Items

- Runtime pixel values are not yet verified with same Electron and Flutter window size, theme, data, and selection state.
- Exact rendered color blending difference between CSS `backdrop-filter: blur(30px) saturate(165%)` and Flutter `ImageFilter.blur(30,30)` is unconfirmed.
- Exact `TextButton.icon` intrinsic label baseline versus Electron button text baseline is unconfirmed.
- Page-specific Add-To business menu eligibility is not part of this visual target until each page call chain is re-audited.

## This Target Allows Changing

- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/multi_select_command_bar.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/command_bar_colors.dart`
- The listed caller files only for passing geometry/visibility information required to match Electron placement.
- Focused widget tests for geometry/responsive behavior.

## This Target Does Not Allow Changing

- AlbumTile hover action style.
- ArtistsPage/AlbumsPage search field, suggestion panel, or history panel behavior.
- Page-specific Add-To business rules unless separately audited against Electron call chains.
- Any fallback behavior not present in Electron.

## Required Verification

- Electron screenshots at the same window size, theme, selected count, and enabled/disabled states:
  - Desktop width above `760px`, day and night.
  - Width between `521px` and `760px`, day and night.
  - Width `520px` or below, day and night.
  - More menu open at `<=760px`.
- Flutter screenshots for the same states after implementation.
- Focused widget tests should assert:
  - `multiSelectCommandBarScrollSpacer == 108.0`.
  - Height is `64`.
  - Desktop More button is absent and selection actions are visible.
  - At `760px`, selection actions are hidden and More is `44 x 36`.
  - At `520px`, Cancel is icon-only `40 x 36`, More is `40 x 36`, Add-To uses max-width `88` with ellipsis rather than disappearing text.
  - Hidden state remains mounted and animates pointer/opacity/offset.
