# Local Page Acceptance Matrix

Electron is the only source of truth for this matrix. This document is an
acceptance target for the Flutter local page, not proof that every item has
already passed runtime verification.

User constraint for this matrix: existing Flutter components may be reused and
their visual style does not need to be identical to Electron. Acceptance here is
about content, interaction, state, side effects, route semantics, and not
exposing IDs or developer information.

## Evidence Scope

Electron source:

- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalPage.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalTitleGrid.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalGridContent.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalTableContent.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalPageQuickJump.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/localFolderModel.ts`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/localPageModel.ts`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/localMoveToFolderMenu.ts`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/LocalFolderCard.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/FolderUpdateResultDialog.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/HiddenFoldersPage.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/App.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/AppRoutes.tsx`

Flutter corresponding source:

- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_context_menus.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_folder_actions.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_file_actions.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_playback_actions.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_scan_actions.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_selection_actions.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_add_to_actions.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_title_grid.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_grid_content.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_table_content.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_folder_card.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_folder_model.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_model.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_quick_jump.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/folder_update_result_dialog.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/hidden_folders_page.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/app/app_router.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/app/shell_workspace.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/test/local_page_test.dart`

## Acceptance Rules

- Do not invent behavior that is not backed by the Electron files above.
- Do not add defensive fallback behavior for impossible states unless explicitly
  approved.
- Do not expose raw IDs, debug text, implementation details, or file internals
  in the user-facing UI.
- Do not add a Local toolbar view toggle. Electron currently hard-codes the
  Local page content view to grid and does not expose a toolbar switch.
- Style parity is out of scope for this matrix unless it affects whether a user
  can discover or operate a feature.
- Runtime acceptance must use real interaction evidence: widget test, manual
  run, screenshot, or captured behavior. Static code similarity is not enough.

## Route And Shell

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Route | `/local` renders `LocalPage`; folder location is provided as current relative path. | `/local` renders `LocalPage`; query `path` maps to `currentRelativePath`. | Open `/local`, `/local?path=Sub`, and a nested path; each shows the expected folder. | `/local?path=Sub` covered by `LocalPage route query opens target local folder`; nested `/local?path=Sub/Deep` covered by `LocalPage route query opens nested local folder`. |
| Search-scoped local route | Directory search opens Search with folder scope, not a different Local page. | Searching a directory records folder search and navigates with the same query/scope semantics. | Search from a folder, verify recent search type is folders and results are scoped. | Covered by `LocalPage search folder uses Electron input dialog`. |
| App bar title integration | When `/local` and rootPath exists, `LocalTitleGrid` is placed in app bar/header; otherwise placeholder. | Shell workspace shows `LocalTitleGrid` only for local route with rootPath. | With rootPath, path bar is visible in Local header; without rootPath it is not. | Covered by `local title hides after music folder is set`, `local app bar shows compact breadcrumb after music folder is set`, and `local title shows before music folder is set`. |
| Hidden folders route | `/hidden-folders` opens `HiddenFoldersPage`; Local hidden entry navigates there. | `/hidden-folders` route renders `HiddenFoldersPage`. | Click Local hidden folders entry and verify page opens. | Wide entry covered by `LocalPage hidden folders entry opens and resumes items`; compact entry covered by `LocalPage compact overflow opens hidden folders entry`; page screenshot exists in `build/smplayer_hidden_folders_dark_verify.png`. |
| Last-page semantics | Electron normalizes nested local paths back to `/local` for last-page style routing. | Flutter must not persist or surface raw implementation IDs when restoring Local. | Restart/restore opens Local safely without showing path IDs or dev info. | Covered by `restored page follows Electron restorable route list`, including `/local?path=Sub/Deep` resolving to `/local`. |

## Breadcrumb And Current Path

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Visibility | Real breadcrumb appears only on Local route when rootPath is set. | Same. | Empty root state has no real breadcrumb; configured root does. | Configured-root screenshots exist in `build/smplayer_local_page_light_verify.png` and `build/smplayer_local_page_dark_verify.png`; empty-root night screenshot exists in `build/smplayer_local_page_empty_root_dark_verify.png`. |
| Current path label | Left label uses `local.currentPath`. | Same i18n label, no hard-coded English/Chinese. | Switch locale and verify label changes. | Covered by `LocalTitleGrid renders Electron breadcrumb label and chain`. |
| Chain construction | Chain starts at root folder display name and appends each path segment. | Same `buildFolderChain` behavior. | For root `C:\Music` and path `A/B`, chain shows `Music`, `A`, `B`. | Covered by `LocalTitleGrid renders Electron breadcrumb label and chain`. |
| Root display name | Root display name is the last segment of rootPath, with no raw ID. | Same. | Root folder label is user-readable folder name. | Covered by `LocalTitleGrid renders Electron breadcrumb label and chain`. |
| Current segment click | Clicking current segment does not navigate; Electron scrolls the current content to top and closes child flyout. | Flutter preserves no-navigation and scrolls content to top. | Scroll Local content down, click current segment, expect top position. | Implemented; `test/local_title_grid_test.dart` verifies the callback path. |
| Ancestor segment click | Clicking a non-current segment opens that ancestor and closes the child flyout. | Same. | From `A/B`, click `A`; Local opens `A`. | Covered by `FolderChainListView ancestor click opens Electron target segment`. |
| Segment right click | Right-click any chain segment opens the breadcrumb folder menu for that folder. | Same. | Right-click root, parent, and current segment; each menu targets that folder. | Callback covered by `FolderChainListView opens Electron context menu callback`; menu side effects covered for a chain folder by `LocalPage breadcrumb menu actions target chain folder`. |
| Child dropdown visibility | A segment with children has a dropdown chevron; a segment without children has no dropdown. | Same. | Verify both segments with and without child folders. | Covered by `LocalTitleGrid renders Electron breadcrumb label and chain`. |
| Child dropdown toggle | Clicking dropdown opens child flyout; clicking same dropdown again closes it; clicking overlay/elsewhere closes it. | Same. | Open, close, and switch between dropdowns. | Covered by `FolderChainListView closes and switches child flyouts`. |
| Child dropdown position | Flyout is anchored near the segment and clamped inside the viewport. | Same behavior; exact style not required. | Open near right edge and verify flyout remains visible. | Fixed Flutter max width to mirror Electron `max-width: min(420px, calc(100vw - 48px))`; covered by `FolderChainListView child flyout clamps, scrolls, and targets child menu` and screenshot `build/smplayer_local_page_breadcrumb_flyout_dark_verify.png`. |
| Child list scroll | Long child lists are scrollable. | Same, using Flutter scrollable. | Folder with many children allows scrolling within flyout. | Covered by `FolderChainListView child flyout clamps, scrolls, and targets child menu`. |
| Child highlight | Child item is highlighted when it is the current path or an ancestor branch of the current path. | Same. | At `A/B`, open `A` children; `B` is highlighted. | Screenshot exists in `build/smplayer_local_page_breadcrumb_flyout_dark_verify.png`. |
| Child click | Clicking a child flyout item opens that child and closes flyout. | Same. | Open root dropdown, click `Sub`, verify Local path becomes `Sub`. | Covered by `FolderChainListView opens Electron child folder flyout`. |
| Child right click | Right-click child flyout item opens the breadcrumb folder menu for that child. | Same. | Right-click child item; menu actions target child folder. | Covered by `FolderChainListView child flyout clamps, scrolls, and targets child menu`. |
| Horizontal overflow | Electron path list supports horizontal overflow and hides native scrollbars. | Flutter must allow full path access when path is long. | Build a deep path and verify all segments can be reached. | Deep-path night screenshot exists in `build/smplayer_local_page_deep_breadcrumb_dark_verify.png`; wheel and pointer-drag offsets are covered by `test/local_title_grid_test.dart`. |
| Wheel-to-horizontal scroll | Electron maps wheel delta to horizontal path scrolling. | Flutter maps wheel delta to horizontal path scrolling. | Use mouse wheel over breadcrumb and verify horizontal scrolling. | Implemented; `test/local_title_grid_test.dart` verifies horizontal offset changes. |
| Pointer-drag horizontal scroll | Electron supports dragging empty breadcrumb area to scroll and suppresses accidental click after drag. | Flutter supports pointer drag scrolling and suppresses the follow-up tap. | Drag breadcrumb horizontally; no accidental folder open. | Covered by `FolderChainListView pointer drag scrolls and suppresses segment tap`. |
| Drag/drop onto path segment | Electron accepts local item payload drops onto non-current path segments. | Flutter supports dropping local items onto non-current breadcrumb targets. | Drag song/folder to a parent segment; item moves to that folder. | Covered by `FolderChainListView accepts drops on path segments and child flyout items`. |
| Drag/drop onto child flyout item | Electron accepts local item payload drops onto child flyout items. | Flutter supports dropping local items onto flyout child targets. | Drag song/folder to a child item in breadcrumb flyout; item moves there. | Covered by `FolderChainListView accepts drops on path segments and child flyout items`. |
| Hidden folders button | Breadcrumb grid has a right-side hidden folders button. | Same or compact overflow equivalent. | Click button and verify `/hidden-folders`. | Wide entry covered by `LocalPage hidden folders entry opens and resumes items`; compact overflow covered by `LocalPage compact overflow opens hidden folders entry`. |

## Breadcrumb Folder Menu

Electron breadcrumb menu is intentionally smaller than the normal folder-card
menu. It should not silently gain unrelated folder actions.

| Menu item | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Shuffle | Random plays the target folder `subtreeSongIds`. | Same. | Right-click parent in breadcrumb, shuffle plays the full subtree. | Covered by `LocalPage breadcrumb menu actions target chain folder`. |
| Add To | Add target folder subtree to now playing, favorites, new playlist, or existing playlist. | Same. | Add from breadcrumb root/parent and verify target song IDs are subtree IDs. | Existing-playlist path covered by `LocalPage breadcrumb menu actions target chain folder`; favorites/new-playlist remain shared Add To menu behavior. |
| Move To Folder | Move the target folder to a legal destination. | Same move-target menu rules as Local. | Move breadcrumb-target folder; illegal destinations are excluded/disabled. | Legal target side effect covered by `LocalPage breadcrumb menu actions target chain folder`; illegal target filtering covered by `isMoveTargetFolder mirrors Electron local folder drop rules`. |
| Preference | Shows folder preference action for breadcrumb target. | Same, no raw folder ID displayed. | Set/undo preference from breadcrumb menu. | Set-preference path covered by `LocalPage breadcrumb menu actions target chain folder`; no raw ID exposed in UI. |
| Reveal | Opens target folder in file manager with pending/opening text. | Same. | Invoke reveal on root/child; system reveal command receives folder path. | Callback path covered by `LocalPage folder reveal action sends Electron folder path`; command contract covered by `desktop_features_test.dart`; macOS runtime command pass confirmed Finder selection/target for `open -R` and `open`. |
| Search Directory | Opens search input dialog titled with target folder name. | Same. | Empty query shows `local.searchQueryEmpty`; valid query opens folder-scoped search. | Covered by `LocalPage breadcrumb search uses target folder scope`. |
| Excluded actions | Breadcrumb menu does not include Select, New Folder, Delete, Refresh, Rename, Sort, or Hide Folder. | Same. | Right-click breadcrumb and verify excluded actions are absent. | Covered by `LocalPage breadcrumb menu keeps Electron reduced actions`. |

## Toolbar

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Stats | Toolbar content shows current folder's direct child folder count and direct song count. | Same. | At root with child folders and a root song, stats use only direct child folder/direct song counts. | Covered by `LocalPage toolbar stats use direct child counts`. |
| Shuffle button | If direct songs and subfolder songs both exist, open scope menu; otherwise play available direct/subtree set. | Same. | Verify Current folder and Include subfolders menu, then playback queue. | Covered by `LocalPage toolbar shuffle matches Electron scope menu`. |
| Refresh button | Refresh current folder; disabled or scanning text while scanning. | Same. | Trigger refresh and verify repository receives current folder path. | Covered by refresh result test. |
| Sort button | Menu items: reverse, separator, title, artist, album. Checked item mirrors current sort. | Same. | Switch title/artist/album/reverse and verify order and persisted criterion. | Sort persistence covered by `LocalPage toolbar sort persists current folder criterion`; multi-select blocking covered by `LocalPage blocks sort changes in multi-select mode`; checkmark state covered by `LocalPage toolbar sort menu mirrors Electron checkmark state`. |
| New folder button | Opens input dialog with default generated folder name and validates name. | Same. | Create default folder, duplicate, empty, and over-50-character cases. | Create covered; validation variants need pass. |
| Multi-select button | Turns on selection mode; active state reflects selection mode. | Same. | Click and verify selection toolbar appears. | Covered in several tests. |
| Delete selected button | Appears in toolbar only in multi-select mode and is disabled with zero selected items. | Same. | Enter multi-select with no selection; delete disabled. Select item; delete enabled. | Covered by `LocalPage delete selected button mirrors Electron disabled state` plus selected-delete flow test. |
| Hidden folders overflow | In compact layout, hidden folders entry is in CommandBar overflow. | Same. | Compact width shows hidden folders action in overflow. | Covered by `LocalPage compact overflow opens hidden folders entry`. |
| No view toggle | Electron hard-codes Local effective view mode to grid and does not show a view switch in the toolbar. | Flutter must not add toolbar list/grid toggle. Settings can still control `LocalViewMode` if already implemented. | Toolbar does not show List View/Grid View buttons. | Covered by `LocalPage toolbar does not expose a view toggle`. |

## Empty And Loading States

| State | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Loading | Local page shows shared loading state while data loads. | Same. | Force loading provider and verify loading state. | Covered by `LocalPage shows Electron loading state while data loads`. |
| No root | Shows `local.noRoot`, `local.noRootCopy`, and choose folder action. | Same. | Root empty; choose folder callback runs scan. | Covered by empty root scan test. |
| Folder not found | Shows `local.folderNotFound`, description, and Back to Root. | Same. | Open non-existent path and click Back to Root. | Covered by `LocalPage missing route folder returns to Electron root`. |
| No scanned songs | With rootPath but no songs, shows `local.noSongsScanned`, `local.scanPopulate`, and settings action. | Same. | Empty scanned library shows Settings action and does not scan automatically. | Covered by empty scanned library test. |
| Search no results | With query and no visible content, shows `local.noSongsBranch` and `local.searchHelp`. | Same. | Search scoped Local with no matches. | Covered by `LocalPage search filters folders and empty results`. |
| Truly empty folder | Folder has no children/songs and no search query: render empty content without misleading copy. | Same. | Open empty folder; verify no false "not scanned" or search copy. | Fixed empty-folder unbounded layout and covered by `LocalPage empty folder stays blank without scan/search copy`. |
| Scan progress | Scan overlay shows title, stage text, counts, current path, and Stop Update when cancellable. | Same. | Start cancellable scan; verify progress text and cancellation. | Covered by custom root scan progress/cancellation test. |

## Folder Index, Sorting, And Filtering

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Folder index root | Always creates root node for rootPath. | Same. | Root exists even when folder table has no explicit root row. | Covered by `buildFolderIndex mirrors Electron folder tree and flatten order`. |
| Relative path | Songs are assigned to folders by path under rootPath. | Same. | Song at root appears in root direct songs; nested song appears in child direct songs. | Covered by `buildFolderIndex mirrors Electron folder tree and flatten order`. |
| Ancestor subtree | Every ancestor gets song ID in `subtreeSongIds`. | Same. | Folder add/shuffle uses all descendants, not only direct songs. | Covered indirectly by multi-select folder add and shuffle. |
| Child folder sort | Child folders sorted by local text compare on folder name. | Same. | Mixed-case/localized names sort like Electron. | Not explicitly tested. |
| Direct song base sort | Folder criterion maps to title, artist, album, reverse/title default. | Same. | Folder with saved criterion orders visible direct songs accordingly. | Covered by `buildFolderIndex applies folder criterion to direct songs`. |
| Search filter | Folder filter checks folder name; song filter checks title, artist, artists, album, and path. | Same. | Query matches by every supported field; no raw ID search. | Song fields covered by `matchesSongSearch mirrors Electron searchable song fields`; folder-name widget filtering covered by `LocalPage search filters folders and empty results`. |
| Quick jump bucket basis | Quick jump basis follows effective sort: artist, album, or title. Reverse uses current base sort. | Same. | Switch sort and verify enabled quick-jump keys change by correct basis. | Title basis covered by `LocalPage table quick jump jumps by Electron title bucket`; artist basis covered by `LocalPage table quick jump follows Electron artist basis`; reverse over album basis covered by `LocalPage table quick jump reverse keeps Electron album basis`. |

## Grid Content

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Section order | Folders render before direct songs. | Same. | Folder and root song present; folder section appears first. | Covered by Local grid section tests and visual screenshots. |
| Section headers | If both folders and songs exist, render collapsible `common.folders` and `local.allSongs`. | Same. | Both present: headers visible and collapse independently. | Covered by `LocalPage grid sections collapse only when both groups exist`. |
| No section headers | If only folders or only songs exist, render content without section headers. | Same. | Folder-only and song-only folders have no redundant headers. | Song-only case covered by `LocalPage grid sections collapse only when both groups exist`; folder-only case covered by `LocalPage grid folder-only content has no section headers`. |
| Folder grid card | Card shows artwork/placeholder, folder badge, name, and stats. | Same content; style can reuse Flutter component. | Verify visible name/stats and no IDs. | Covered by `Local grid folder card exposes Electron content and actions`. |
| Folder thumbnail candidates | Folder artwork is assembled from direct songs and child folders, grouped by album; each album group contributes at most one resolved artwork; maximum four images. | Same content rule, not necessarily same visual styling. | Folder with several album groups shows up to four distinct thumbnails; no artwork falls back to folder/default artwork. | Candidate grouping covered by `folder thumbnail candidate groups mirror Electron ordering`; resolved artwork path covered by `Local folder thumbnail resolver keeps resolved artwork path`; resolved artwork image rendering covered by `Local grid folder card renders resolved artwork image`. |
| Folder thumbnail ordering | Electron uses thumbnail child paths sorted by folder ID and direct song IDs sorted by song ID for thumbnail candidate order. | Same ordering unless current Flutter data model has a documented Electron-backed reason. | Build fixture with multiple child folders/songs and verify thumbnail order. | Covered by `folder thumbnail candidate groups mirror Electron ordering`. |
| Folder click | Non-selection click opens folder. | Same. | Click folder card and path changes. | Covered by `LocalPage folder click opens relative folder`. |
| Folder multi-select click | In multi-select, click toggles selection instead of opening. | Same. | Enable multi-select and click folder; selected count changes, route does not. | Covered indirectly. |
| Folder hover/actions | Non-multi-select folder actions include play/shuffle and add. | Same operations; exact hover style not required. | Action buttons play subtree and open Add To menu. | Covered by `Local grid folder card exposes Electron content and actions`; folder subtree Add To is also covered through Local integration. |
| Folder list variant | Compact layout uses list-style folder rows inside tree. | Same. | Width under 720 shows list/tree rows. | Covered for compact list view. |
| Song grid card | Shows song artwork/fallback, title, current/playing state, and action controls. | Same operations; exact style can differ. | Play, add, context menu, current indicator work. | Hover action and current playing state covered by `test/local_grid_content_test.dart`; song menu/play flows covered by Local integration tests. |
| Song detail label | When sort basis is album, detail label is artists plus album; otherwise omitted. | Same. | Sort by album and verify card subtitle includes artist and album. | Model covered by `local grid song detail label follows Electron sort-mode display`; widget rendering covered by `LocalPage album sort shows Electron song detail label`. |
| Current song state | Current song is marked; playing song shows playing state and pause action. | Same. | Start playback then verify current row/card state. | Playing wave visual state covered by `Local grid current song shows Electron playing wave`; pause side effect covered by `LocalPage current song context menu pauses playback`. |

## Compact Tree

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Breakpoint | Compact local layout begins below 720px. | Same. | Resize below/above 720 and verify layout change. | Covered by compact Local tests using sub-720 surfaces and wide Local tests using desktop surfaces. |
| Nav-minimal page inset | In nav-minimal/compact Local, `.local-page` uses `padding: 6px 12px 0` and `gap: 8px`; the breadcrumb title is in the workspace app bar, so page content does not reserve the desktop title gap. | Compact Flutter uses 12px horizontal and 6px top page inset, removes the title-placeholder gap when the workspace app bar owns the title, and keeps 8px toolbar/content spacing. | Compact screenshot should show toolbar/content starting at the Electron nav-minimal inset, not the desktop 24/18 inset. | Implemented in `LocalPageScaffold` and `LocalPage`; compact tests pass and screenshot regenerated at `build/smplayer_local_page_compact_dark_verify.png`. |
| Nav-minimal content shell | Electron's compact Local scroll frame is transparent; folder/song compact lists own their card borders. There is no single large outer card wrapping quick jump and list content. | Compact Flutter removes the outer `LocalPageContentPanel` card and uses transparent scroll padding while preserving list/card surfaces inside content. | Compact screenshot should not show a large surrounding content panel around quick jump plus list. | Implemented in `LocalPageContentPanel`; screenshot regenerated at `build/smplayer_local_page_compact_dark_verify.png`. |
| Nav-minimal quick jump | Electron compact quick jump column is 22px wide, buttons are 20px wide, and min-height is 380px. | Compact Flutter quick jump uses 22px column, 20px buttons, 380px height, and 10px gap to the list. | Compact screenshot and quick-jump interaction remain usable. | Implemented in `LocalSongQuickJump` / `LocalGridContent`; compact visual test passed. |
| Tree row build | Child folders are rendered as tree rows; expanded folders append nested folders and direct songs. | Same. | Expand folder and verify child song appears below it. | Covered by compact list/tree test. |
| Tree folder toggle | Toggle button expands/collapses only if folder has nested visible folders or songs. | Same. | Empty folder toggle disabled/hidden behavior verified. | Fixed Flutter compact rows to omit non-expandable toggles like Electron; covered by `LocalPage compact tree select all uses visible tree rows`. |
| Tree song queue | Playing a tree song uses compact tree song queue plus direct current songs where Electron does. | Same queue semantics. | Expanded child song plays with expected queue. | Covered by compact list/tree test for list mode. |
| Tree indentation | Depth changes indentation. | Usability must reflect hierarchy; exact pixels not required. | Nested rows are visually nested. | Compact expanded-tree night screenshot exists in `build/smplayer_local_page_compact_tree_dark_verify.png`. |
| Compact selection scope | Selectable folders/songs include visible compact tree rows plus current direct songs. | Same. | Select all/reverse selection in compact includes expanded tree rows only. | Covered by `LocalPage compact tree select all uses visible tree rows`. |

## Table/List Mode

Electron has `LocalTableContent`. Flutter may use existing list/table widgets, but
behavior should remain compatible.

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Header columns | Table has Name, Artist, Album headers. | Same when list mode is active. | List mode shows three columns. | Covered by list-view columns test. |
| Virtualization | Table virtualizes rows with overscan. | Flutter list mode should not render all offscreen rows. | Large list: offscreen row absent until scrolled. | Covered by virtualization test. |
| Folder rows | Folder row shows folder icon/name/count, opens on double-click/click behavior per mode, and has row actions. | Equivalent user operations. | Open, menu, play, add, refresh, search, reveal from row. | Covered by `LocalTableContent folder and song rows expose Electron actions`. |
| Song rows | Song row shows title, artist links/text, album link/text, play/current state, and row actions. | Equivalent user operations. | Play, add, play next, context menu, artist/album navigation where supported. | Covered by `LocalTableContent folder and song rows expose Electron actions` and `LocalTableContent artist and album cells navigate like Electron`. |
| Table quick jump | When enabled in table, quick jump row is horizontal. | Equivalent accessible quick jump. | Large list shows quick jump and jumps. | Implemented as horizontal table quick jump and covered by `LocalPage table quick jump jumps by Electron title bucket`. |
| Table section headers | Same folder/song section header logic as grid. | Same. | Headers appear only when both content types exist. | Covered by `LocalPage list view mirrors Electron table columns`. |
| Table compact tree | Compact table uses tree rows with folder/song row heights and expansion. | Equivalent behavior. | Compact list tree expands and plays child song. | Covered. |

## Selection Mode

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Stored selection | Electron stores Local multi-select state and selected folders/songs per page key. | Flutter currently uses in-state selection; acceptance should match user-visible behavior unless persistence is required separately. | Navigate within Local clears selection; selection does not leak invalid items. | Filter invalid items covered; persistence not confirmed. |
| Clear on folder change | Changing current relative path clears multi-select and selected items. | Same. | Select item, open folder, selection is cleared. | Covered by `LocalPage clears selection when current folder changes`. |
| Effective selection | Selection is filtered to currently selectable visible items. | Same. | Select item then filter it away; selected toolbar disappears. | Covered by filtered-out selection test. |
| Selected item count | Count is selected folders plus selected songs. | Same. | Select one folder and one song; count is 2. | Covered by `LocalPage selection commands mirror Electron sets`. |
| Selected queue IDs | Selected playable queue is selected song IDs plus selected folders' subtreeSongIds with duplicates removed. | Same. | Select folder and song; play/add uses deduped IDs. | Mixed folder/song queue covered by `LocalPage play selected uses selected queue`; overlapping duplicate case covered by `LocalPage play selected dedupes overlapping folder songs`. |
| Play selected | Shown only when selected queue has songs; plays first selected queue item with selected queue. | Same. | Select playable folder/song and press play. | Covered by `LocalPage play selected uses selected queue`. |
| Add selected | Shown only when selected queue has songs; supports now playing, favorites, new playlist, existing playlist. | Same. | Add selected folder to playlist. | Covered by multi-select add folder test. |
| Move selected | Disabled when no selected items or no legal destination. | Same. | Select item, move to legal folder; no legal target disables action. | Move covered. |
| Delete selected | Confirms disk delete and routes to pending/undo delete flow. | Same. | Confirm delete and verify undo appears. | Covered by selected move/delete test. |
| Select all | Selects all currently selectable folders/songs. | Same. | Select all in filtered view includes only visible/selectable items. | Covered for wide visible set by `LocalPage selection commands mirror Electron sets`, filtered set by `LocalPage filtered select all uses visible items only`, and compact tree set by `LocalPage compact tree select all uses visible tree rows`. |
| Reverse selection | Inverts current selectable folder/song sets. | Same. | Reverse from one selected item yields all others. | Covered by `LocalPage selection commands mirror Electron sets`. |
| Clear selection | Clears both folder and song selections. | Same. | Clear button resets count and toolbar state. | Covered by `LocalPage selection commands mirror Electron sets`. |
| Cancel selection | Leaves selection mode and clears selected items. | Same. | Cancel hides selection toolbar and clears marks. | Covered by `LocalPage selection commands mirror Electron sets`. |
| Hide after operation | If setting says hide multi-select command bar after operation, operation clears selection. | Same. | Toggle setting and verify post-operation state. | Setting-on covered by `LocalPage selection commands mirror Electron sets`; setting-off covered by `LocalPage keeps multi-select bar when setting is off`. |
| Sort blocked in selection | Electron blocks sort change in multi-select and shows `local.pleaseExitMultiSelectMode`. | Same. | Enter multi-select, try sort, see message and no persisted sort. | Covered. |

## Folder Operations

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Open folder | Uses relative path and current Local route state. | Same. | Folder click opens correct relative path. | Covered by `LocalPage folder click opens relative folder`. |
| Shuffle folder | Toolbar shuffle uses current folder songs and shows no-music notification when the current folder queue is empty; folder card play action is disabled for empty folders like Electron. | Same. | Empty current folder toolbar Shuffle shows no-music copy; non-empty folder play/shuffle uses subtree. | Empty current folder covered by `LocalPage toolbar shuffle on empty folder shows Electron copy`; non-empty covered indirectly by toolbar/folder queue tests. |
| Add folder | Adds folder subtreeSongIds to now playing/favorites/playlist. | Same. | Add folder to existing playlist. | Direct folder action covered by `LocalPage folder add action uses folder subtree songs`; multi-select add also covered. |
| Create child folder | Folder menu New Folder creates under selected folder, not current folder. | Same. | Right-click folder > New Folder; created path is child of target. | Covered by `LocalPage folder menu creates child folder under target`. |
| Rename folder | Input dialog default is current name; no-op if name unchanged. | Same. | Rename to new name calls repository; unchanged does not. | Rename-to-new and unchanged no-op covered by `LocalPage single folder rename hide and delete mirror Electron`. |
| Delete folder | Confirmation title/message use folder name; delete passes folder absolute path. | Same. | Confirm delete and verify repository folder path. | Covered by `LocalPage single folder rename hide and delete mirror Electron`. |
| Hide folder | Hides folder, shows undo notification, and can resume by path. | Same. | Hide folder then undo restores. | Covered by `LocalPage single folder rename hide and delete mirror Electron`. |
| Reveal folder | Opens folder in OS file manager. | Same. | Platform reveal callback receives folder path. | Callback path covered by `LocalPage folder reveal action sends Electron folder path`; command contract covered by `desktop_features_test.dart`; macOS Finder runtime selection/target verified with `open -R` and `open`. |
| Search folder | Input dialog requires non-empty query; commits folder-scoped search. | Same. | Empty query error; valid query records folder search. | Covered for folder action. |
| Folder preference | Preference menu uses folder entity and folder ID internally, without showing ID. | Same no-ID UI. | Set preference and inspect repository call/UI. | Covered for normal folder menu. |
| Folder sort menu | Folder menu sort submenu has reverse, title, artist, album; checkmark reflects folder criterion. | Same. | Right-click folder, set sort, verify persisted target folder path and checked item. | Positive target-folder persistence covered by `LocalPage folder sort menu persists target folder`; checkmark state covered by `LocalPage folder sort menu mirrors Electron checkmark state`. |

## Song Operations

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Play song | Play uses current visible queue. | Same. | Click/double-click song and verify queue IDs. | Covered for list mode and compact tree. |
| Toggle current song | If current song is playing, row play action pauses; otherwise moves/plays. | Same. | Current playing row button toggles pause. | Covered by `LocalPage current song context menu pauses playback`; card visual state covered by `Local grid current song shows Electron playing wave` and `build/smplayer_local_page_current_song_dark_verify.png`. |
| Play next | Row/menu Play Next inserts song next. | Same. | Invoke Play Next and inspect queue. | Covered by `LocalPage song context Play Next inserts after current queue`. |
| Add song | Song add menu supports now playing, favorites, new playlist, existing playlist. | Same. | Add to Now Playing and My Favorites. | Covered by song add menu test. |
| Context menu | Song menu includes Play, Add To, Select, Move To Folder, Hide File, View, and Electron shared music actions. | Same. | Right-click song and verify actions. | Covered by song context menu test. |
| Select song | Song context Select enters multi-select with that song only. | Same. | Right-click Select, verify count. | Covered. |
| View submenu | View opens Music Info, Lyrics, Album Art modes and includes See Local where shared menu requires it. | Same. | View > See Music Info opens dialog; other modes remain available. | Dialog modes covered by song view menu test; See Local callback path covered by `LocalPage song See Local sends Electron song path`; command contract and macOS Finder runtime selection are verified through the shared reveal command. |
| Move song | Move To Folder routes through local move undo/conflict path. | Same. | Move song to legal folder and verify undo. | Covered by `LocalPage song context menu moves and hides single song`. |
| Hide song | Hide File hides song and shows undo. | Same. | Hide then undo restores. | Covered by `LocalPage song context menu moves and hides single song`. |
| Delete song | Delete from disk uses pending/undo delete flow. | Same. | Confirm delete and verify undo prompt. | Covered elsewhere in shared flows, not specifically Local single-song here. |
| Favorite | Favorite toggles through shared add/remove favorite path. | Same. | Toggle favorite from menu/add path and verify repository state. | Add to favorites covered. |
| Artist/album navigation | Electron song rows link artist to `/artists?artist=` and album to `/albums?album=`. | Flutter should provide equivalent navigation if list/table exposes these as actions/text. | Click artist/album from list row and verify route, or mark unsupported with evidence. | Covered by `LocalPage table artist and album cells navigate like Electron`. |

## Drag And Drop

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Payload | Local drag payload has `songIds` and `folderPaths`. | Same semantic payload. | Drag single song, selected songs, folder, selected folder. | Covered for compact song/folder branches and breadcrumb payload acceptance by Local drag tests. |
| Selected folder drag | Dragging selected folder moves all selected folder absolute paths. | Same. | Select two folders and drag one; both move. | Covered by `LocalPage dragging a selected folder moves selected folders`. |
| Selected song drag | Dragging selected song moves all selected song IDs. | Same. | Select two songs and drag one; both move. | Covered by `LocalPage dragging a selected song moves selected songs`. |
| Unselected drag | Dragging an unselected song/folder moves only that item. | Same. | Drag unselected item while other items selected. | Unselected song branch covered by `LocalPage dragging an unselected song moves only that song`; unselected folder branch covered by `LocalPage dragging an unselected folder moves only that folder`. |
| Valid targets | Target must not be empty, same folder, already parent, descendant, or a song's current folder. | Same. | Illegal targets reject drop; legal targets accept. | Covered by `isMoveTargetFolder mirrors Electron local folder drop rules` plus compact valid drag tests. |
| Folder drop target | Folder cards/rows accept valid local item drops. | Same. | Drag song to folder card/row. | Covered in compact list case; grid/table variants need pass. |
| Breadcrumb drop target | Breadcrumb segments and child flyout items accept valid local item drops. | Same. | Drag song/folder to breadcrumb segment/child item. | Covered by `FolderChainListView accepts drops on path segments and child flyout items`. |
| Drop side effect | Accepted drop calls move local items and clears drag/selection state. | Same. | After drop, repository receives IDs/paths/target and selection clears. | Covered for compact folder/song drops; breadcrumb target callbacks are covered by `FolderChainListView accepts drops on path segments and child flyout items`. |

## Refresh Result Dialog

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Trigger | Refresh result with changes shows notification with Detail action; Detail opens dialog. | Same user flow or direct equivalent. | Refresh folder with changes, open details. | Covered by refresh result test. |
| Refresh notification text | Single added/removed/moved file uses the single-item i18n key with stripped file title; multiple uses count text. Artist split/merge counts are appended and joined by `common.comma`. | Same. | Refresh with one added file says added file title; refresh with multiple added says count. | Implemented; covered by `refresh result message mirrors Electron single and multiple copy`. |
| Refresh error mapping | Errors prefixed `Folder not found: ` and `Cannot access folder: ` map to localized not-found/access-denied messages; other errors pass through. | Same. | Simulate both prefixed errors and a generic error. | Implemented; covered by `refresh folder error message mirrors Electron prefix mapping` and LocalPage error test. |
| Refresh no reentry | Electron ignores refresh when scan is already running or a refresh is already in progress. | Same. | Double-click refresh while running; only one refresh request is sent. | Implemented; covered by `LocalPage refresh ignores duplicate requests while running`. |
| No changes | No-change result shows `local.refreshNoChange` message, no detail dialog. | Same. | Refresh no-change folder. | Covered by `LocalPage refresh ignores duplicate requests while running`. |
| Tabs | Dialog has Added, Removed, Moved, Artist Updates tabs depending on result counts. | Same. | Result with all groups shows all relevant tabs/counts. | Covered by `FolderUpdateResultDialog shows all Electron result tabs`; dedicated dialog doc has style details. |
| File title logic | Titles are relative to refreshed folder, extension stripped; duplicates fall back to full path. | Same. | Duplicate file titles show full path; unique strips prefix/ext. | Covered by `folder update file titles mirror Electron duplicate rules`. |
| Playable result rows | Added/moved rows are playable; removed rows are not. | Same. | Added row can play/open menu; removed row cannot play. | Added row play/menu and removed-row non-play covered by `FolderUpdateResultDialog playable rows play and open menu`. |
| Result song menu | Result-dialog song menu disables Select, Music Properties, and Delete. | Same. | Open result song menu and verify excluded actions. | Covered through Local integration by `LocalPage refresh result song menu excludes Electron actions`; row callback coverage remains in `FolderUpdateResultDialog playable rows play and open menu`. |
| Artist suggestions | Artist tab embeds artist split review and applying/dismissing updates dialog state. | Same. | Apply/dismiss suggestions from result dialog. | Covered by artist split review tests. |

## Hidden Folders Page

| Area | Electron rule | Flutter target | Acceptance check | Current evidence |
|---|---|---|---|---|
| Entry | Opened from Local hidden folders button/overflow. | Same. | Click entry from wide and compact Local. | Wide entry covered by `LocalPage hidden folders entry opens and resumes items`; compact overflow covered by `LocalPage compact overflow opens hidden folders entry`. |
| Loading | Shows loading state while hidden items load. | Same. | Force loading and verify shared loading state. | Covered by `HiddenFoldersPage shows Electron loading state`. |
| Introduction | Shows hidden item explanation text. | Same i18n key. | Hidden page contains introduction copy. | Covered by `LocalPage hidden folders entry opens and resumes items`. |
| Empty state | Shows no hidden items state when list empty. | Same. | Empty hidden storage list. | Covered by `LocalPage hidden folders route shows initial empty state`. |
| Resume | Each hidden item has Resume action; resume invalidates library content. | Same. | Resume item and verify repository call plus Local refresh. | Covered by `LocalPage hidden folders entry opens and resumes items`. |
| No IDs | Hidden rows must not display storage IDs. | Same. | Inspect visible text for no raw IDs/dev info. | Covered for fixture row by `LocalPage hidden folders entry opens and resumes items`. |

## Existing Flutter Test Evidence

`test/local_page_test.dart` already covers these Local acceptance slices:

- Toolbar shuffle scope menu.
- Refresh result details for added/removed/moved files.
- List mode columns and basic song play.
- List mode artist and album cell route navigation.
- Table quick jump row visibility and title-bucket jump behavior.
- Table quick jump title, artist, and reverse-over-album basis behavior.
- Compact list/tree rows and child-song queue behavior.
- Compact list song drag onto folder.
- Compact drag payload semantics for selected folders, selected songs,
  unselected folders, and unselected songs.
- Folder click routing from Local root to a relative folder.
- Compact tree non-expandable folders do not expose a toggle; compact Select
  All covers visible expanded tree rows plus current direct songs.
- List virtualization.
- List/table section headers when both folders and songs are present.
- Grid section collapse when folders and songs are both present, plus song-only
  and folder-only no-header behavior.
- No toolbar view toggle.
- Empty root choose-and-scan flow.
- Empty scanned library settings action.
- Root scan progress and cancellation.
- Multi-select add selected folder to playlist.
- Song Add To menu for Now Playing and My Favorites.
- New folder creation and visibility.
- Sort blocked in multi-select mode.
- Toolbar sort menu checkmark state.
- Local page and Hidden Folders loading states.
- Toolbar direct child folder/song stats.
- Multi-select Delete From Disk visible-disabled state with zero selected items.
- Folder context sort submenu checkmark state.
- Album-sort song detail subtitle rendering.
- Folder search input dialog, empty-query validation, and folder-scoped search.
- `/local?path=Sub` and `/local?path=Sub/Deep` route query folder opening.
- `/local?path=Missing` folder-not-found state and Back to Root route recovery.
- Shell app bar Local title replacement and compact breadcrumb rendering.
- Filtered-out selected items ignored.
- Folder-name search filtering and search no-result copy.
- Filtered Select All uses only visible/selectable items.
- Folder changes clear multi-select state.
- Truly empty folders render without scan/search empty copy.
- Normal folder context menu major actions and preference.
- Folder menu creates a child under the target folder.
- Selected local items move and delete.
- Multi-select hide-after-operation setting is covered for both on and off.
- Selected queue IDs are deduped when a selected folder and selected song
  overlap.
- Song context menu major actions and Select.
- Song context menu move-to-folder with undo, hide-file with undo, and current
  playing Pause action.
- Song View menu opening MusicDialog.
- Folder chain child flyout click.
- Folder chain right-click callback.
- Breadcrumb label/root/segment construction and child dropdown visibility.
- Folder chain pointer-drag horizontal scroll and drag/drop acceptance on path
  segments plus child flyout items.
- Local grid folder card visible content/no-ID checks and folder play/add
  actions.
- Folder update result dialog shell, current playing wave, long-list
  constraint, and playable added row play/menu interaction.
- Local refresh-result song menu excludes Select, View/Music Properties, and
  Delete actions.
- Folder thumbnail candidate grouping and ordering.

These tests are useful evidence, but they do not fully replace manual desktop
inspection for platform-specific text rendering and visual discoverability.

## Second-Pass Missing Or Weak Coverage

The following items were easy to miss and should be treated as high-priority
acceptance gaps until verified or implemented:

| Gap | Why it matters | Current status |
|---|---|---|
| Breadcrumb wheel-to-horizontal scroll | Electron explicitly maps wheel movement to horizontal path scrolling. | Implemented in Flutter; `test/local_title_grid_test.dart` verifies wheel horizontal scroll. |
| Breadcrumb pointer-drag horizontal scroll | Electron supports drag-scrolling and suppresses accidental click after drag. | Covered by `FolderChainListView pointer drag scrolls and suppresses segment tap`. |
| Breadcrumb drag/drop targets | Electron accepts local item drops on path segments and child flyout items. | Implemented for non-current path segments and child flyout targets; `test/local_folder_model_test.dart` verifies illegal descendant/self/parent target rules. |
| Breadcrumb current-segment scroll-to-top | Electron scrolls current Local content to top on current segment click. | Implemented in Flutter; `test/local_title_grid_test.dart` verifies callback. |
| Breadcrumb menu exclusion list | Breadcrumb menu is intentionally smaller than normal folder menu. | Covered by `LocalPage breadcrumb menu keeps Electron reduced actions`. |
| Deep/long breadcrumb runtime behavior | Source exists, but overflow usability must be proven. | Deep-path screenshot, breadcrumb-flyout screenshot, wheel-scroll test, pointer-drag test, and child-flyout clamp/scroll test now cover the automated portion. |
| Child flyout close/switch behavior | Opening was tested; closing and switching dropdowns was not. | Covered by `FolderChainListView closes and switches child flyouts`. |
| Breadcrumb Search Directory flow | Normal folder search is tested; breadcrumb-target search is not. | Covered by `LocalPage breadcrumb search uses target folder scope`. |
| Hidden folders page resume flow | Route/source exists; resume behavior needs Local-page integration evidence. | Covered by `LocalPage hidden folders entry opens and resumes items`. |
| Folder rename/delete/hide single-item flows | Multi-select delete is covered; single folder menu operations need coverage. | Covered for rename-to-new, rename unchanged no-op, delete, hide, and undo by `LocalPage single folder rename hide and delete mirror Electron`. |
| Folder sort submenu persistence | Sort-blocking is covered; positive folder sort update needs coverage. | Covered by `LocalPage folder sort menu persists target folder`. |
| Folder thumbnail candidate ordering | Folder card artwork content depends on Electron album-group and thumbnail ordering rules. | Candidate grouping and ordering covered by `folder thumbnail candidate groups mirror Electron ordering`; resolved artwork path covered by `Local folder thumbnail resolver keeps resolved artwork path`; final image rendering covered by `Local grid folder card renders resolved artwork image`. |
| Refresh notification single vs multiple text | Electron has different single-file and multi-file copy. | Implemented and covered by `test/local_folder_model_test.dart`. |
| Refresh error mapping and duplicate refresh blocking | Electron maps known scan errors and blocks concurrent refreshes. | Implemented and covered by `test/local_folder_model_test.dart` plus `test/local_page_test.dart`. |
| Search filter fields | Electron matches folder name plus song title, artist, artists array, album, and path. | Song fields covered by `matchesSongSearch mirrors Electron searchable song fields`; folder-name widget filtering covered by `LocalPage search filters folders and empty results`. |
| Select all/reverse/clear/cancel | Multi-select basics exist; full command set needs coverage. | Covered for wide visible set by `LocalPage selection commands mirror Electron sets`, filtered set by `LocalPage filtered select all uses visible items only`, and compact visible tree set by `LocalPage compact tree select all uses visible tree rows`. |
| Single-song move/hide/current pause | Song menu content existed, but side effects and undo were not proven. | Covered by `LocalPage song context menu moves and hides single song` and `LocalPage current song context menu pauses playback`. |
| Refresh result playable rows | Dialog row rendering existed, but playable row callbacks were not proven. | Added-row play/menu and removed-row non-play covered by `FolderUpdateResultDialog playable rows play and open menu`. |
| Illegal drag/drop target matrix | One valid compact drop is covered; invalid target rules need coverage. | Valid selected-folder, selected-song, unselected-folder, and unselected-song drag payload branches are covered; invalid empty/same/current-parent/descendant/current-song-folder targets are covered by `isMoveTargetFolder mirrors Electron local folder drop rules`. |
| Artist/album row navigation from Local table | Electron table rows link artist/album. | Covered by `LocalPage table artist and album cells navigate like Electron`. |
| Table quick jump row | Electron table quick jump is horizontal and jumps by title/artist/album bucket. | Covered by `LocalPage table quick jump jumps by Electron title bucket`, `LocalPage table quick jump follows Electron artist basis`, and `LocalPage table quick jump reverse keeps Electron album basis`. |
| Grid section visibility/collapse | Electron only shows collapsible section headers when folders and songs both exist. | Both-groups collapse and song-only no-header behavior covered by `LocalPage grid sections collapse only when both groups exist`; folder-only case covered by `LocalPage grid folder-only content has no section headers`. |
| OS reveal commands | Needs platform callback/runtime evidence, not just source. | Flutter callback paths are covered for folder reveal and song See Local; command contract covered by `desktop_features_test.dart`; macOS runtime check confirmed `open -R` selected the file and `open` targeted the folder in Finder. |
| Screenshot evidence | Existing tests were behavior-focused; visual discoverability needs screenshots. | Added Flutter-rendered wide Local light/night, empty-root night, compact night, compact expanded-tree night, deep-breadcrumb night, breadcrumb-flyout night, table night, current-song night, and Hidden Folders night screenshots. Manual desktop screenshots are still useful for platform font/text readability. |

## Implementation Notes - 2026-05-31

Confirmed Electron evidence used for this pass:

- `src/pages/LocalTitleGrid.tsx`: wheel-to-horizontal scroll, path drag scroll,
  current segment scroll-to-top, non-current breadcrumb drop targets, child
  flyout drop targets, and reduced breadcrumb menu.
- `src/pages/localPageModel.ts` and `src/pages/LocalPage.tsx`: refresh result
  single/multiple messages, refresh folder error prefix mapping, and duplicate
  refresh blocking while a refresh is already running.
- `src/styles/local.css` and `src/styles/local-table.css`: night-mode Local,
  hidden folders, breadcrumb flyout, empty-state artwork, refresh overlay/dialog,
  and move progress colors.

Flutter changes completed in this pass:

| Item | Flutter files | Status |
|---|---|---|
| Local night palette | `local_page_quick_jump.dart`, `app_appearance_model.dart` | Added `LocalPageColors` theme extension with day/night palettes and registered it in app theme. |
| Local components use themed colors | Local page shell/title/grid/table/folder card/hidden folders/scan overlay files | Replaced Local static color reads with `LocalPageColors.of(context)` in scoped Local UI. |
| Breadcrumb current segment click | `local_title_grid.dart`, `local_page.dart` | Current segment now calls Local scroll-to-top. |
| Breadcrumb wheel horizontal scroll | `local_title_grid.dart` | Wheel delta maps to horizontal list scroll. |
| Breadcrumb pointer drag scroll | `local_title_grid.dart` | Dragging the path list changes horizontal offset and suppresses the follow-up segment tap. |
| Breadcrumb drop targets | `local_title_grid.dart`, `local_page.dart`, `local_page_model.dart` | Non-current path segments and flyout children accept `LocalItemsDragPayload`; descendant/self/parent invalid moves are rejected like Electron. |
| Breadcrumb child flyout clamp | `local_title_grid.dart`, `test/local_title_grid_test.dart` | Flyout max width now follows Electron `min(420px, 100vw - 48px)` behavior and no longer expands past a narrow viewport; disposing an open flyout no longer calls `setState`. |
| Refresh messages and errors | `local_page_model.dart`, `local_page_scan_actions.dart` | Single file refresh messages use stripped file titles, multiple messages use counts, known refresh errors map to localized messages, no-change refresh does not open a result dialog, and duplicate refresh requests are ignored while running. |
| Route and compact entry coverage | `local_page.dart`, `test/local_page_test.dart` | `/local?path=Sub` opens the target folder, and compact CommandBar overflow opens Hidden Folders. |
| Empty local folder layout | `local_page_empty_content.dart`, `test/local_page_test.dart` | Empty folders without search now render `SizedBox.shrink()` instead of an expanding box inside a scroll view; no scan/search copy is shown. |
| Compact tree toggles | `local_folder_card.dart`, `local_table_content.dart`, `test/local_page_test.dart` | Non-expandable compact folders no longer render tree chevrons, matching Electron's `row.expandable ? chevron : null` behavior. |
| Hidden folders route/resume coverage | `hidden_folders_page.dart`, `test/local_page_test.dart` | Wide Local hidden entry opens Hidden Folders, Resume calls repository, list refreshes to empty state, and fixture storage IDs are not displayed. |
| Multi-select command coverage | `local_page.dart`, `test/local_page_test.dart` | Select all, reverse, clear, cancel, filtered select-all, compact visible-tree select-all, clear-on-folder-change, hide-after-operation on/off, and selected mixed folder/song queue are covered. |
| Breadcrumb/folder menu coverage | `local_page_context_menus.dart`, `local_page_folder_actions.dart`, `test/local_page_test.dart` | Breadcrumb Shuffle, Add To existing playlist, Move To Folder, Preference, Search Directory, and excluded action list are covered against the target folder path; folder sort, rename/new/no-op, hide/undo, delete, and folder-menu child creation are also covered. |
| Playback/add/sort coverage | `local_page_playback_actions.dart`, `local_page_add_to_actions.dart`, `local_page_context_menus.dart`, `test/local_page_test.dart` | Empty current-folder Shuffle shows the Electron no-music copy; direct folder Add To uses subtree IDs; toolbar sort persists current folder criterion; song Play Next inserts after the current queue index. |
| Single-song menu side effects | `local_page_context_menus.dart`, `library_page_actions.dart`, `test/local_page_test.dart` | Move To Folder calls single-song local move path and undo; Hide File calls hide/unhide; current playing song menu shows Pause and toggles playback. |
| Refresh-result playable rows | `folder_update_result_dialog.dart`, `folder_update_result_sections.dart`, `test/folder_update_result_dialog_test.dart` | Added result row hover play button calls `onPlay`; right-click row opens the result song menu callback for that song; removed rows do not play or open a song menu. |
| Additional model/UI coverage | `local_folder_model.dart`, `local_title_grid.dart`, `test/local_folder_model_test.dart`, `test/local_title_grid_test.dart`, `test/local_page_test.dart` | Folder criterion ordering, song search fields, child flyout close/switch/clamp/scroll/right-click, ancestor segment click, hidden initial empty state, and Play selected queue are covered. |
| Table/grid route coverage | `local_page.dart`, `local_table_content.dart`, `local_page_quick_jump.dart`, `test/local_page_test.dart` | Table quick jump uses Electron's horizontal row form and jumps by title/artist/reverse-over-album bucket; reverse sort is preserved as a transient sort mode instead of being reset to saved folder criterion; table artist/album cells route to `/artists?artist=` and `/albums?album=`; nested Local route query opens `Sub/Deep`; grid collapsible sections are covered for both-groups plus song-only/folder-only states. |
| Drag/section coverage | `local_grid_content.dart`, `local_folder_card.dart`, `local_page_model.dart`, `test/local_page_test.dart`, `test/local_folder_model_test.dart` | Folder-only grid content renders without redundant section headers; compact drag payloads move all selected folders, all selected songs, only the dragged unselected folder, or only the dragged unselected song; illegal drag targets reject empty payload, same folder, current parent, descendant, and song-current-folder cases. |
| Sort/detail/thumbnail coverage | `local_page.dart`, `local_folder_model.dart`, `test/local_page_test.dart`, `test/local_folder_model_test.dart` | Toolbar sort checkmark tracks the saved sort mode; album sort shows the Electron artist-album detail label in the grid; folder thumbnail candidates use direct-song album groups first, then child folder groups in folder-ID order with direct thumbnail songs sorted by song ID. |
| Loading/stats/delete/sort menu coverage | `local_page.dart`, `hidden_folders_page.dart`, `test/local_page_test.dart` | Local and Hidden Folders shared loading states are covered; toolbar stats use direct child folder/song counts; multi-select Delete From Disk stays visible but disabled with zero selected items like Electron; folder context sort submenu checkmark tracks the target folder criterion. |
| Breadcrumb and grid interaction coverage | `local_title_grid.dart`, `local_grid_content.dart`, `test/local_title_grid_test.dart`, `test/local_grid_content_test.dart` | Breadcrumb pointer drag changes horizontal offset and suppresses accidental segment open; breadcrumb path segments and child flyout items accept drag payloads; grid folder cards show user-facing name/stats without IDs/paths and wire play/add callbacks. |
| Shell and route recovery coverage | `shell_workspace.dart`, `local_page.dart`, `test/workspace_app_bar_test.dart`, `test/local_page_test.dart` | Local app bar replaces the generic title with compact breadcrumb content when a root path exists; missing Local folders show Electron copy and Back to Root returns without scroll-controller crashes. |
| Last-page/reveal/thumbnail callback coverage | `app_route_model.dart`, `local_page.dart`, `local_page_folder_actions.dart`, `test/app_router_test.dart`, `test/local_page_test.dart`, `test/local_grid_content_test.dart` | Restored `/local?path=...` now resolves to `/local`; folder reveal and song See Local pass the Electron absolute path into injectable platform callbacks; folder thumbnail resolver keeps resolved cached artwork paths. |
| Refresh title/current song/OS evidence | `folder_update_result_file_title.dart`, `desktop_features.dart`, `test/folder_update_result_dialog_test.dart`, `test/local_page_visual_verify_test.dart`, `test/desktop_features_test.dart` | Refresh result titles strip the refreshed folder prefix and extension while duplicate titles fall back to full path; current song night screenshot is generated; reveal/open folder shell command contracts are covered and macOS Finder runtime selection/target was verified. |
| Table row coverage | `local_table_content.dart`, `test/local_table_content_test.dart` | Folder rows open folders, expose context menu callbacks, and wire play/add/refresh/search/reveal actions; song rows wire play/add/play-next/menu actions and artist/album route cells. |

Verification from this pass:

- `flutter analyze` passed for the whole repo.
- `flutter test test/local_page_test.dart test/folder_update_result_dialog_test.dart
  test/local_title_grid_test.dart test/local_folder_model_test.dart
  test/local_grid_content_test.dart test/local_table_content_test.dart
  test/workspace_app_bar_test.dart test/local_page_visual_verify_test.dart
  --concurrency=1` passed with 123
  widget/unit tests.
- `flutter test test/folder_update_result_dialog_test.dart --plain-name
  "folder update file titles mirror Electron duplicate rules" --concurrency=1`
  passed.
- `flutter test test/local_page_visual_verify_test.dart --plain-name
  "writes current song night verification screenshot" --concurrency=1` passed
  and writes `build/smplayer_local_page_current_song_dark_verify.png`.
- `flutter test test/desktop_features_test.dart --plain-name "reveal item
  commands use one Electron-style shell contract" --concurrency=1` passed.
- `flutter test test/desktop_features_test.dart --plain-name "open folder
  commands are shared by Local, Search, and settings logs" --concurrency=1`
  passed.
- macOS shell runtime check: `open -R` on a temporary `Track.mp3` returned
  Finder `selection=/private/tmp/.../Track.mp3`; `open` on its folder returned
  Finder `target=/private/tmp/.../`.
- `flutter test test/app_router_test.dart --plain-name "restored page follows
  Electron restorable route list" --concurrency=1` passed and covers
  `/local?path=Sub/Deep` restoring to `/local`.
- A broader run that included all of `test/app_router_test.dart` reached
  `+135 -4`; the four failures were existing non-Local app-router/portal route
  cases (`album query route opens Electron-style album detail`,
  `non-library-root tabs bypass missing-library-root prompt`,
  `sidebar back returns playlist details to playlists`, and
  `sidebar search commits to search route and recent history`). The Local-page
  files in that same run continued through the then-current 117 checks; the
  later file-title, current-song screenshot, and folder artwork image tests are
  covered by the 120-test Local-page run above.
- `flutter test test/local_page_test.dart --concurrency=1` passed with 69
  widget tests after adding table artist/album navigation, table quick jump
  title/artist/reverse-over-album basis coverage, selected/unselected drag
  payload coverage, folder click routing, overlapping selected-queue dedupe,
  refresh-result song-menu exclusions, toolbar sort checkmark state, album-sort
  song detail rendering, grid section collapse/no-header coverage, nested route
  query, empty-folder Shuffle, direct folder Add To, compact Hidden Folders
  overflow, toolbar Sort persistence, song Play Next coverage, Local/Hidden
  loading states, toolbar direct-count stats, disabled delete state, and folder
  sort-menu checkmark coverage.
- `flutter test test/local_page_test.dart test/folder_update_result_dialog_test.dart
  --concurrency=1` passed with 45 widget tests after adding folder filtering,
  filtered/compact selection, empty-folder, folder-child-create, rename no-op,
  hide-after-operation setting-off, and removed-result-row coverage.
- `flutter test test/local_page_test.dart test/folder_update_result_dialog_test.dart
  --concurrency=1` passed with 38 widget tests after adding single-song
  move/hide/current-pause coverage and refresh-result playable-row coverage.
- Earlier in this pass, `flutter test test/local_page_test.dart
  test/local_title_grid_test.dart test/local_folder_model_test.dart
  test/local_page_visual_verify_test.dart --concurrency=1` passed with 48
  widget/unit tests.
- `flutter test test/local_title_grid_test.dart test/local_grid_content_test.dart
  --concurrency=1` passed with 12 widget tests after adding breadcrumb
  label/chain/dropdown visibility, pointer-drag, breadcrumb path/flyout drop
  acceptance, and grid folder content/action coverage.
- `flutter test test/workspace_app_bar_test.dart --concurrency=1` passed with
  9 widget tests, including Local title replacement and compact breadcrumb
  app-bar coverage.
- `flutter test test/local_page_visual_verify_test.dart --concurrency=1`
  passed with 8 widget screenshot tests.
- `test/local_page_visual_verify_test.dart` writes these screenshot artifacts:
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_light_verify.png`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_dark_verify.png`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_empty_root_dark_verify.png`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_compact_dark_verify.png`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_compact_tree_dark_verify.png`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_deep_breadcrumb_dark_verify.png`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_breadcrumb_flyout_dark_verify.png`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_table_dark_verify.png`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_local_page_current_song_dark_verify.png`
  - `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/build/smplayer_hidden_folders_dark_verify.png`
- These Flutter test screenshots verify non-blank Local day/night, Local
  empty-root night, compact night, compact expanded-tree night, deep-breadcrumb
  night, breadcrumb-flyout night, Local table night, current-song night, and
  Hidden Folders night rendering. Because Flutter widget tests use test fonts,
  a final manual desktop screenshot pass is still useful for platform text
  readability.

## Suggested Acceptance Run Order

1. Run current widget coverage:

   ```sh
   flutter test test/local_page_test.dart
   flutter test test/folder_update_result_dialog_test.dart
   flutter test test/local_title_grid_test.dart
   flutter test test/local_grid_content_test.dart
   flutter test test/local_table_content_test.dart
   flutter test test/local_folder_model_test.dart
   flutter test test/workspace_app_bar_test.dart
   flutter test test/local_page_visual_verify_test.dart
   flutter test test/artist_split_review_dialog_test.dart
   ```

2. Optional manual desktop pass with a fixed library fixture:

   - wide Local root
   - wide deep folder with long breadcrumb
   - compact Local root
   - compact expanded tree
   - list mode
   - refresh result dialog
   - hidden folders page

3. Record screenshots or runtime notes for UI-only acceptance. If a screenshot
   still shows a behavior gap, mark it as remaining; do not call it aligned.
