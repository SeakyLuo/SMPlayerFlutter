# Local Page Song And Folder Parity Target

Electron is the only source of truth for this target. This document narrows the
Local page scope to song and folder layout, display, hover state, and user
operations. It supersedes the older `local_page_acceptance_matrix.md` note that
style parity was out of scope for these rows.

## Evidence

Electron source:

- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalPage.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalGridContent.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalTableContent.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/GridViewMusicItemControl.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/GridArtworkCardContent.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/LocalFolderCard.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/shared/i18nCounts.ts`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/AppBar.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/sidebar.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/appbar.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/local.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/local-table.css`

Flutter scope:

- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_shell.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_grid_content.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_table_content.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_compact_table_content.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_folder_card.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_i18n_counts.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/playback/playlist_control_item.dart`

Out of scope for this target: shell/titlebar/sidebar chrome. On macOS, the app
name remains hidden in the titlebar/sidebar chrome and the 78px leading inset
for traffic-light space remains required; those are platform shell rules, not
Local song/folder content rules.

Confirmed Electron behavior from source:

- `GridViewMusicItemControl.open()` toggles song selection when `multiSelect`
  is true; otherwise it calls `onPlayTrack(song.id, openQueueSongIds ??
  queueSongIds)`.
- `LocalPage.tsx` passes the current folder's direct, search-filtered songs as
  `folderQueueSongIds` / `openQueueSongIds` for local grid song cards.
- `LocalFolderCard.openFolder()` calls `onOpenFolder(folder.relativePath)`, and
  folder card/list clicks call `onToggleSelection(folder.relativePath)` only in
  multi-select variants.

Runtime evidence captured in this pass:

- Electron runtime captures use a deterministic fixture rooted at `C:\Music`
  only inside the verification harness, then open through the real Local UI to
  `Collections/Live/Sessions/Archive`. The Flutter macOS verifier uses a
  macOS-style fixture root under `/Users/.../Music` with the same visible folder
  chain. These fixture paths are not product rules; runtime behavior must
  continue using the user's real selected root path.
- Electron geometry now records the real `.local-commandbar` element, not the
  stale `.command-bar` selector.
- Electron harness copies `app-icon.png`, `colorful_no_bg.png`, and
  `folder.png`, matching `shared/staticAssets.ts` so folder fallback and badge
  images are not broken in runtime screenshots.
- Flutter wide LocalPage grid, light mode, 1280x820 widget harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_light_verify.png`
- Flutter wide LocalPage grid, night mode, 1280x820 widget harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_dark_verify.png`
- Electron LocalPage Archive data, light mode, 1280x820 BrowserWindow capture
  with renderer IPC stub:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_light_verify.png`
- Electron LocalPage Archive data, light mode, same BrowserWindow capture
  downsampled from Retina output to logical 1280x820:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_light_1280_verify.png`
- Electron LocalPage Archive geometry, logical 1280x820:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_light_1280_verify.geometry.json`
- Electron LocalPage Archive data, night mode, same BrowserWindow capture
  downsampled from Retina output to logical 1280x820:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_dark_1280_verify.png`
- Electron LocalPage Archive geometry, night mode, logical 1280x820:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_dark_1280_verify.geometry.json`
- Electron compact LocalPage Archive data, light mode, same BrowserWindow
  capture downsampled to logical 640x900:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_compact_light_640_verify.png`
- Electron compact LocalPage Archive geometry, logical 640x900:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_compact_light_640_verify.geometry.json`
- Electron compact LocalPage Archive data, night mode, logical 640x900:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_compact_dark_640_verify.png`
- Electron compact LocalPage Archive geometry, night mode, logical 640x900:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_compact_dark_640_verify.geometry.json`
- Flutter wide folder hover actions, light mode, 1280x820 widget harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_wide_folder_hover_light_verify.png`
- Flutter wide song hover actions, light mode, 1280x820 widget harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_wide_song_hover_light_verify.png`
- Electron wide LocalPage Archive folder hover, light mode, logical 1280x820,
  with hover geometry:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_folder_hover_light_1280_verify.png`
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_folder_hover_light_1280_verify.geometry.json`
- Electron wide LocalPage Archive song hover, light mode, logical 1280x820,
  with hover geometry:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_song_hover_light_1280_verify.png`
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_song_hover_light_1280_verify.geometry.json`
- Flutter full `SmPlayerShellPage` LocalPage Archive folder hover, light mode,
  1280x820 widget-test shell harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_shell_local_page_archive_folder_hover_light_verify.png`
- Flutter full `SmPlayerShellPage` LocalPage Archive song hover, light mode,
  1280x820 widget-test shell harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_shell_local_page_archive_song_hover_light_verify.png`
- Electron compact local table, light mode:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_compact_table_light_verify.png`
- Flutter compact local table widget verification, light mode:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_compact_table_light_verify.png`
- Flutter LocalPage with stored list preference still using Electron grid entry:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_compact_stored_list_grid_light_verify.png`
- Flutter compact folder row hover actions:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_compact_folder_hover_light_verify.png`
- Flutter full `SmPlayerShellPage` LocalPage Archive data, light mode,
  1280x820 widget-test shell harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_shell_local_page_archive_light_verify.png`
- Flutter compact full `SmPlayerShellPage` LocalPage Archive data, light mode,
  640x900 widget-test shell harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_shell_local_page_archive_compact_light_verify.png`
- Electron compact LocalPage Archive folder hover, light mode, logical 640x900,
  with hover geometry:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_compact_folder_hover_light_640_verify.png`
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_compact_folder_hover_light_640_verify.geometry.json`
- Flutter compact full `SmPlayerShellPage` LocalPage Archive folder hover,
  light mode, 640x900 widget-test shell harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_shell_local_page_archive_compact_folder_hover_light_verify.png`
- Electron compact LocalPage Archive folder focus, light mode, logical 640x900,
  with focus geometry:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_compact_folder_focus_light_640_verify.png`
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_compact_folder_focus_light_640_verify.geometry.json`
- Flutter compact full `SmPlayerShellPage` LocalPage Archive folder focus,
  light mode, 640x900 widget-test shell harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_shell_local_page_archive_compact_folder_focus_light_verify.png`
- Electron compact LocalPage Archive song hover, light mode, logical 640x900,
  with hover geometry:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_compact_song_hover_light_640_verify.png`
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_electron_local_page_archive_compact_song_hover_light_640_verify.geometry.json`
- Flutter compact full `SmPlayerShellPage` LocalPage Archive song hover,
  light mode, 640x900 widget-test shell harness:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_shell_local_page_archive_compact_song_hover_light_verify.png`
- Flutter desktop runtime `SmPlayerShellPage` LocalPage Archive data, light
  mode, 1280x820 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_light_1280_verify.png`
- Flutter desktop runtime `SmPlayerShellPage` LocalPage Archive geometry, light
  mode, 1280x820 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_light_1280_verify.geometry.json`
- Flutter desktop runtime `SmPlayerShellPage` LocalPage Archive data, night
  mode, 1280x820 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_dark_1280_verify.png`
- Flutter desktop runtime `SmPlayerShellPage` LocalPage Archive geometry, night
  mode, 1280x820 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_dark_1280_verify.geometry.json`
- Flutter desktop runtime compact `SmPlayerShellPage` LocalPage Archive data,
  light mode, 640x900 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_compact_light_640_verify.png`
- Flutter desktop runtime compact `SmPlayerShellPage` LocalPage Archive
  geometry, light mode, 640x900 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_compact_light_640_verify.geometry.json`
- Flutter desktop runtime compact `SmPlayerShellPage` LocalPage Archive data,
  night mode, 640x900 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_compact_dark_640_verify.png`
- Flutter desktop runtime compact `SmPlayerShellPage` LocalPage Archive
  geometry, night mode, 640x900 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_compact_dark_640_verify.geometry.json`
- Flutter desktop runtime wide LocalPage Archive folder hover, light mode,
  1280x820 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_folder_hover_light_1280_verify.png`
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_folder_hover_light_1280_verify.geometry.json`
- Flutter desktop runtime wide LocalPage Archive song hover, light mode,
  1280x820 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_song_hover_light_1280_verify.png`
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_song_hover_light_1280_verify.geometry.json`
- Flutter desktop runtime compact LocalPage Archive folder hover, light mode,
  640x900 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_compact_folder_hover_light_640_verify.png`
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_compact_folder_hover_light_640_verify.geometry.json`
- Flutter desktop runtime compact LocalPage Archive song hover, light mode,
  640x900 macOS run:
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_compact_song_hover_light_640_verify.png`
  `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_flutter_desktop_local_page_archive_compact_song_hover_light_640_verify.geometry.json`

## Target Matrix

| Area | Electron rule | Flutter target | Status |
|---|---|---|---|
| Page scroll shell | Electron `.page-panel.local-page` is transparent with no inner card surface. `.local-scroll-shell` owns only scroll padding, and `.local-folder-grid` / `.local-song-grid` use full available width so one folder/song still starts at the left grid edge. In the 1280x820 Archive capture, the first folder card is `left=350,top=220,width=180,height=232`. | Flutter LocalPage must not wrap wide content in an extra bordered/shadowed panel, and scroll content must be constrained to the viewport width so grids do not center when they have few items. | Fixed in current pass; shell screenshot test asserts the first folder card matches Electron geometry within tolerance. |
| Workspace Local header | Electron `App.tsx` renders `LocalTitleGrid` inside `.workspace-header` for `/local` when rootPath exists in both wide and nav-minimal shells. Electron `.workspace.is-local-route .workspace-header` is `height:108px` with `padding:48px 24px 18px` in wide mode; nav-minimal uses the 40px app bar header. Electron `.folder-chain-list-view` uses `gap:2px`; each segment owns its dropdown chevron, so there is no separate breadcrumb separator icon. Electron hidden-folder entry uses `Icon name="hiddenFolders"`, mapped to Fluent `FolderProhibitedRegular`, in both the title-grid button and LocalPage compact overflow menu. In the wide Archive fixture capture, the title-grid hidden-folder button is `left=1214,top=48,width=42,height=42`; that same fixture's Archive breadcrumb exposes 5 dropdown buttons because the test path has 5 segments. Electron `.local-page` has `padding:0 24px 0`, `.local-toolbar` has `min-height:50px`, and `.local-page` gap is `14px`. Electron compact CommandBar media query changes toolbar min-height to 44px, visible button height to 38px plus 4px vertical margins, content padding to 8px, and button horizontal padding to 10px; the Archive compact runtime CommandBar is `left=12,top=78,width=616,height=46`. | Flutter `SmPlayerWorkspace` must host `LocalTitleGrid` in the workspace header for wide and compact Local routes, hide the LocalPage inline title under that header, keep one chevron per breadcrumb segment, use the same hidden-folder icon and button geometry, keep wide LocalPage top padding at 0, preserve the Electron toolbar/content vertical chain, and use the same compact CommandBar media-query dimensions. | Fixed in current pass; desktop runtime geometry now matches Electron CommandBar exactly in light and night mode at 1280x820 (`left=344,top=108,width=912,height=48`) and 640x900 (`left=12,top=78,width=616,height=46`). The refreshed wide runtime geometry shows hidden-folder button zero delta and the fixture breadcrumb dropdown count `5`; the refreshed compact runtime geometry shows the same fixture breadcrumb dropdown count `5`. Widget shell screenshot tests cover wide and compact Local card/row geometry. |
| Grid order | Folders render before direct songs. | Same order. | Existing behavior retained. |
| Section headers | When both folders and songs exist, show collapsible Folders and All Songs sections. If only one kind exists, no redundant section header. | Same. | Existing behavior retained. |
| Count labels | Electron uses `formatFolderCardStats` and `formatLocalFolderSongCount` from `shared/i18nCounts.ts`, so English singular values render as `1 folder`, `1 song`; they are not raw `{count} folders` template substitutions. Electron `.local-toolbar p` uses `14px` and `font-weight: 650`. | Flutter LocalPage toolbar and folder row counts must use the same locale-aware folder/song unit formatting and the same toolbar count typography. | Fixed in current pass; desktop runtime screenshots now show `1 folder · 3 songs` and `1 song`, and targeted tests cover the helper, toolbar, and folder-card counts. |
| Section spacing | Electron wide sections use 14px section gap, 24px bottom margin, 30px header height, 16px header font, and 15px chevrons. Electron nav-minimal sections use 8px section gap, 14px bottom margin, 30px header height, 15px header font, and 15px chevrons. Electron night-mode `.local-content-section-header` overrides to 38px min-height, 16px horizontal padding, pill radius, subtle border/background, hides the chevron, and uses the accent expanded state from `.local-content-section-header.is-expanded`. | Flutter sections should use the same header height and gap in both width buckets, with compact-only header font reduction, and should apply the Electron night-mode header and expanded-state override. | Fixed in current pass; wide shell screenshot test asserts first folder card `top=220` and first song card `top=520`, compact shell screenshot test asserts the first folder and song rows land at the Electron compact geometry, and night-mode desktop runtime geometry now has zero delta for the first folder card at `top=228` and first song card at `top=536`. |
| Grid sizing | Folder and song grid tracks are 180px wide with 30px column gap and 26px row gap. Cards are 180px wide, 232px min height, 10px padding, and 160px artwork. | Same dimensions. | Fixed/covered for the Archive fixture; Electron and Flutter desktop runtime geometry have zero delta for the first folder card and first direct song card at logical 1280x820 in both light and night mode, and compact row geometry has zero delta at logical 640x900. |
| Song quick jump | Electron vertical quick-jump is a sticky 27-row grid (`top: 6px`), 30px wide in wide layout and 22px wide in compact layout, with 3px vertical padding and 1px row gaps. It remains in normal flow until its content position reaches the sticky top. Jumping scrolls to the real target item position, not a fixed row-height estimate. User override: when a large song set can show quick jump, sorting must not change song grid column count merely because the active sort has fewer than four quick-jump buckets. | Keep the same vertical density and sticky behavior. For `currentSongs.length >= 50`, reserve the quick-jump rail width even when the active bucket map hides the quick-jump buttons. | Fixed in current pass; widget tests cover vertical metrics, mixed folder/song sticky threshold behavior, sticky screen position, target-position scrolling, and the reserved rail preventing a 4-column grid from expanding to 5 columns when sort hides quick-jump buttons. |
| Folder grid default surface | Folder grid card default background is transparent and has no shadow. Hover/focus/selected adds card hover surface and shadow. | Same visible states. | Fixed in current pass for grid cards. |
| Folder grid artwork | Folder card shows up to four album-group thumbnails. No thumbnails fall back to the colorful default artwork over Electron `--default-artwork-bg`, with folder image badge at bottom right. The artwork cover keeps `var(--artwork-shadow)` by default. | Same content, fallback gradient, badge placement, and artwork cover shadow. | Resolver retained; fallback background, fallback asset, badge asset, and default artwork cover shadow fixed in current pass. |
| Folder grid hover actions | Non-multi-select folder grid hover/focus/selected reveals centered 48px round play and add actions over artwork. Default state hides actions. In the 1280x820 Archive folder-hover capture, the action group is `left=387,top=286,width=106,height=48`, with folder action opacity `1` and song action opacity `0`. | Same action visibility, geometry, and operations. | Fixed in current pass; Electron hover screenshot/geometry and Flutter desktop runtime hover screenshot/geometry cover the same Archive data with zero geometry delta. |
| Folder grid click | Normal click opens folder. In multi-select, click toggles folder selection. Right click opens folder menu. | Same. | Fixed/covered; `LocalPage folder click opens relative folder` proves normal click route behavior, and selection-command tests cover multi-select item set behavior. |
| Folder list row | Compact/list folder rows show optional tree toggle, optional check mark, folder icon, name, info, and trailing actions. Electron nav-minimal list rows use a 30px folder icon column with a 22px image; rows with a tree toggle use `padding-left: calc(8px + depth * 22px)`, a 24px toggle column, 10px gaps, `font-weight: 690` for `.local-folder-list-name`, and `13px` / `font-weight: 520` for `.local-folder-list-info`. The Archive fixture puts the folder name at `left=95` in the 640x900 capture. | Same structure, operation, icon column, tree-toggle padding, title/info typography, and title/trailing x-position. | Row transparency, panel containment, action visibility, title/info typography, title x-position, and trailing right edge fixed in current pass. Compact light and night desktop runtime geometry now has zero delta for row/card bounds and folder title left/top; the `1 song` trailing right edge matches Electron at `right=613`. |
| Folder list hover/focus actions | Folder list trailing actions are hidden by default and become visible on hover/focus. Info fades out while actions are visible. Buttons are 28px transparent icon buttons with 6px radius and accent hover, not grid artwork floating buttons. List Play remains enabled even for empty folders; Add To is disabled for empty folders. In the 640x900 Archive compact folder-hover capture, the action group is `left=465,top=184,width=148,height=28`, five action buttons are 28px square with 2px gaps, info opacity is `0`, and actions opacity is `1`. Programmatic focus on the row produces the same action geometry and opacity. | Same. | Hover and focus fixed in current pass; Electron compact hover/focus screenshots/geometry, Flutter compact shell hover/focus screenshot tests, and Flutter desktop runtime compact hover geometry cover the same Archive data. Runtime hover action geometry has zero delta. |
| Song grid card | Local song grid card uses artwork/fallback with default artwork cover shadow, current playing overlay, title, and subtitle/detail label. `GridViewMusicItemControl` always renders `.local-grid-song-subtitle`; default content is the display artist, and album sort replaces it with `artist · album`. Hover/focus/selected reveals centered 48px play/pause and add actions. The title row does not show a favorite heart, and artwork-to-title spacing is 5px. In the 1280x820 Archive capture, the first direct song card is `left=350,top=520,width=180,height=232`; the `Glass Horizon` title starts at `left=360,top=695`, and the default `Noon Section` artist subtitle starts at `left=360,top=718.25`. In the song-hover capture, the action group is `left=387,top=586,width=106,height=48`, with song action opacity `1` and folder action opacity `0`. | Same subtitle/display logic, card geometry, and hover action geometry. | Favorite icon, spacing, default artist subtitle, album-sort detail subtitle, focus-visible action reveal, artwork cover shadow, wide shell geometry, and hover action geometry fixed in current pass; refreshed Electron and Flutter desktop runtime geometry cover the same Archive data. The `Noon Section` subtitle left/top now matches Electron. |
| Song grid current state | Current song title and subtitle use accent color. Electron CSS sizes `.local-grid-song-playing-wave` at 34px; the current Flutter target has an explicit user override to keep the liquid-glass playing wave the same 48px diameter as the hover play button. Hover/focus hides the wave and reveals actions. | Preserve the explicit 48px liquid-glass wave override while keeping the Electron hover/focus state transition. | Playing wave size override and focus hide behavior fixed in current pass; widget coverage asserts the current playing wave is 48px and remains hidden when hover/focus actions are visible. |
| Song grid operations | Click plays song with the open folder queue; in selection mode toggles selection. Right click opens song menu. Add opens Add To menu. | Same. | Fixed/covered; `LocalPage song click plays Electron current-folder queue` proves a clicked song plays with the direct current-folder queue and selected queue index, while `LocalPage song click toggles selection in multi-select` proves multi-select click does not replace Now Playing. Existing targeted tests cover song context menu, Play Next, Add To, move/hide, and current-song pause. |
| Compact grid songs | Electron compact grid song rows reuse `PlaylistControlItem` instead of a bespoke Local row. Under nav-minimal 640px width, `.local-compact-song-list .now-playing-queue-item` is 78px high with `58px minmax(0, 1fr) 34px 20px` columns, 12px gaps, 10/12/10/10 padding, 56px artwork, 16px/760 title, and 14px duration. On hover/focus the actions column expands to `max-content`; favorite and Add To are hidden, and the first Archive row shows Play Next at `left=515,top=297,width=34,height=34` and More at `left=549,top=297,width=34,height=34`. | Flutter compact grid songs must keep `PlaylistControlItemVariant.compact`, use the same 58px artwork column around the 56px artwork, collapse primary actions the same way, and expose only the same compact hover actions and geometry. | Fixed in current pass; Electron compact song hover screenshot/geometry, Flutter compact shell hover screenshot/test, and Flutter desktop runtime compact song hover geometry cover the same Archive data. Runtime row bounds, title left/top, and hover action group geometry now match Electron exactly for the measured Archive fixture. |
| Compact list panel | Electron wraps compact folder tree and compact song rows in `local-compact-tree-list` / `local-compact-song-list` panels with border, 10px radius, panel background, shadow, clipping, and row separators. Folder list rows are transparent rows inside that panel, not standalone bordered cards. Electron compact section headers use `min-height:30px`, `margin:0 2px`, and section gap `8px`. Electron compact song item body is 78px, and non-last `.local-compact-song-row` adds a 1px row separator, so the first Archive direct-song row is `left=13,top=275,width=614,height=79`. In the same 640x900 Archive capture, the first folder row is `left=13,top=175,width=614,height=46`. | Flutter compact folder tree/direct folder list and compact song list should use the same single panel structure, row separators, full content width, section header height, panel border content inset, and compact song row wrapper/separator geometry. | Fixed in current pass; compact desktop runtime geometry now matches Electron exactly for CommandBar, the first folder row, and the first direct song row. Compact shell screenshot tests cover light, folder hover, folder focus, and song hover states. |
| Local view mode | Electron `LocalPage.tsx` currently sets `effectiveViewMode` to `'grid'`, so LocalPage does not enter table/list mode even when table components exist in source. | Flutter LocalPage must ignore stored `LocalViewMode.list` for the Local page entry and render `LocalGridContent`. | Fixed in current pass; table components remain directly tested but no longer drive LocalPage. |
| Table/list components | Electron still has `LocalTableContent`, but the LocalPage branch is unreachable while `effectiveViewMode` is hard-coded to `'grid'`. If that branch is re-enabled later, rows should expose folder/song actions on row hover and preserve table semantics. Folder rows use the folder image asset; song rows use the colorful icon asset when not current. | Flutter table widgets may remain as directly tested components, but LocalPage must not route into them unless Electron re-enables list mode. | LocalPage entry parity is fixed by always rendering `LocalGridContent`; direct Flutter component tests cover row actions/type assets as residual component coverage, not LocalPage pixel-parity evidence. |
| Drag/drop | Folder and song drag payloads include selected items when the dragged item is selected; drops onto legal folders move local items. Folder drop target styling is scoped to the grid artwork cover or list row, using a 2px accent outline outside the surface; grid artwork also keeps the artwork shadow plus accent glow. | Same payload behavior and drop target scoping. | Payload behavior retained; folder drop target scoping fixed in current pass with widget coverage. |
| IDs/dev info | No raw database IDs, implementation paths beyond intended user file paths, or debug text appear in card/list UI. | Same. | Existing tests cover representative card content. |

## Unconfirmed

- Electron runtime and Flutter desktop runtime screenshots now exist for wide
  and compact grid using the same Archive data, logical window sizes, and light
  / night mode theme states. Geometry parity is closed for the measured command
  bar, first folder card, first direct song card/row, hidden-folder button,
  breadcrumb dropdown count, and hover action groups. Pixel parity is still not
  fully closed until remaining visible screenshot differences beyond those
  measured anchors are audited and either fixed or explicitly accepted.
  LocalPage list/table same-runtime screenshots are not a current target while
  Electron keeps `effectiveViewMode` hard-coded to `'grid'`.
- Electron wide Archive-data screenshot exists at logical 1280x820 after
  downsampling the Retina `capturePage()` output. Flutter now has both a
  widget-test shell harness screenshot and a macOS desktop runtime screenshot
  for the same Archive data and logical 1280x820 size. The refreshed wide
  runtime geometry records the default `Noon Section` artist subtitle at the
  same left/top as Electron (`left=360`, `top≈718`).
- Compact Electron and Flutter shell screenshots exist at logical 640x900 with
  the same Archive data in light and night mode. Flutter now has both
  widget-test and macOS desktop runtime screenshots. Runtime geometry now
  matches compact CommandBar, the first folder row, the first direct song row,
  folder title left/top, and song title left/top exactly. Text width values in
  geometry JSON are not a row-layout parity signal because the Electron capture
  records wider text containers while Flutter records the actual Text render
  boxes.
- Electron and Flutter desktop runtime night-mode screenshots were refreshed
  after the Electron fixture, static-asset, and commandbar selector fixes. Wide
  1280x820 and compact 640x900 commandbar, first folder card/row, and first
  direct song card/row geometry now match exactly. Text width values remain
  non-authoritative for parity because Electron geometry records the text
  container while Flutter records the rendered text box for some labels,
  including local song subtitles.
- Wide folder/song hover now has same-data Electron capture geometry and
  Flutter desktop runtime geometry. Folder and song hover action groups match
  Electron exactly at logical 1280x820.
- Compact folder/song hover now has same-data Electron capture geometry and
  Flutter desktop runtime geometry. Compact folder hover action geometry and
  opacity match Electron exactly at logical 640x900
  (`left=465,top=184,width=148,height=28,right=613,bottom=212`, opacity `1`).
  Compact song hover action-group geometry matches Electron exactly at logical
  640x900.
- Table/list component pixel parity remains unconfirmed as residual component
  coverage, but it is not required for current LocalPage entry parity because
  Electron does not expose that branch.
