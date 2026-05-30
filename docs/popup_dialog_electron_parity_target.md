# PopupDialog Electron Parity Target

Electron source of truth:

- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/components/PopupDialog.tsx`
- `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/song-dialog.css`

Flutter target:

- `/Users/luohaitian/Desktop/Projects/SMPlayerFlutter/lib/src/library/ui/popup_dialog.dart`

| Area | Electron rule | Flutter acceptance check |
| --- | --- | --- |
| Overlay | `.song-dialog-overlay` covers viewport, z-index layer, centered grid, `rgba(24,30,38,.24)`, blur 12. Night overlay is `rgba(4,8,13,.62)`. | `PopupDialog` fills the viewport, applies 12 blur, and uses `PopupDialogResolvedColors.overlay` for light/night. |
| Desktop shell size | `.song-dialog` is `width:min(780px, calc(100vw - 48px))`, `height:min(760px, calc(100vh - 48px))`, centered. | At `1200x900`, default dialog is `780x760`; at desktop sizes smaller than defaults it subtracts `48px`. |
| Desktop shell chrome | Border `rgba(185,195,210,.5)`, radius `12px`, background `rgba(250,252,255,.98)`, shadow `0 26 80 rgba(35,45,60,.28)`. | Light colors come from `PopupDialogResolvedColors.light`; dark shell uses dark extension values. |
| Layout rows | Electron default grid is `auto auto minmax(0,1fr)`; dialogs that do not use `afterNav` effectively render nav, optional after-nav, body, footer. | Flutter shell renders nav, optional `afterNav`, expanded child, optional footer in that order. |
| Class variants | Electron callers pass `className`, `navClassName`, and `overlayClassName`; shared CSS uses these to select tab/mobile behavior and dialog-specific rules. | Flutter now threads Electron class names through the matching callers and maps known dialog classes for mobile tab-grid vs flex behavior. |
| Desktop nav | `.song-dialog-tabs` padding is `22px 28px 18px`; close button sits at the right with `margin-left:auto`. | Flutter nav uses `EdgeInsets.fromLTRB(28,22,28,18)` and keeps close at the far right. |
| Close button | `.song-dialog-icon-button` is `42px` wide/min-width, close icon visible on desktop, back icon hidden. Generic button height is `40px`, radius `10px` in nav. | Flutter close button is `42x40`, radius `10`, icon size `18`, shown on desktop only. |
| Desktop drag strip | `.popup-dialog-window-drag-strip` is fixed top, left `0`, right `138px`, height `32px`; pointer down starts window drag. | Flutter adds an invisible desktop strip over the same region and calls existing window drag callbacks when available. |
| Toolbar drag | Electron starts window drag from nav background, but not from buttons, inputs, textareas, selects, or links. | Unconfirmed for Flutter; this pass does not claim toolbar-drag parity because Flutter hit testing needs separate runtime validation. |
| Mobile breakpoint | At `max-width:720px`, overlay aligns start/stretch; drag strip hidden. | At width `<=720`, Flutter dialog uses full viewport width/height and hides the desktop drag strip. |
| Mobile titlebar | `.popup-dialog-mobile-titlebar` is fixed top, right `138px`, height `32px`, display flex; contains a `40px` back button and app title text. | Flutter shows a `32px` top titlebar with a `40px` close/back button and `app.shell` label. |
| Mobile shell | At `max-width:720px`, `.song-dialog` is `100vw/100vh`, border radius `0`, border width `0`. | Flutter mobile dialog fills constraints, radius `0`, border omitted. |
| Mobile nav | Mobile `.song-dialog-tabs` padding is `calc(32px + 12px) 12px 10px`; close button in nav is hidden. | Flutter mobile nav padding is `44px 12px 10px` and the nav close button is not rendered. |
| Mobile tab layout | Electron turns default `.song-dialog-tabs` into three equal columns on mobile; release notes, preference, remote, artist split, and album-art-library dialogs override this back to flex. | Flutter expands `PopupDialogTab` children into equal mobile cells only for music/album tabbed dialogs; known flex-dialog class names keep regular nav layout. |
| Title text | `.popup-dialog-title-block h2` is 22px desktop, 18px mobile, ellipsized. | Dialog callers continue to own title widgets; mobile padding gives them the same available area. |
| Close stack | Electron registers each `PopupDialog` with `popupDialogStack`; back navigation closes the top popup before route navigation. | Flutter registers each `PopupDialog` in `closeTopPopupDialog()` and shell back calls it before route navigation. |
| Escape key | Electron routes close through the top popup stack from global navigation behavior. | Flutter `PopupDialog` closes itself on Escape only when it is the top registered dialog. |

Unconfirmed until runtime visual comparison:

- Exact native window dragging behavior in packaged macOS/Windows builds.
- Toolbar background dragging, excluding buttons and inputs.
- Pixel-level comparison of the mobile titlebar against Electron screenshots.
- Wheel/touch scroll containment details from Electron's DOM event listeners.
