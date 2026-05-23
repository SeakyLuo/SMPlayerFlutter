# MediaControl alignment target

This target tracks implementation gaps against the Electron player, not just raw colors.

## Functional gaps

- Compact player actions must match Electron compact behavior: mode/more controls stay in the right utility column, progress stays on the second row, and transport stays centered in its own column.
- Transport controls should not be pushed by title text or utility buttons. Flutter must use a three-column compact layout, not a single Row where `Expanded(track)` can move the controls.
- Play/pause should use the Fluent icon directly. Do not use fixed pixel offsets; fixed offsets scale badly between 56, 52, and 48 px buttons.

## Wide background target

- Electron wide day background is layered: white/accent diagonal wash, cover-color horizontal wash to 42%, and a solid `rgba(255,255,255,.82)` base.
- Electron wide night background is layered: subtle white/accent diagonal wash, cover-color horizontal wash to 46%, and `rgba(17,22,28,.9)` base.
- Flutter currently approximates this with `GlassContainer` plus multiple `DecoratedBox` layers. The next background pass should map each Electron layer one-to-one instead of tuning isolated alpha constants.

## Compact responsive target

- Electron compact top row is a grid-like layout:
  - Track column on the left.
  - Transport column centered.
  - Utility column on the right.
  - Progress row spans all columns.
- Electron `<=520px` compact dimensions:
  - Columns: `minmax(112px, 1fr) minmax(136px, 176px) 68px`.
  - Rows: `72px 28px`.
  - Padding: `9px 12px 11px`.
  - Transport gap: `16px`.
  - Primary button: `48px`, padding `12px`.
  - Utility buttons: `34px`, padding `5px`.
- Flutter compact should preserve those roles even when the local implementation intentionally keeps skip backgrounds at `40px`. The utility column is `72px` in Flutter narrow mode because two 34px Flutter controls overflow a strict 68px render box by 4px.

## Current intentional differences

- Skip buttons are `40px` instead of Electron `36px` because the requested target was “outer circular background +10%”.
- Day disabled primary remains white and hides the icon because that is the requested app behavior; Electron CSS would make all disabled transport buttons `rgba(255,255,255,.08)` with `opacity: .65`.
