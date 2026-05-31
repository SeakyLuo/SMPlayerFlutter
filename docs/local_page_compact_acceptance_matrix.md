# LocalPage Compact Acceptance Matrix

Electron is the only source of truth for this compact/narrow-screen target.
This matrix covers the `/local` page when the app shell is in `nav-minimal`
mode and Local content width is below the compact breakpoint.

## Current Alignment Goal

Goal opened on 2026-05-31:

- Re-audit the remaining LocalPage narrow-screen differences against Electron
  `nav-minimal`.
- Write the target, source evidence, Flutter evidence, confirmed differences,
  current status, and unconfirmed items into this document.
- Do not mark a row as aligned from Flutter code similarity alone; each fixed
  row needs Electron source evidence plus Flutter implementation, test, or
  screenshot evidence.

This goal treats the user supplied narrow-screen screenshots as mismatch
prompts, not as the sole source of truth. Electron source/CSS remains the
authority. Items that still need a same-size Electron and Flutter runtime
capture stay marked as partially verified or unconfirmed.

## Evidence Scope

Electron source:

- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalPage.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalTitleGrid.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/shell.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/workspace.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/appbar.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/local.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/local-table.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/responsive.css`

Flutter corresponding source:

- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/app/shell_page.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/app/shell_workspace.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_shell.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_title_grid.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_grid_content.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_table_content.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_quick_jump.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/test/local_page_test.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/test/local_page_visual_verify_test.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/test/shell_page_test.dart`

## Compact Layout Target

| Area | Electron compact rule | Flutter target | Acceptance check | Current status |
|---|---|---|---|---|
| Breakpoint | Shell enters `nav-minimal` below 720px; Local compact content uses the same narrow state. | Shell minimal mode and Local compact layout both begin below 720px. | Width 719 uses minimal app bar and compact Local; width 720 leaves minimal mode. | Covered by `shell matches Electron navigation breakpoints` and compact Local tests. |
| Minimal titlebar | `nav-minimal` adds a 32px top titlebar row. | Flutter reserves `minimalTitlebarHeight` before workspace content. | At 600px width, workspace top is below the minimal titlebar and starts at x=0. | Covered by shell minimal tests. |
| Player reservation | Electron workspace height is `100vh - 32px - player-height + player-top-radius`; player overlays the bottom 120px with 18px top radius overlap. | Flutter workspace height uses `height - playerHeight + playerTopRadius - workspaceTop`; player is a bottom positioned 120px surface. | At compact width, Local content scroll area ends above the bottom player except for the intentional 18px radius overlap. | Covered by `minimal workspace reserves Electron player height`; compact full-shell screenshot remains not captured. |
| App bar title | Local breadcrumb/title grid moves into `.workspace-header`; page body should not render a second title row. | `LocalTitleGrid` is supplied by `SmPlayerWorkspace`; `LocalPage` hides inline title when `WorkspaceNavigationAppBarScope` is active. | Compact shell shows one breadcrumb/title area only. | Implemented in `shell_workspace.dart` and `local_page.dart`; body screenshot exists at `build/smplayer_local_page_compact_appbar_body_light_verify.png`. |
| Page inset | `.app-shell.nav-minimal .local-page` uses `padding: 6px 12px 0` and `gap: 8px`. | `LocalPageScaffold` uses 12px horizontal, 6px top, 0 bottom; toolbar/content gap is 8px. | Compact screenshot should not show desktop 24px/18px page inset. | Implemented; compact dark screenshot regenerated. |
| Toolbar | Compact toolbar keeps the stats text, random play, update, sort, and overflow actions in one row. | Flutter `CommandBar` keeps intrinsic content and reserves compact overflow width. | At 640px, stats and primary actions stay visible; overflow holds hidden folders entry and lower-priority actions. | Covered by compact toolbar and overflow tests. |
| Content shell | Electron compact scroll frame is transparent; compact lists own their card/border surfaces. | `LocalPageContentPanel` removes the outer card in compact mode and only applies scroll padding. | Compact screenshot must not show one large card wrapping quick jump plus content. | Implemented; compact dark screenshot regenerated. |
| Scroll padding | `.local-scroll-shell` compact keeps top 4px and bottom 18px padding. | Compact scrollable content uses `EdgeInsets.fromLTRB(0, 4, 0, 18)`. | Last row has a small tail gap but no fake 120px Local padding. | Implemented for grid/scrollable content; table content keeps its own `6,6,6,18` list padding. |
| Quick jump | Compact song grid with quick jump uses 22px column, 20px buttons, 380px height, and 10px column gap. | `LocalSongQuickJump(compact: true)` and `_LocalSongGrid` use those dimensions. | At compact width, `# A-Z` rail is narrow and aligned with the compact list card. | Implemented; compact screenshot and tests cover quick-jump presence. |
| Folder tree rows | Compact folder rows are list/tree rows with disclosure only when expandable; nested rows are indented. | Flutter compact table/tree rows expose only visible expandable toggles and keep nested indentation. | Expand a folder and verify nested folders/songs appear in order. | Covered by compact tree tests and expanded-tree screenshot. |
| Song rows | Compact grid song rows reuse Electron `PlaylistControlItem`: 78px row, 56px artwork, title, artist plus album, duration on the right, and hover/focus actions instead of always-visible action columns. | Flutter compact rows reuse `PlaylistControlItemVariant.compact` instead of a Local-only row. | Compact page with songs shows duration in the row and does not show play/favorite/add as always-visible columns. | Implemented in `local_grid_content.dart`; compact screenshots regenerated. |
| Selection state | Compact select-all/reverse operates on visible compact tree rows plus current direct songs. | Flutter compact selection uses the visible compact row set. | Expand one tree branch, select all, and verify only visible rows are selected. | Covered by `LocalPage compact tree select all uses visible tree rows`. |
| Empty root | Electron shows the same no-root state inside compact page inset. | Flutter reuses the same empty-root state under compact scaffold. | Root path empty at compact width shows no-root copy and choose action. | Empty-root screenshot exists for dark mode; compact-specific empty-root screenshot is not yet captured. |
| Empty folder/search | Electron keeps Local empty states in the content area without adding extra desktop shell chrome. | Flutter compact content uses the same empty-state branch and transparent compact shell. | Empty folder and no-result states render without overflow. | Covered by empty-folder and search tests; compact screenshot not separately captured. |
| Night mode | Electron `body.night-mode .app-shell.nav-minimal` uses dark shell/background and dark Local surfaces. | Flutter uses `LocalPageColors.night` and shell dark extensions. | Compact night screenshot has dark Local text/surfaces and no light-only constants. | Covered by compact dark screenshots and analyze. |
| Light mode | Electron compact light mode uses `#f8fbfe` minimal toolbar/shell and light Local surfaces. | Flutter uses `LocalPageColors.day` and shell light extensions. | Compact light screenshot should match the structure in the supplied reference: minimal app bar, compact inset, transparent content shell, bottom player reserved by shell. | Light compact screenshots exist at `build/smplayer_local_page_compact_light_verify.png` and `build/smplayer_local_page_compact_appbar_body_light_verify.png`; full shell/player screenshot remains not captured. |

## Unconfirmed Runtime Evidence

- A live Electron screenshot at the exact same window size and dataset as the
  supplied Flutter screenshot has not been captured in this turn.
- The current Flutter visual tests render LocalPage content screenshots, not a
  full app shell screenshot with the real bottom player. The shell code path and
  compact player height reservation are covered by tests, but full shell visual
  proof is still marked unconfirmed.

## 2026-05-31 Screenshot Re-Audit

Reference supplied by the user:

- `/Users/luohaitian/Desktop/截屏2026-05-31 19.06.39.png`

Confirmed Electron evidence rechecked for this audit:

- `LocalPage.tsx` renders compact toolbar actions in this order: shuffle,
  refresh, sort, new folder, multi-select, then delete in selection mode.
- `LocalGridContent.tsx` renders compact song rows through
  `PlaylistControlItem`, not a Local-only song row.
- `local-table.css` defines compact grid song rows as a bordered
  `.local-compact-song-list` containing 78px rows with 56px artwork, title,
  artist plus album, right-side duration, and hover/focus actions.
- `appbar.css` moves the Local breadcrumb into the nav-minimal workspace header
  and hides the current-path label and hidden-folders button there.
- `i18nCounts.ts` formats `formatFolderCardStats` from localized count helpers;
  `zh-CN.json` also contains `local.folderCardStats` as
  `文件夹：{folders} · 歌曲：{songs}`. The Electron screenshot therefore needs
  live locale confirmation before changing Flutter strings from the code path
  alone.

| Screenshot area | Electron evidence | Flutter evidence | Status | Follow-up rule |
|---|---|---|---|---|
| Song row structure | `LocalGridContent.tsx` uses `PlaylistControlItem` for compact rows; CSS uses 78px row, 56px artwork, duration, hover actions. | Earlier Flutter used `_CompactLocalSongRow` with always-visible play/next/favorite/add icons. It now uses `PlaylistControlItemVariant.compact`. | Fixed from confirmed difference. | Keep compact Local song rows on shared `PlaylistControlItem`; do not reintroduce Local-only always-visible action columns. |
| Quick jump and song list shell | Electron uses `22px + 10px + list` and list owns the border/radius. | Flutter now uses 22px quick jump, 10px gap, and transparent outer content panel. | Fixed from confirmed difference. | Verify with compact screenshot after any content-shell edit. |
| Toolbar visible action count | Electron toolbar order is confirmed, but visible vs overflow depends on measured widths, window width, locale text width, and CommandBar runtime measurement. | Flutter compact test covers overflow menu order. The user screenshot shows different visible counts between old Flutter and Electron. | Partially verified; exact visibility still needs same-width full-shell runtime screenshot. | Do not claim toolbar pixel parity until Flutter and Electron are captured at the same logical width, locale, and app shell. |
| Toolbar stats text | Electron code path uses `formatFolderCardStats`; locale files include both count-helper wording and `local.folderCardStats` wording. The supplied Electron screenshot shows `文件夹：0 · 歌曲：78`. | Flutter Local toolbar uses `i18n.t('local.folderCardStats')`; tests currently inject `{folders} folders · {songs} songs`. | Unconfirmed string parity for the real app locale bundle. | Audit Flutter runtime locale resources before changing wording; do not infer from test fixtures. |
| Minimal titlebar app name | Electron screenshot does not show an app title next to macOS window controls. | The supplied Flutter screenshot shows app title text in the top-left area, but current `shell_page.dart` uses empty title on macOS for `MinimalTitlebar`. | Unconfirmed against current build; may be stale screenshot or platform/titlebar path difference. | Needs current full-shell macOS screenshot before editing titlebar behavior. |
| Full shell and player overlap | Electron reserves workspace height with `100vh - 32px - player-height + player-top-radius`; player is bottom overlay. | Flutter shell code and `minimal workspace reserves Electron player height` test cover the height formula. | Behavior covered by test, visual not fully proven. | Need full-shell screenshot with real player to close visual proof. |
| Current/playing rows | Electron compact row marks current/playing through `PlaylistControlItem` overlay and current foreground. | Flutter now delegates to `PlaylistControlItem`, but the current visual screenshot fixture is not a real playing full-shell queue state. | Partially verified by component reuse and tests. | Capture or add fixture with current song selected/playing in compact Local. |
| Table/list compact mode | Electron table mode uses separate mobile table CSS: hidden header, single-column rows, 72px song rows, 58px folder cards, and horizontal quick jump. | Flutter `LocalTableContent` now delegates compact rendering to `LocalCompactTableContent` when `isCompactLayout` is true. | Implemented and covered by `LocalTableContent compact mode hides desktop header and stacks song text`; Flutter compact screenshot generated at `build/smplayer_local_page_compact_table_light_verify.png`. Same-size Electron runtime screenshot still not captured. | Keep marked separate from grid compact parity; do not claim pixel parity until captured against Electron in the full shell. |

## Goal Self-Audit

| Check | Result | Evidence |
|---|---|---|
| Electron files and CSS were rechecked before changing status. | Done | `LocalPage.tsx`, `LocalGridContent.tsx`, `appbar.css`, `local-table.css`, `i18nCounts.ts`, and `zh-CN.json` are listed above with concrete rules. |
| Flutter corresponding implementation was rechecked. | Done | `shell_workspace.dart`, `local_page.dart`, `local_grid_content.dart`, and compact Local tests were inspected for the same areas. |
| Narrow song-row mismatch from the screenshots has a confirmed Electron target. | Done | Electron compact grid song rows use shared `PlaylistControlItem`; Flutter compact Local song rows now use `PlaylistControlItemVariant.compact`. |
| Toolbar content and overflow are fully pixel-proven. | Not closed | Source order and tests are covered, but exact visible item count still depends on same-width runtime measurement. |
| Stats text is fully proven for the real Chinese runtime. | Not closed | Electron source and locale files disagree enough to require live locale confirmation before changing Flutter wording. |
| Full shell, macOS titlebar, and bottom player overlap are visually proven. | Not closed | Shell math is tested, but this document still lacks a current same-size full-shell screenshot with the real player. |
| Empty data states are included in the compact acceptance target. | Partially closed | Empty root/folder/search branches are listed and covered by tests; compact-specific screenshots are still missing for every empty branch. |
| Table/list compact mode is included in the same claim as grid compact mode. | Partially closed | It now has a compact Flutter implementation, widget test, and Flutter screenshot, but still needs same-size Electron full-shell visual proof because Electron uses a separate mobile table CSS path. |

No row in this document should be read as "fully pixel aligned" unless its
status explicitly says the visual proof exists. Rows marked partial or
unconfirmed are the remaining alignment target.
