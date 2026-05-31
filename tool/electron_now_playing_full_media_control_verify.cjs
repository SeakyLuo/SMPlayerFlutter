const { mkdir, writeFile } = require('node:fs/promises');
const { dirname, resolve } = require('node:path');
const { pathToFileURL } = require('node:url');

const { app, BrowserWindow } = require('electron');

app.disableHardwareAcceleration();

const electronRoot = '/Users/luohaitian/Desktop/Projects/SMPlayerElectron';
const flutterRoot = '/Users/luohaitian/Desktop/Projects/SMPlayerFlutter';
const outputDir = resolve(flutterRoot, 'build/now_playing_full_electron');
const outputJson = resolve(outputDir, 'media_control_footer_metrics.json');
const outputHtml = resolve(outputDir, 'media_control_footer_verify.html');
const widths = [500, 780, 1000, 1400];
const height = 760;

const indexCss = pathToFileURL(resolve(electronRoot, 'src/index.css')).href;
const appCss = pathToFileURL(resolve(electronRoot, 'src/App.css')).href;

const icon = (path) => `
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path d="${path}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path>
  </svg>
`;

const html = `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <link rel="stylesheet" href="${indexCss}">
  <link rel="stylesheet" href="${appCss}">
  <style>
    html, body, #root {
      width: 100%;
      height: 100%;
      margin: 0;
      overflow: hidden;
    }
    body {
      background: #eef3f8;
    }
    .verify-content {
      position: fixed;
      inset: 0;
      background:
        radial-gradient(circle at 18% 24%, rgba(91, 135, 182, 0.20), transparent 34%),
        linear-gradient(135deg, #d9e3ec, #f8fbfe);
    }
  </style>
</head>
<body>
  <div id="root">
    <div class="app-shell">
      <section
        class="now-playing-full-page is-day is-player-bar-raised"
        style="--now-playing-full-cover-rgb: 91, 135, 182;"
      >
        <div class="verify-content"></div>
        <footer
          class="player-bar now-playing-full-player-bar"
          style="--player-cover-rgb: 91, 135, 182;"
        >
          <button
            type="button"
            class="player-track now-playing-full-player-exit"
            aria-label="Exit immersive mode"
            data-key="exit"
          >
            <span class="player-artwork-shell">
              <span class="album-swatch" aria-hidden="true"></span>
              <span class="player-artwork-overlay" aria-hidden="true">
                ${icon('M8 3H3v5 M3 3l7 7 M16 3h5v5 M21 3l-7 7 M8 21H3v-5 M3 21l7-7 M16 21h5v-5 M21 21l-7-7')}
              </span>
            </span>
          </button>
          <div class="player-center">
            <div class="transport-row">
              <button class="transport-button skip" data-key="previous" type="button">
                ${icon('M15 6l-6 6 6 6 M7 6v12')}
              </button>
              <button class="transport-button primary" data-key="play" type="button">
                ${icon('M8 5v14 M16 5v14')}
              </button>
              <button class="transport-button skip" data-key="next" type="button">
                ${icon('M9 6l6 6-6 6 M17 6v12')}
              </button>
            </div>
            <div class="progress-row">
              <span data-key="elapsed">1:12</span>
              <input
                data-key="progress"
                class="media-slider"
                type="range"
                min="0"
                max="120"
                step="0.1"
                value="72"
                style="--range-progress: 60%;"
              >
              <span data-key="duration">2:00</span>
            </div>
          </div>
          <div class="player-utility">
            <div class="player-volume-row">
              <div class="player-compact-volume-action">
                <button type="button" data-key="compact-volume">
                  ${icon('M5 9v6h4l5 4V5L9 9H5z')}
                </button>
              </div>
              <button class="player-volume-toggle" type="button" data-key="volume">
                ${icon('M5 9v6h4l5 4V5L9 9H5z')}
              </button>
              <span class="volume-slider-wrap">
                <input
                  class="media-slider"
                  type="range"
                  min="0"
                  max="100"
                  value="60"
                  style="--range-progress: 60%; --volume-tooltip-left: 60%;"
                >
              </span>
              <button class="favorite-toggle" type="button" data-key="favorite">
                ${icon('M12 21s-7-4.35-9.2-8.58C.8 8.57 3.15 5 6.9 5c2.08 0 3.37 1.13 5.1 3 1.73-1.87 3.02-3 5.1-3 3.75 0 6.1 3.57 4.1 7.42C19 16.65 12 21 12 21z')}
              </button>
            </div>
            <div class="player-mode-row">
              <button class="player-mode-button" type="button" data-key="shuffle">
                ${icon('M4 17h5l-2-2 M9 17l-2 2 M4 7h6c2 0 3 1 3 3v4 M20 7h-5l2-2 M15 7l2 2')}
              </button>
              <button class="player-mode-button" type="button" data-key="repeat">
                ${icon('M4 7h11l-3-3 M15 7l-3 3 M20 17H9l3 3 M9 17l3-3')}
              </button>
              <button class="player-mode-button" type="button" data-key="repeat-one">
                ${icon('M4 7h11l-3-3 M15 7l-3 3 M20 17H9l3 3 M9 17l3-3 M12 9v6')}
              </button>
              <button class="player-compact-mode-button" type="button" data-key="mode">
                ${icon('M4 17h5l-2-2 M9 17l-2 2 M4 7h6c2 0 3 1 3 3v4 M20 7h-5l2-2 M15 7l2 2')}
              </button>
              <button type="button" data-key="more">
                ${icon('M5 12h.01 M12 12h.01 M19 12h.01')}
              </button>
            </div>
          </div>
        </footer>
      </section>
    </div>
  </div>
</body>
</html>`;

function rectScript() {
  return `
(() => {
  const by = (selector) => document.querySelector(selector)
  const rect = (selector) => {
    const element = by(selector)
    if (!element) return null
    const r = element.getBoundingClientRect()
    return {
      left: Number(r.left.toFixed(2)),
      top: Number(r.top.toFixed(2)),
      right: Number(r.right.toFixed(2)),
      bottom: Number(r.bottom.toFixed(2)),
      width: Number(r.width.toFixed(2)),
      height: Number(r.height.toFixed(2)),
    }
  }
  const style = (selector, property) => getComputedStyle(by(selector)).getPropertyValue(property)
  return {
    shellClass: by('.app-shell').className,
    playerBar: rect('.now-playing-full-player-bar'),
    exitButton: rect('[data-key="exit"]'),
    exitShell: rect('[data-key="exit"] .player-artwork-shell'),
    previous: rect('[data-key="previous"]'),
    play: rect('[data-key="play"]'),
    next: rect('[data-key="next"]'),
    mode: rect('[data-key="mode"]'),
    shuffle: rect('[data-key="shuffle"]'),
    repeat: rect('[data-key="repeat"]'),
    repeatOne: rect('[data-key="repeat-one"]'),
    more: rect('[data-key="more"]'),
    elapsed: rect('[data-key="elapsed"]'),
    progress: rect('[data-key="progress"]'),
    duration: rect('[data-key="duration"]'),
    playerBarGridColumns: style('.now-playing-full-player-bar', 'grid-template-columns'),
    playerBarGridRows: style('.now-playing-full-player-bar', 'grid-template-rows'),
    playerBarPadding: style('.now-playing-full-player-bar', 'padding'),
    playerBarColumnGap: style('.now-playing-full-player-bar', 'column-gap'),
    transportGap: style('.transport-row', 'gap'),
    progressGridColumns: style('.progress-row', 'grid-template-columns'),
    progressGap: style('.progress-row', 'gap'),
    progressPadding: style('.progress-row', 'padding'),
    modeRowGap:
      rect('[data-key="more"]') && rect('[data-key="mode"]')
        ? Number((rect('[data-key="more"]').left - rect('[data-key="mode"]').right).toFixed(2))
        : null,
  }
})()
`;
}

async function main() {
  await mkdir(outputDir, { recursive: true });
  await writeFile(outputHtml, html);

  const metrics = {};
  const win = new BrowserWindow({
    width: widths[0],
    height,
    x: -10000,
    y: -10000,
    show: true,
    backgroundColor: '#eef3f8',
    webPreferences: { backgroundThrottling: false },
  });
  win.webContents.on('did-finish-load', () => {
    console.log('[electron-media-control-verify] did-finish-load');
  });
  win.webContents.on('did-fail-load', (_event, code, description, url, isMainFrame) => {
    console.log(
      `[electron-media-control-verify] did-fail-load ${code} ${description} ${url} main=${isMainFrame}`,
    );
  });
  await win.loadFile(outputHtml);

  for (const width of widths) {
    console.log(`[electron-media-control-verify] measuring ${width}`);
    win.setSize(width, height);
    await win.webContents.executeJavaScript(`
      document.querySelector('.app-shell').classList.toggle('nav-minimal', ${width <= 800});
    `);
    await new Promise((resolve) => setTimeout(resolve, 250));
    metrics[String(width)] = await win.webContents.executeJavaScript(rectScript());
    const image = await win.webContents.capturePage();
    await writeFile(resolve(outputDir, `media_control_footer_${width}.png`), image.toPNG());
  }
  win.destroy();

  await writeFile(outputJson, `${JSON.stringify(metrics, null, 2)}\n`);
  console.log(`[electron-media-control-verify] wrote ${outputJson}`);
  app.quit();
}

app.once('ready', () => {
  main().catch((error) => {
    console.error(error);
    app.exit(1);
  });
});
