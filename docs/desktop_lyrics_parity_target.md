# Desktop Lyrics Parity Target

Source of truth:

- Electron window: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/electron/desktop-lyrics-window.ts`
- Electron UI: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/DesktopLyricsApp.tsx`
- Electron styles: `/Users/luohaitian/Desktop/Projects/SMPlayerElectron/src/styles/desktop-lyrics.css`

Required target:

- Window: default bounds `760 x 148`, transparent, borderless, non-taskbar, always on top at screen-saver level, no shadow, non-resizable.
- Card: `margin: 8px`, `padding: 10px 18px 12px`, `border-radius: 8px`, transparent at rest.
- Layout: grid rows `meta / lyric / toolbar`, `row-gap: 6px`; meta at top, lyric centered, toolbar at bottom.
- Hover/focus card: border `rgba(255,255,255,0.22)` in night mode, `rgba(15,23,42,0.08)` in day mode; background alpha `opacity * 0.34` night, `opacity * 0.24` day; backdrop blur/saturate effect.
- Toolbar: visible only on hover/focus, centered, height `30px`, gap `3px`; buttons min width `26px`, height `26px`, horizontal padding `6px`, radius `5px`, icon size `16px`.
- Meta: visible only on hover/focus, font size `12px`, weight `650`, line height `1.3`, gap `10px`; day color `rgba(17,24,39,0.68)`, night color `rgba(255,255,255,0.7)`.
- Lyrics: one line only; font size from setting, weight `800`, line height `1.16`, text align center, no letter spacing, nowrap, ellipsis when static.
- Stroke: `0.7px` equivalent, stroke color transparent when setting is empty, text shadow `0 1px 2px` using stroke color at 50%.
- Overflow: scroll distance is content width minus box width; duration is `min(12, max(5, round(distance / 28) + 4))`; animation eases and pauses near the ends like Electron keyframes.
- Lock: window remains interactive for the unlock/settings buttons; drag is disabled; close button is hidden.
