# MultiSelectCommandBar Electron Parity Target

This document is the acceptance target for aligning Flutter `MultiSelectCommandBar` with Electron.

Electron is the only source of truth. Items without runtime screenshot or interaction proof are marked as unconfirmed and must not be reported as aligned.

## Confirmed Electron Evidence

- Component source: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/MultiSelectCommandBar.tsx`
  - Exports `MULTI_SELECT_COMMAND_BAR_SCROLL_SPACER = 108`.
  - Renders a body-level portal and measures the nearest `.workspace-content` or `.now-playing-full-page`.
  - Bottom offset is derived from `.player-bar` when present, otherwise `12px`.
  - Visibility is controlled by `.is-visible`; the bar remains mounted and animates opacity/translate.
  - Hidden state sets `aria-hidden`.
  - Layout changes animate `left`, `width`, and `bottom` with `160ms ease`; visibility animates opacity/translate with `180ms ease`.
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
  - Hover changes border/background/text/shadow; disabled opacity is `.46`, and day disabled shadow becomes a single inset `rgba(255,255,255,.62)` highlight.
  - Button focus is not styled as hover in the MultiSelectCommandBar CSS; the only local focus-related rule is `outline: none` on the internal `select`.
  - More button is hidden by default.
- Responsive source: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/albums.css`
  - `max-width: 760px`: bar gap `12px`, padding `0 12px 0 18px`, count min-width `112px`, selection actions and selection separator hidden, More shown at `44px x 36px`.
  - `max-width: 520px`: gap `8px`, padding left `12px`, padding right `10px`, count max-width `96px`, separators hidden, button min-width `40px`, Add-To max-width `88px`, Add-To chevron hidden, remove/extra/selection actions hidden, Cancel becomes icon-only `40px` with zero padding, More becomes `40px x 36px`.
- Night style source: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/albums.css`
  - Night bar uses dark gradient `rgba(31,38,48,.92)` to `rgba(19,24,31,.84)` over `rgba(18,24,31,.88)`.
  - Night border is `rgba(255,255,255,.09)`.
  - Night shadow is `0 -16px 44px rgba(0,0,0,.32)`.
  - Night buttons use `var(--night-border)`, `rgba(255,255,255,.065)`, and `var(--night-text)`.
  - Night hover uses accent-tinted background and accent-mixed text.
- Electron call sites:
  - Albums, Artists, Local, Search, Recent, Now Playing, Now Playing Full Playlist, and HeaderedPlaylistControl all reuse the same shared component.
  - List/grid content uses the exported `108px` spacer when multi-select is visible.
  - Local also applies `.local-page.is-selection-mode .local-scroll-shell { padding-bottom: 108px; }` in `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/local.css`.
  - Local passes `showPlay={selectedQueueSongIds.length > 0}` and `showAddTo={selectedQueueSongIds.length > 0}`, so folder-only selections with no songs hide Play/Add-To while keeping Remove/Move.
  - Local builds `selectedMoveToFolderMenuItems` with `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/localMoveToFolderMenu.ts` and disables the Move To Folder extra action when `selectedLocalItemCount === 0 || selectedMoveToFolderMenuItems.length === 0`.
  - Electron's local move helper excludes a selected folder itself and its parent from move targets, while keeping other descendants reachable through submenu tree items.
  - Local `HideMultiSelectAfterOperation` does nothing when `hideMultiSelectCommandBarAfterOperation` is disabled; Play/Add-To/Move keep the current selection in that setting-off state.
  - Albums and Search direct Play are routed through the shared Electron `MultiSelectCommandBar`, so `hideIfNeeded` only clears/cancels when `hideMultiSelectCommandBarAfterOperation` is enabled.
  - Recent passes `showPlay={activeTab !== 'searches'}` and `showAddTo={activeTab !== 'searches'}` in `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/RecentPage.tsx`, so recent-search multi-select hides Play/Add-To while keeping Remove.
  - HeaderedPlaylistControl passes `onRemove={removable ? ... : undefined}`, and the shared Electron component only renders Remove when `onRemove` is present.
  - HeaderedPlaylistControl opens the multi-select Add-To menu with `setAddToMenu({ x: event.clientX, y: event.clientY })`, unlike Albums/Artists/Recent/Search/Local/Now Playing call sites that anchor their Add-To menus above the button.
  - Now Playing Add-To menu operations and direct Play hide selection only when `hideMultiSelectCommandBarAfterOperation` is enabled; Remove clears selection inside the remove callback.
  - Search applies `.search-page.is-selection-mode .search-result-stack { padding-bottom: 108px; }` in `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/search.css`.

## Flutter Implementation Evidence

- Shared Flutter component: `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/multi_select_command_bar.dart`
  - Exports `multiSelectCommandBarScrollSpacer = 108.0`.
  - Uses `Align(alignment: Alignment.bottomCenter)` inside the caller's layout; normal shell pages receive the shell bottom inset, and now-playing full renders the bar from the full-page Stack instead of the queue panel.
  - Responsive rules are evaluated against the Flutter host constraints, which now match workspace/full-page width for confirmed command bar hosts.
  - Keeps hidden state mounted with opacity, pointer ignore, Electron `180ms ease` opacity/slide timing, and a `16px / 64px` slide fraction.
  - Mirrors hidden `aria-hidden` with `ExcludeSemantics(excluding: !visible)`.
  - Animates bottom inset, command bar width, and asymmetric left/right bleed offset with Electron `160ms ease` layout timing.
  - Uses a top-only `ClipRRect` plus `GlassContainer` liquid-glass surface with Electron `30px` blur and `1.65` saturation targets, while the foreground border painter still draws only the left/top/right border.
  - Uses a foreground border painter that draws the left, top, and right border only, matching Electron's `border-bottom: 0`.
  - Uses a fixed flex row; horizontal scroll overflow was removed for this command surface.
  - Uses Electron breakpoints at `760` and `520` against the command bar host width.
  - Uses explicit `TextButton` and `IconButton` styles for `36px` command controls, `13px / 640` labels, `16px` icons, and `MaterialTapTargetSize.shrinkWrap`.
  - Widget assertions cover Electron surface padding at desktop, `760px`, and `520px`, plus desktop/tablet separator heights.
  - Supports symmetric `horizontalBleed` and asymmetric `leftBleed`/`rightBleed` so padded pages can render the bar at the workspace host width instead of the inner page padding width.
  - Local page scroll content now receives `108px` bottom padding in multi-select mode, matching Electron's local scroll shell CSS.
  - Local page now only shows Play/Add-To when selected local items produce playable song ids, matching Electron's `selectedQueueSongIds.length > 0` gating.
  - Local Move To Folder extra action now uses Electron's source/parent target filtering and is disabled when the selected move menu has no targets.
  - Local Play/Add-To/Move now preserve selection when `hideMultiSelectCommandBarAfterOperation` is disabled, matching Electron's setting-gated `HideMultiSelectAfterOperation`.
  - Albums and Search page-level Play tests now preserve selection when `hideMultiSelectCommandBarAfterOperation` is disabled, matching Electron shared `hideIfNeeded`.
  - Recent page now hides Play/Add-To on the searches tab, matching Electron's `activeTab !== 'searches'` gating.
  - HeaderedPlaylistControl now only passes Remove when `removable` is true, matching Electron's `onRemove` gating.
  - HeaderedPlaylistControl now opts into pointer-anchored Add-To menu positioning, while other call sites keep the Electron `rect.top - 8` above-button positioning.
  - Now Playing renders the shared bar as a panel overlay outside its `24px` content padding, matching Electron's portal placement rather than the inner page padding box.
  - Now Playing direct Play and Add-To menu operations now rely on `hideAfterOperation` instead of unconditionally clearing selection, matching Electron's setting-gated behavior; Remove still clears selection inside its remove callback.
  - Flutter-side golden PNGs now cover desktop, `760px`, `520px`, night, disabled, zh-CN CJK-font desktop, and zh-CN `760px` compact visual states under `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/test/goldens/`.
- Flutter call sites:
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/albums_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/artists_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/search_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/headered_playlist_layout.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/recent/recent_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/playback/now_playing_page.dart`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/playback/immersive_mode_page.dart`

## Acceptance Matrix

| Area | Electron Rule | Flutter Gap | Target |
| --- | --- | --- | --- |
| Mounting and animation | Bar remains mounted and toggles opacity/pointer-events/translate with `180ms ease`; layout `left/width/bottom` changes use `160ms ease`; hidden state is `aria-hidden`. | Fixed in the shared Flutter component; Artists and Recent no longer conditionally remove the shared bar; bottom/width/bleed layout changes now use the Electron timing; hidden state excludes semantics. | Keep callers mounted and preserve separate `160ms` layout, `180ms` visibility timing, and hidden semantics. |
| Placement | Fixed to measured content host left/width; bottom is above player bar or `12px`. | Normal shell pages pass the confirmed `17px` inset derived from Flutter workspace/player overlap and Electron `-1px`; Local/Albums and Recent bleed across page padding so their surface width resolves to the workspace host width; Now Playing renders the bar as a panel overlay outside its content padding; now-playing full is lifted to the full-page Stack with bottom `playerHeight - 1`. | Preserve shell inset, page-padding bleed, Now Playing overlay placement, and now-playing full overlay placement; screenshot verification still required. |
| Scroll spacer | Content avoids the fixed bar with `108px` spacer/padding where Electron applies it. | Local scroll shell was missing the `108px` multi-select bottom padding; fixed in `LocalPageContentPanel`. | Preserve `108px` scroll spacer/padding on Local, Search, Albums, Artists, Recent, Now Playing, Now Playing Full, and HeaderedPlaylistControl where Electron has it. |
| Size | Height `64px`, scroll spacer `108px`. | Spacer matches; height matches. | Preserve both values. |
| Border | Top radius `17px`; bottom border removed. | Fixed in the shared Flutter component with a top/side-only border painter. | Preserve top/side-only border; keep bottom border absent in screenshot verification. |
| Day surface | CSS gradient, surface color, `blur(30px) saturate(165%)`, shadow, inset highlight. | Flutter now uses the project liquid-glass `GlassContainer` with `blur: 30` and `saturation: 1.65`, plus the existing gradient/tint and shadow layers; different rendering primitives still require runtime screenshot proof. | Preserve liquid-glass surface parameters and match observable day rendering with screenshot proof. |
| Night surface | Dedicated dark gradient, border, shadow, button, hover rules. | Fixed in shared Flutter colors/styles, with widget assertions and Flutter-side golden coverage. | Preserve theme-aware night visuals; Electron/Flutter runtime screenshot comparison still required. |
| Desktop layout | Count min-width `154px`; action gap `9px`; no horizontal scroll; selection actions visible; More hidden. | Fixed in shared Flutter component. | Preserve the fixed flex row and assertions. |
| `<=760px` layout | Count min-width `112px`; separator height `26px`; selection actions hidden; More `44px`. | Fixed in shared Flutter component. | Preserve visible action set, separator height, and More dimensions. |
| `<=520px` layout | Count max-width `96px`; count gap `7px`; all separators hidden; button min-width `40px`; Cancel icon-only with zero padding; remove/extra/selection hidden; Add-To keeps truncated label up to `88px`; More `40px`. | Fixed in shared Flutter component. | Preserve adaptive count width, icon-only Cancel padding, Add-To text truncation, hidden chevron, and `88px` max width. |
| Buttons | Desktop/tablet min `72px`, phone min `40px`, height `36px`, radius `8px`, padding `12px`, gap `7px`, font `13px/640`, icon `16px`. | Fixed in shared Flutter component with explicit styles and geometry assertions. | Preserve explicit button size, padding, icon size, and label style. |
| Hover/focus | Hover border/background/text/shadow changes; night hover uses no box-shadow; button focus is not styled as hover. | Flutter has Electron-style hover state for colors and now mirrors day/night hover shadow state; focused buttons no longer resolve hover colors. Exact rendered blending still needs runtime screenshot comparison. | Preserve Electron hover state for buttons/selects in day and night, keep focus distinct from hover, and verify visually. |
| Disabled | Disabled opacity `.46` applies to the whole command button element; day disabled shadow becomes a single inset highlight; disabled cursor default in Electron. | Fixed in shared Flutter component and covered by widget assertions for Play/Add/Remove disabled state, including opacity wrapping the button shadow and the day disabled shadow shape. | Preserve disabled callbacks, whole-button opacity `.46`, and disabled shadow; runtime rendered blending still belongs to screenshot verification. |
| More menu | Anchored above More button at `top - 8`; includes remove, extra actions, separator, select-all, reverse, clear. | Flutter uses `localToGlobal(0, -8)` and same item intent. | Keep menu content and anchor; verify exact position and overflow set at both breakpoints. |
| Add-To action | Electron can be button invoking external menu or native hidden select; internal select appears only when playlist targets exist, while external-menu call sites provide their own target menu. | Flutter uses the shared flyout builder, with caller-specific targets audited against Electron. | Match action geometry/visibility, hide Add-To when no concrete target exists, and preserve the audited caller-specific target sets. |
| Local playable gating | Local hides Play/Add-To when selected local items do not resolve to song ids. | Fixed in Flutter Local call site with `showPlay/showAddTo` driven by `selectedQueueSongIds.isNotEmpty`. | Preserve Local folder-only no-song behavior: Remove/Move remain available, Play/Add-To are absent. |
| Local Move extra action | Move To Folder is disabled when no selected move targets exist; target helper excludes source and parent folders. | Fixed in Flutter Local call site and helper. | Preserve disabled Move state and Electron source/parent target filtering. |
| Local hide preference | Local Play/Add-To/Move call `HideMultiSelectAfterOperation`, which does nothing when the setting is disabled. | Fixed in Flutter Local selection helper; setting-off operations now keep selected items. | Preserve setting-gated hide without clearing selection when disabled. |
| Albums/Search hide preference | Albums and Search direct Play use shared Electron `hideIfNeeded`, so setting-off Play keeps selection. | Covered by Flutter Albums/Search page-level tests using `hideMultiSelectCommandBarAfterOperation: false`. | Preserve setting-gated hide without clearing selection when disabled. |
| Recent searches gating | Recent hides Play/Add-To on the searches tab. | Fixed in Flutter Recent call site with `showPlay/showAddTo` driven by `_activeTab != RecentTab.searches`. | Preserve searches multi-select behavior: Remove remains available, Play/Add-To are absent. |
| Headered remove gating | HeaderedPlaylistControl renders Remove only when `removable` supplies `onRemove`. | Fixed in Flutter HeaderedPlaylistControl call site. | Preserve hidden Remove action for non-removable headered playlists. |
| Headered Add-To anchor | HeaderedPlaylistControl uses pointer coordinates for its Add-To flyout. | Fixed with a Headered-only pointer positioning option on the shared component. | Preserve pointer anchoring for Headered and above-button anchoring for the other verified call sites. |
| Now Playing hide preference | Now Playing direct Play and Add-To menu operations clear selection only when `hideMultiSelectCommandBarAfterOperation` is enabled; Remove clears inside its callback. | Fixed in Flutter NowPlaying by passing `hideAfterOperation` to the shared bar and removing unconditional selection clears from Play/Add-To callbacks. | Preserve setting-gated hide for Play/Add-To and unconditional Remove clear. |
| Now Playing Full hide preference | Now Playing Full external Add-To menu items hide only when `hideMultiSelectCommandBarAfterOperation` is enabled. | Covered by Flutter NowPlayingFull favorites and playlist Add-To page-level tests using setting-off state. | Preserve setting-gated hide for Favorites, New Playlist, playlist Add-To, and direct Play. |
| Hide-after-operation | Component-level direct actions call hide only when setting is enabled; cancel always clears and exits. | Flutter passes `hideAfterOperation` and mirrors this in many direct actions. | Preserve only confirmed per-call-site behavior; do not add fallback hiding to unverified flows. |
| Shared usage | One shared component across all listed Electron pages. | Flutter has one shared component, but host placement differs by caller. | Fix in the shared primitive and only adjust callers where geometry requires it. |

## Confirmed Remaining Differences

- Runtime screenshot parity is still unconfirmed.
- Exact body-level portal semantics are matched by equivalent Stack-layer geometry, not by a literal Flutter `Overlay`/portal; runtime proof is still required before claiming pixel parity.
- Widget golden outputs exist for Flutter-side visual regression only; they do not replace the required Electron/Flutter runtime screenshot comparison.

## Flutter Call-Site Geometry Audit

| Caller | Flutter host geometry | Electron-equivalent handling |
| --- | --- | --- |
| Local | Page content has horizontal inset; command bar is inside the page Stack. | Passes shell bottom inset and `horizontalBleed` so the rendered surface reaches the workspace host left/right. |
| Albums | `_AlbumsPagePanel` has `24px` horizontal padding. | Passes shell bottom inset and `horizontalBleed: 24`. |
| Recent | Recent page has asymmetric horizontal chrome in the current layout. | Passes shell bottom inset plus asymmetric `leftBleed`/`rightBleed`. |
| Now Playing | `_NowPlayingPagePanel` has `24px` content padding on all sides. | Renders the bar in a panel overlay outside the content padding and passes the shell bottom inset. |
| Artists | `_ArtistsPagePanel` has zero padding. | Uses the shared bar directly with shell bottom inset. |
| Search | `_SearchPageSurface` is full-size; only scroll slivers are padded. | Uses the shared bar directly with shell bottom inset. |
| HeaderedPlaylistControl | Layout Stack is full-size under the workspace surface. | Uses the shared bar directly with shell bottom inset. |
| Now Playing Full | Full page owns its own bottom player height. | Uses the full-page multi-select wrapper at `playerHeight - 1`, matching Electron `.now-playing-full-page` anchoring. |

## Add-To Call-Site Eligibility Audit

| Caller | Electron target set | Flutter evidence |
| --- | --- | --- |
| Albums | External menu from `getAddToPlaylistMenuFlyoutItems` with Now Playing, Favorites when selected songs are not all favorite, New Playlist, and custom playlists. | Multi-select passes `includeNowPlayingInAddTo: true`, favorite gating, create playlist, and custom playlist callbacks; page tests cover context menu targets, playlist add, and setting-off Play selection retention. |
| Artists | External menu with Now Playing, Favorites when applicable, New Playlist, and custom playlists. | Multi-select passes the same target callbacks; Artists tests cover song/group Add-To filtering, favorites hiding when all selected songs are favorite, New Playlist, playlist writes, and undo targets. |
| Search | External menu with Now Playing, Favorites when applicable, New Playlist, and custom playlists; single-song add uses the single-song repository path. | Search tests cover multi-select Now Playing append, album Add-To menu target presence, single-song playlist add, grouped card add, and setting-off Play selection retention. |
| Local | External menu is shown only when selected local items resolve to song ids; folder-only no-song selection hides Play/Add-To. | Local passes `showAddTo: selectedQueueSongIds.isNotEmpty`; tests cover folder-only hiding, selected folder Add-To song ids, Now Playing/Favorites targets, and setting-off Add-To selection retention. |
| Recent | External menu exists for songs/albums/artists tabs and is hidden on searches tab. | Recent passes `showAddTo: _activeTab != RecentTab.searches`; tests cover song menu targets, multi-select Now Playing write, and searches-tab Add-To hiding. |
| HeaderedPlaylistControl | Pointer-anchored external menu includes Now Playing unless the current playlist is Now Playing, Favorites unless the current playlist is Favorites, New Playlist, and custom playlists excluding the current saved playlist. | Flutter passes pointer anchoring, current/excluded playlist names, Now Playing/Favorites gating, and custom playlist callbacks; tests cover pointer anchoring and Add-To target behavior through headered/album detail flows. |
| Now Playing | Shared menu excludes Now Playing by using `currentPlaylistName: common.nowPlaying`, includes Favorites when applicable, New Playlist, and custom playlists. | NowPlaying tests cover command bar submenu targets, favorites, playlist writes, and multi-select setting-off Add-To retention. |
| Now Playing Full | Electron external menu uses `currentPlaylistName: common.nowPlaying`, so Now Playing is excluded while Favorites/New Playlist/custom playlists remain eligible. | Flutter full wrapper omits `includeNowPlayingInAddTo`, passes `currentPlaylistName: common.nowPlaying`, favorite gating, playlist callbacks, and tests cover menu target filtering plus setting-off Favorites and playlist Add-To retention. |

## Runtime Screenshot Evidence

- Electron original, local page dark multi-select selected at `1200 x 820`: `/tmp/smplayer_electron_multiselect.png`.
  - Confirmed the command bar begins at the workspace content host left edge and overlaps the player bar by the Electron `-1px` rule.
- Flutter before padded-page bleed fix, local page dark multi-select selected at `1200 x 820`: `/tmp/smplayer_flutter_multiselect_selected.png`.
  - Confirmed the command bar was shifted inward by the page padding and narrower than Electron.
- Flutter after padded-page bleed fix:
  - Widget geometry now asserts `horizontalBleed: 24` yields left `-24` and width `host + 48`.
  - Widget geometry also asserts asymmetric `leftBleed: 24`, `rightBleed: 18` yields left `-24` and width `host + 42`, matching Recent's current page padding.
  - Widget geometry now asserts desktop surface padding `26px/18px`, `760px` padding `18px/12px`, `520px` padding `12px/10px`, desktop separators `28px`, tablet separator `26px`, and no phone separators.
  - Widget state now asserts the shared surface uses a liquid-glass `GlassContainer` with `blur: 30`, `saturation: 1.65`, `GlassQuality.standard`, hard clipping, no elevation, and its own layer.
  - Widget layout now asserts zh-CN compact `添加到` keeps a wider-than-72px button at the `760px` breakpoint instead of collapsing to an ellipsized label.
  - Widget geometry now asserts selected-count width and typography (`154px` desktop, `112px` tablet, `96px` phone cap, `13px / 760` strong text), command buttons render at `36px` height, use shrink-wrapped Material tap targets, use `13px / 640` labels, and resolve icons through `16px` `IconTheme`.
  - Widget geometry now asserts all primary command button labels use `13px`, `height: 1`, and `FontVariation.weight(640)`, not only the Cancel button.
  - Widget interaction now asserts day hover changes command button shadow to the Electron `0 3px 10px` target, and night hover clears the command button shadow like Electron `box-shadow: none`.
  - Compact visual goldens now include the More button's idle command-button shadow, matching Electron's shared `.multi-select-command-bar button` shadow rule at the `760px` and `520px` breakpoints.
  - Albums page-level geometry now asserts the multi-select surface left is `0`, right/width are `1200px`, and bottom is `800 - 17px`, proving the `24px` page panel padding is not narrowing the command bar.
  - Recent page-level geometry now asserts the multi-select surface left is `0`, right/width are `1200px`, and bottom is `800 - 17px`, proving the asymmetric `24px/18px` page panel padding is not narrowing the command bar.
  - Local content panel geometry now asserts the scroll content bottom padding can be set to `108px`, matching Electron's `.local-scroll-shell` selection-mode padding.
  - Local page-level interaction now asserts selecting an empty folder hides Play/Add-To while keeping Delete/Move actions visible, matching Electron's `selectedQueueSongIds.length > 0` gate.
  - Local page-level interaction now asserts Move To Folder is disabled when Electron's selected move menu has no target.
  - Local helper test now asserts Electron source/parent target filtering: selected source and parent are excluded while a child target remains reachable.
  - Local page-level interaction now asserts multi-select Add-To and Play keep selection visible when Electron's hide-after-operation setting is disabled.
  - Albums and Search page-level interactions now assert multi-select Play keeps selection visible when Electron's hide-after-operation setting is disabled.
  - Recent page-level interaction now asserts recent-search multi-select hides Play/Add-To while keeping Remove visible, matching Electron's `activeTab !== 'searches'` gate.
  - HeaderedPlaylistControl interaction now asserts non-removable selection mode hides Remove, matching Electron's `onRemove` gating.
  - HeaderedPlaylistControl interaction now asserts multi-select Add-To uses the Electron pointer anchor; the shared component Add-To tests still assert the default above-button `8px` anchor and that pointer anchoring is consumed per click instead of being reused.
  - Shared widget interaction now asserts Add-To is hidden when no concrete Add-To target can be built, matching Electron's internal-select visibility rule.
  - Widget interaction now asserts the compact More menu opens with its panel bottom `8px` above the More button top, matching Electron's `rect.top - 8` anchor rule after flyout boundary resolution.
  - Widget interaction now asserts the desktop Add-To flyout opens with its panel bottom `8px` above the Add-To button top and contains Now Playing, My Favorites, and New Playlist entries when those callbacks are present.
  - Widget state now asserts hidden state keeps the bar mounted with `opacity: 0`, pointer ignore, `16px` slide, and `180ms ease` timing; Play, Add-To, and Remove are disabled with `Opacity(.46)` when selected count is zero, matching Electron's disabled opacity rule.
  - Widget state now asserts disabled Play, Add-To, and Remove use the Electron day disabled single inset shadow instead of the normal two-layer command button shadow.
  - Widget state now asserts hidden state excludes semantics and visible state keeps semantics exposed, matching Electron `aria-hidden`.
  - Widget state now asserts bottom inset, width, and asymmetric bleed offset use the Electron `160ms ease` layout transition timing.
  - Now Playing no longer places the shared bar inside `_NowPlayingPagePanel`'s `24px` content padding; the panel exposes an overlay layer for the bar, matching Electron portal geometry.
  - Now Playing page-level geometry now asserts the multi-select surface left is `0`, right/width are `1400px`, and bottom is `900 - 17px` in a `1400 x 900` test viewport, proving the overlay is outside the panel's `24px` content padding and still uses the shell player overlap inset.
  - Now Playing page-level interaction now asserts multi-select Add-To and Play Selected keep selection visible when Electron's hide-after-operation setting is disabled.
  - Now Playing Full page-level interaction now asserts multi-select Favorites and custom playlist Add-To keep selection visible when Electron's hide-after-operation setting is disabled.
  - 2026-06-02 Flutter-side visual rerun: `flutter test test/multiselect_command_bar_visual_test.dart` passed desktop, `760px`, `520px`, and night golden states after the latest sizing/anchor/timing changes.
  - 2026-06-02 Flutter-side filter rerun: `flutter test test/multiselect_command_bar_visual_test.dart --update-goldens` refreshed desktop, `760px`, `520px`, and night golden states after adding the Electron `saturate(165%)` backdrop filter; rerunning `flutter test test/multiselect_command_bar_visual_test.dart` passed.
  - 2026-06-02 CJK-font visual rerun: `test/multiselect_command_bar_visual_test.dart` now loads `/System/Library/Fonts/STHeiti Medium.ttc` as `SMPlayerTestChinese`, renders zh-CN labels (`已选择 1 项`, `取消`, `播放`, `添加到`, `移除`, `全选`, `反选`, `清除...`), writes `test/goldens/multiselect_command_bar_zh_desktop.png`, and `flutter test test/multiselect_command_bar_visual_test.dart` passed all five visual states.
  - 2026-06-02 disabled visual rerun: `test/multiselect_command_bar_visual_test.dart` now writes `test/goldens/multiselect_command_bar_disabled.png` for `selectedCount: 0`, covering the disabled Play/Add-To/Remove visual state; rerunning `flutter test test/multiselect_command_bar_visual_test.dart` passed all six visual states.
  - 2026-06-02 liquid-glass/zh-CN compact rerun: `test/multiselect_command_bar_visual_test.dart` now writes `test/goldens/multiselect_command_bar_zh_760.png`; the rendered `760px` zh-CN command bar shows full `添加到` text, and `flutter test test/multiselect_command_bar_visual_test.dart` passed all seven visual states.
  - 2026-06-09 functional-layout rerun: Flutter `MultiSelectCommandBar` compact breakpoint was corrected from the Flutter-only `1260px` value to Electron's `<=760px` CSS rule, so `900px` workspace hosts keep the desktop action row with Select All / Reverse / Clear visible and no More button. `flutter test test/command_bar_test.dart --plain-name MultiSelectCommandBar`, `flutter test test/multiselect_command_bar_visual_test.dart`, and targeted `dart analyze` passed after refreshing the Flutter-side golden files.
  - Flutter-side shell visual evidence now writes `build/smplayer_flutter_shell_local_multiselect_dark_verify.png` at `1200 x 820` with `SmPlayerShellPage`, `LocalPage`, the player bar, multi-select enabled, and selected items present.
  - The shell visual test asserts the command bar surface left is `320px`, right is `1200px`, width is `880px`, and bottom is `701px`, matching the workspace host width and the Electron `player top - 1px` overlap rule for this test shell.
  - Runtime screenshot after restart is still unconfirmed because the macOS debug window became unavailable/black during the verification attempt.
  - A later macOS debug rerun still launched the process but exposed no accessible/CG main window (`System Events` reported `windows=0`, `CGWindowList` found no `Simple Melody Player` window). Temporary native window-order experiments were not retained because they did not restore screenshot evidence.
  - 2026-06-02 rerun: `flutter run -d macos --no-pub` built and launched `Simple Melody Player.app`, but reported `Failed to foreground app; open returned 1`. `System Events` still reported `frontmost=false`, `visible=true`, `windows=0`; Swift `CGWindowListCopyWindowInfo` found no matching on-screen window; `/tmp/smplayer_runtime_attempt_full.png` was an all-black screenshot. This does not prove runtime parity.
  - 2026-06-02 follow-up: `flutter build macos --debug --no-pub` succeeded, but launching the built `Simple Melody Player.app` with `open -n` still produced `System Events` result `frontmost=false`, `visible=true`, `windows=0` and no `CGWindowList` entry for the app. Running the built Mach-O directly printed VM service and shader-precache logs, but still produced `windows=0`. Runtime screenshot proof remains blocked by the missing native window.
  - 2026-06-02 native-window follow-up: `macos/Runner/Base.lproj/MainMenu.xib` now marks the main `MainFlutterWindow` `visibleAtLaunch="YES"`, and `MainFlutterWindow.awakeFromNib` orders the window front on the next main runloop. A temporary instrumented run confirmed `MainFlutterWindow.awakeFromNib` executed and `NSApp.windows.count == 1` with `isVisible == true`; those temporary logs were removed from source. External System Events/CGWindow enumeration and `screencapture` still returned no visible app window/all-black output in this Codex session, so runtime pixel screenshot proof is still unconfirmed.
  - 2026-06-02 latest rerun: `flutter build macos --debug --no-pub` succeeded and `open -n build/macos/Build/Products/Debug/Simple Melody Player.app` launched process `Simple Melody Player`, but System Events inspection failed because `osascript` lacks Accessibility permission and `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` returned no Simple Melody Player window even after `tell application "Simple Melody Player" to activate`. Runtime screenshot proof remains unconfirmed.
  - 2026-06-02 filter/semantics rerun: after adding Electron `saturate(165%)` and hidden semantics, `flutter build macos --debug --no-pub` succeeded and the app process launched, but System Events still reported `frontmost=false`, `visible=true`, `windows=0`; Swift `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` reported `matchingWindows=0`; `/tmp/smplayer_runtime_multiselect_filter_attempt.png` was `3456 x 2234` with one sampled color and max channel value `0`. Runtime screenshot proof remains unconfirmed.
  - 2026-06-02 Now Playing hide-preference rerun: after fixing Now Playing multi-select Play/Add-To setting-gated hiding, `flutter build macos --debug --no-pub` succeeded and the app process launched, but System Events still reported `frontmost=false`, `visible=true`, `windows=0`; Swift `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` reported `matchingWindows=0`; `/tmp/smplayer_runtime_multiselect_nowplaying_attempt.png` was `3456 x 2234` with one sampled color and max channel value `0`. Runtime screenshot proof remains unconfirmed.
  - 2026-06-02 localized-window rerun: after adding Albums/Search hide-preference coverage, `flutter build macos --debug --no-pub` succeeded and `open -n build/macos/Build/Products/Debug/Simple Melody Player.app` launched pid `31725`. English-name matching was wrong because the native owner/title localizes to `简音播放器`; pid-based `CGWindowListCopyWindowInfo(.optionAll)` and `.optionOnScreenOnly` found one window at `X=80, Y=60, Width=1241, Height=840`. Full-screen `screencapture` still produced `/tmp/smplayer_runtime_window_attempt.png` with one sampled color and max RGB `0`, and `screencapture -l 51318` failed with `could not create image from window`. Runtime pixel screenshot proof remains blocked by the capture path, not by missing window enumeration.
  - 2026-06-02 Computer Use fallback: `list_apps` reported the running localized app as `简音播放器` at the Debug build path, but `get_app_state` for the full app path returned `cgWindowNotFound`, and `get_app_state` for `简音播放器` returned `Invalid app`. Computer Use therefore did not provide an alternate runtime screenshot path in this session.

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
- Hidden command bar state must stay mounted at `opacity: 0`, ignore pointer input, and slide by `16px`.
- Bottom inset, command bar width, and left/right bleed offset must use Electron's `160ms ease` layout transition timing.

Implementation target:

- Disable Material's padded tap target for this command surface.
- Apply the Electron label style at the button content layer, not only through inherited page typography.
- Add widget assertions for rendered button height, label font size/weight, icon size, and tap target mode.

## Unconfirmed Items

- Runtime pixel values are not yet verified with same Electron and Flutter window size, theme, data, and selection state.
- Exact rendered color blending difference between Electron CSS `backdrop-filter: blur(30px) saturate(165%)` and Flutter's project liquid-glass surface is unconfirmed.
- Exact runtime label baseline with the final app platform font stack versus Electron button text baseline is unconfirmed.
- Runtime screenshot for the post-bleed Flutter build is still required before reporting padded-page placement as pixel-confirmed.

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
  - At `520px`, Cancel is icon-only `40 x 36`, button minimum is `40`, More is `40 x 36`, count width is capped at `96`, Add-To uses max-width `88` with ellipsis rather than disappearing text.
  - Surface padding and separator visibility/height match the Electron desktop, `760px`, and `520px` CSS rules.
  - Selected-count width and typography match Electron desktop/tablet/phone rules.
  - Hidden state remains mounted and animates pointer/opacity/offset with Electron `180ms ease` timing.
  - Hidden state excludes semantics while visible state exposes semantics, matching Electron `aria-hidden`.
  - Bottom inset, command bar width, and left/right bleed offset use Electron `160ms ease` layout timing.
  - Liquid-glass surface uses Electron `blur(30px) saturate(165%)` targets through `GlassContainer` settings.
  - Symmetric and asymmetric page-padding bleed produce the expected left/right surface geometry.
  - Albums and Recent page-level tests assert the rendered surface reaches the workspace edges instead of padded page content edges.
  - Local scroll content uses the `108px` Electron multi-select spacer instead of the default `18px` local bottom padding.
  - Local folder-only selections with no songs hide Play/Add-To and keep Remove/Move visible.
  - Local Move To Folder extra action disables when Electron's selected move menu has no targets, and move target filtering excludes selected source/parent folders.
  - Local multi-select Add-To and Play respect `hideMultiSelectCommandBarAfterOperation`; setting-off operations keep selection visible.
  - Recent searches multi-select hides Play/Add-To and keeps Remove visible.
  - HeaderedPlaylistControl hides Remove when `removable` is false.
  - HeaderedPlaylistControl Add-To menu uses pointer anchoring while the default shared Add-To path remains above-button anchored; pointer anchoring is one-shot per click.
  - Now Playing multi-select Add-To and Play Selected respect `hideMultiSelectCommandBarAfterOperation`; setting-off operations keep selection visible.
  - Add-To action hides when there is no Now Playing/Favorites/Create Playlist/playlist target.
  - Play, Add-To, and Remove disabled actions use disabled callbacks and `Opacity(.46)` when selected count is zero.
  - Command buttons render as `36px` high, use `13px / 640` labels, resolve command icons to `16px`, and use shrink-wrapped Material tap targets.
  - Compact More menu opens above its More button with the Electron `8px` vertical gap and contains remove/select-all/reverse/clear items.
  - Desktop Add-To menu opens above its Add-To button with the Electron `8px` vertical gap and includes the built-in Add-To entries when the corresponding callbacks are present.
  - Flutter-side golden PNGs are generated for desktop, `760px`, `520px`, night, disabled, zh-CN CJK-font desktop, and zh-CN `760px` compact states.
  - Flutter-side shell screenshot is generated for LocalPage multi-select over the player bar at `1200 x 820`.
