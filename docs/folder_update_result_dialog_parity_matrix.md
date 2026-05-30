# Folder Update Result Dialog Parity Matrix

Electron source of truth:

- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/FolderUpdateResultDialog.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/LocalPage.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/localPageModel.ts`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/local-table.css`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/song-dialog.css`

Flutter target files:

- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/folder_update_result_dialog.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/folder_update_result_sections.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/folder_update_result_tab_button.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page.dart`
- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/local_page_context_menus.dart`

| Area | Electron rule | Flutter acceptance check |
| --- | --- | --- |
| Shell | Uses `PopupDialog` with `folder-update-result-dialog ContentDialog`, `780px x 760px`, `12px` radius, overlay blur, close button in nav. | `FolderUpdateResultDialog` uses shared `PopupDialog` with `width: 780`, `height: 760`; close remains in the nav row. |
| Title | `local.updateResultOfFolder` with `folder.name`; title is one line, ellipsized. | Title text uses the same i18n key and remains one line with ellipsis. |
| Tab presence | Added, removed, moved tabs are shown only when their result arrays are non-empty; artist tab is shown only when artist update count is positive. | Tabs are conditionally rendered from the same result arrays/count. |
| Initial tab | Artist updates first when present; otherwise first non-empty file group, ordered added, removed, moved. | `_initialTab()` follows the same priority. |
| Tab style | Pill tabs, `34px` high, `8px` gap, icon `14px`, label `14px/720`, count pill min `22px` x `22px`. | `FolderUpdateResultTabButton` matches these dimensions and uses `PopupDialogColors` for light/night states. |
| File title logic | `getUpdateResultFileTitle()` normalizes paths, strips the folder prefix and extension; duplicated titles fall back to full path. | `folder_update_result_file_title.dart` keeps the same normalization, extension stripping, and duplicate full-path rule. |
| List layout | Result list has `10px` radius, border, internal scroll, row height `66px`, and at most `14` visible rows. | File section height is `min(rowCount * 66, 14 * 66, available pane height)` and scrolls inside the list. No bottom overflow at `1200x900`. |
| Added/moved rows | Playable rows have artwork `42px`, title, context menu on right click, and playback only through the artwork play button. | Added/moved rows do not play on whole-row click; artwork button calls `onPlay`; secondary click opens the song menu. |
| Removed rows | Removed rows are disabled, no artwork, muted text, no playback or song menu. | Removed rows render as non-playable text rows with muted color and no menu callback. |
| Row backgrounds | Light mode: removed rows alternate `rgba(246,249,253,.82)` and `rgba(255,255,255,.72)`; playable rows stay `rgba(255,255,255,.72)`. Night mode: rows alternate `.055` and `.035` white overlays. | Row color matrix follows those rules through `PopupDialogColors` and `Theme.brightness`. |
| Hover/focus | Non-disabled rows hover/focus to accent overlay; current artwork wave hides when artwork play button is visible. | Playable rows use accent hover background; row hover reveals the artwork play overlay and hides the wave. |
| Song menu | Result menu passes `showSelect=false`, `showMusicProperties=false`, `showDelete=false`. | `LocalPage` result dialog menu call uses these flags; normal local-page song menus keep their defaults. |
| Artist updates | Artist tab embeds `ArtistSplitReviewPanel`; applying/dismissing updates the result state from the Local page flow. | Existing `FolderUpdateResultArtistSection` remains embedded and is not reimplemented in this migration. |

Unconfirmed before runtime verification:

- Exact Electron rendered pixels for the current user data, because this pass has source and CSS evidence but no fresh Electron screenshot yet.
