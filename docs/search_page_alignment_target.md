# Search Page Alignment Target

Source of truth: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/pages/SearchPage.tsx`,
`SearchResultSections.tsx`, `src/shared/SearchHelper.ts`, and `src/styles/search.css`.

## Business Logic

- Query scope: when `folder` is present, search only songs and folders under that folder; playlists still participate by containing matched scoped songs.
- Filter tabs: tabs are `All`, `Artists`, `Albums`, `Songs`, `Playlists`, `Folders`; non-All empty tabs are disabled and sorted after non-empty tabs.
- Filter tabs visibility: tabs render only when there are search results. Empty query, loading without query, and no-result states do not show result tabs.
- Typed filters: if the current `type` has zero results, Electron renders the tabs but no empty section header for that type.
- Filter navigation: changing a tab updates `/search?query=...&type=...` with `type` omitted for All, preserves `folder`, clears selection, and records recent search as `sidebar` for All or the concrete type otherwise.
- Query/folder change: reset active filter to All, clear expanded sections, clear selection, close transient menus/dialogs.
- Preview mode: All tab uses preview limits. Artists preview limit is 10; other sections preview limit is 5.
- View all/view less: expands or collapses the current section inside All. It does not switch to the section filter route.
- Sorting: each section uses the Electron sort options and persists to the matching `search*Criterion` setting.
- Selection: songs and cards are selected separately but command actions operate on the union of selected song ids plus selected card song ids.
- Card play: artist card play records artist played before replacing the queue; other card play shuffles card song ids and starts the first song.
- Folder open: folder search result opens the local page for that relative folder; folder context menu supports reveal and search directory.

## Layout And Style

- Page padding: `.search-page` target is `6px 24px 22px`; selection mode adds bottom command-bar space.
- Result stack: vertical gap is 18px.
- Filter tabs: horizontal pill row, 8px gap, 30px min height, label plus count, active tab is solid accent with white text.
- Loading state: inline 18px spinner plus `nowPlaying.loading`, matching Electron `search-loading-state`.
- Empty and no-result states: shared `empty-state` panel with only a strong headline, no tabs above it.
- Section header: 40px high, title 18px/700, actions on the right with 36px controls, 9px radius, subtle border, control surface fill.
- Artists: compact responsive card grid; cards are horizontal, min width 260px, 64px artwork, 14px content gap, 86px min height.
- Albums: 180px album tiles, 30px column gap, 26px row gap.
- Playlists and folders: use 180px grid-card rhythm, not horizontal search result cards.
- Songs: use playlist row layout with album visible.
- Empty states: use shared empty-state surface and strong headline only.
