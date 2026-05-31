# Hidden Folders Electron Acceptance Matrix

## Scope

This document freezes the Electron target for the hidden folders surface before Flutter changes. Electron remains the source of truth.

## Confirmed Electron Sources

- Page: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/HiddenFoldersPage.tsx`
- Hook: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/hooks/useHiddenStorageItems.ts`
- Route: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/AppRoutes.tsx`
- Title resolver: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/appModel.ts`
- Local entry/action points: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalTitleGrid.tsx`, `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalPage.tsx`
- Store calls: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/state/useLibraryStore.ts`
- CSS: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/local.css`, `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/local-table.css`, `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/appbar.css`

## Flutter Sources

- Page: `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/hidden_folders_page.dart`
- Route/title: `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/app/app_router.dart`, `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/app/shell_workspace.dart`
- Local entry/action points: `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_title_grid.dart`, `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page.dart`, `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_context_menus.dart`
- Repository/service: `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/data/library_repository.dart`, `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/data/library_hidden_storage_service.dart`
- Tests/proof: `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/test/local_page_test.dart`, `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/test/library_repository_test.dart`, `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/test/local_page_visual_verify_test.dart`

## Acceptance Matrix

| Area | Electron rule | Flutter target | Verification |
| --- | --- | --- | --- |
| Route | `/hidden-folders` renders `HiddenFoldersPage`; shell title is `local.hiddenFolders`. | `/hidden-folders` renders `HiddenFoldersPage`; shell title uses the same i18n key. | `LocalPage hidden folders entry opens and resumes items`; router/source audit. |
| Local wide entry | Local breadcrumb/title grid has hidden folders button with `hiddenFolders` icon and `local.hiddenFolders` tooltip. | `LocalTitleGrid` hidden folders button opens `/hidden-folders`. | `LocalPage hidden folders entry opens and resumes items`. |
| Local compact entry | Compact Local command bar puts `local.viewHiddenFolders` in overflow. | Compact `CommandBar` overflow opens `/hidden-folders`. | `LocalPage compact overflow opens hidden folders entry`. |
| Hide folder action | Folder menu `local.hideFolder` calls hide local folder, clears selection/menu, and shows undo that resumes by path. | Folder menu hides repository folder, invalidates content, clears local selection, and undo restores the folder. | Existing Local page context menu tests plus repository hidden-state tests. |
| Hide file action | Electron song menus call `hideSong`, show `notification.hiddenStorageItem`, and undo restores by hidden path. Hidden storage list later shows the item as type `file`. | Shared Flutter song hide helper calls repository `hideSong`, undo calls `unhideSong`; hidden list renders `file` rows and restores them through `resumeHiddenStorageItem`. | `LocalPage hidden folders entry opens and resumes items`; repository hide/unhide coverage. |
| Root refresh banner | `HiddenFoldersPage` receives global `pageLoading`; when true it renders `.root-banner` with `library.refreshing` between introduction and hidden item list. | Hidden page watches `libraryContentDataProvider.isLoading` and renders the same banner position and card treatment. | `HiddenFoldersPage shows Electron root refresh banner`. |
| Hidden page load | Page loads hidden storage items when active. While item loading is pending, compact `LoadingState` is shown as an `empty-state loading-state compact` card. | `HiddenFoldersPage` fetches `getHiddenStorageItems` on init and shows a compact status card until done. | `HiddenFoldersPage shows Electron loading state`. |
| Introduction | `hiddenFolders.introduction`; margin `10px 20px`; text strong, 16px, weight 400, line-height 1.45. | Same copy and matching text styling/inset. | Widget style assertion and screenshot `build/smplayer_hidden_folders_dark_verify.png`. |
| List surface | `.hidden-storage-list` fills remaining height, starts at top, native scroll, bottom padding 18, no row gaps. | Expanded list starts under intro, scrolls, bottom padding 18, no separators. | Screenshot `build/smplayer_hidden_folders_dark_verify.png`. |
| Row layout | Three columns: icon, path, Resume. Min height 42px, padding 6px, 8px gap. | Row uses icon/path/button layout with min height 42 and Electron spacing. | `LocalPage hidden folders entry opens and resumes items`; screenshot. |
| Row background | Even rows use `surface-subtle`; odd rows use `panel`; no card border/radius. | Alternating row background without card border/radius. | Screenshot. |
| Icon | Folder items use folder icon; file items use songs/music icon. Icon box is 30x30 with 6px horizontal margin; icon 22px; muted foreground. | Folder/file icons match type and muted visual weight. | Screenshot and fixture with folder/file items. |
| Path | Raw storage path is displayed, wraps anywhere; no storage ID is displayed. | Path text displays `item.path`, can wrap, and does not render `id`. | `LocalPage hidden folders entry opens and resumes items`. |
| Resume | Button copy is `hiddenFolders.resume`; min height 32px; 4px radius; surface-control background; subtle border; hover uses accent tint/strong accent. | Resume is an outlined surface-control button with Electron dimensions and hover colors. | Widget assertion and screenshot. |
| Empty state | If no hidden items and not loading, `empty-state compact hidden-storage-empty` displays `hiddenFolders.empty` inside an `h3`; margin is `0 20px`, card padding `16px 18px`, radius `18px`, and common empty-state border/background. | Empty state uses the same compact status-card structure and inset. | `LocalPage hidden folders route shows initial empty state`. |
| Resume flow | Resume calls `resumeHiddenStorageItem(item)`, refreshes songs/folders, then reloads hidden storage items. | Page calls repository resume, invalidates library content, and reloads hidden items. | `LocalPage hidden folders entry opens and resumes items`; `hidden folder state mirrors Electron parent-hidden semantics`. |
| Repository semantics | Hiding a folder records the parent as hidden and descendants as parent-hidden; restoring the parent restores descendants and removes hidden list entry. | `LibraryHiddenStorageService` mirrors parent-hidden state and restore behavior. | `hidden folder state mirrors Electron parent-hidden semantics`. |
| Night mode | `.workspace:has(.hidden-folders-page)` uses night shell background; hidden page text uses night text variables. | Hidden page reads `LocalPageColors.of(context)` and follows dark theme colors. | `writes HiddenFoldersPage night verification screenshot`. |

## Confirmed Flutter Differences Fixed

- Hidden page used 24/18 page padding instead of Electron `padding: 0`.
- Introduction used muted 14px semibold text instead of Electron strong 16px regular text.
- Empty state used a Flutter-specific 20px title card; it now mirrors Electron `empty-state compact hidden-storage-empty` sizing and card treatment.
- Loading state used the shared centered Flutter loading widget; it now mirrors Electron's compact inline `empty-state loading-state compact` status card.
- The global refresh banner was missing; hidden page now mirrors Electron `loading={pageLoading}` with a `library.refreshing` root banner while library content is loading.
- Rows used separate rounded cards, borders, 8px separators, accent icons, single-line ellipsis paths, and `FilledButton`; Electron uses full-width zebra rows, muted icons, wrapping paths, and a subtle outlined button.

## Unconfirmed / Not Changed

- Runtime pixel comparison against a live Electron window is not yet captured in this document; Flutter visual proof is generated by widget screenshot.
