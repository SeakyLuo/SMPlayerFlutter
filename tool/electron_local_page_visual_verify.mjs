import { spawn } from 'node:child_process'
import { createRequire } from 'node:module'
import { copyFile, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const flutterRoot = resolve(__dirname, '..')
const electronRoot = resolve(flutterRoot, '..', 'SMPlayerElectron')
const requireFromElectron = createRequire(join(electronRoot, 'package.json'))
const electronBinary = requireFromElectron('electron')
const viteBinary = join(electronRoot, 'node_modules', 'vite', 'bin', 'vite.js')
const width = Number(process.env.ELECTRON_LOCAL_VERIFY_WIDTH ?? 1280)
const height = Number(process.env.ELECTRON_LOCAL_VERIFY_HEIGHT ?? 820)
const brightness = process.env.ELECTRON_LOCAL_VERIFY_BRIGHTNESS === 'dark' ? 'dark' : 'light'
const output = resolve(
  flutterRoot,
  process.env.ELECTRON_LOCAL_VERIFY_OUTPUT ??
    `build/smplayer_electron_local_page_archive_${brightness}_${width}_verify.png`,
)
const geometryOutput = resolve(
  flutterRoot,
  process.env.ELECTRON_LOCAL_VERIFY_GEOMETRY_OUTPUT ?? output.replace(/\.png$/, '.geometry.json'),
)
const port = Number(process.env.ELECTRON_LOCAL_VERIFY_PORT ?? 5194)
const tempRoot = await mkdtemp(join(electronRoot, '.tmp-local-verify-'))

try {
  await writeHarness(tempRoot)
  const vite = spawn(process.execPath, [viteBinary, '--host', '127.0.0.1', '--port', String(port)], {
    cwd: tempRoot,
    env: {
      ...process.env,
      SMPLAYER_ELECTRON_ROOT: electronRoot,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  vite.stdout.on('data', (chunk) => process.stdout.write(chunk))
  vite.stderr.on('data', (chunk) => process.stderr.write(chunk))
  await waitForServer(port)
  await runElectronCapture(tempRoot)
  vite.kill('SIGTERM')
} finally {
  await rm(tempRoot, { recursive: true, force: true })
}

async function writeHarness(root) {
  await mkdir(join(root, 'src'), { recursive: true })
  await mkdir(join(root, 'public'), { recursive: true })
  await copyFile(join(electronRoot, 'public', 'app-icon.png'), join(root, 'public', 'app-icon.png'))
  await copyFile(join(electronRoot, 'public', 'colorful_no_bg.png'), join(root, 'public', 'colorful_no_bg.png'))
  await copyFile(join(electronRoot, 'public', 'folder.png'), join(root, 'public', 'folder.png'))
  await writeFile(
    join(root, 'index.html'),
    '<!doctype html><html><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>',
  )
  await writeFile(
    join(root, 'vite.config.mjs'),
    `import { defineConfig } from ${JSON.stringify(pathToFileURL(join(electronRoot, 'node_modules', 'vite', 'dist', 'node', 'index.js')).href)}
import react from ${JSON.stringify(pathToFileURL(join(electronRoot, 'node_modules', '@vitejs', 'plugin-react', 'dist', 'index.js')).href)}

export default defineConfig({
  plugins: [react()],
  resolve: {
    dedupe: ['react', 'react-dom', 'react-router-dom', 'zustand'],
  },
  server: {
    fs: {
      allow: [${JSON.stringify(root)}, ${JSON.stringify(electronRoot)}],
    },
  },
})
`,
  )
  await writeFile(join(root, 'src', 'main.tsx'), rendererHarness())
  await writeFile(join(root, 'capture-main.cjs'), electronCaptureMain())
}

function rendererHarness() {
  const electronSrc = join(electronRoot, 'src')
  return `import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from '${join(electronSrc, 'App.tsx')}'
import { AppRouter } from '${join(electronSrc, 'AppRouter.tsx')}'
import '${join(electronSrc, 'index.css')}'
import '${join(electronSrc, 'App.css')}'

const params = new URLSearchParams(window.location.search)
const brightness = params.get('brightness') === 'dark' ? 'dark' : 'light'
document.body.classList.toggle('night-mode', brightness === 'dark')
document.documentElement.classList.toggle('night-mode', brightness === 'dark')
window.location.hash = '/local'

const songs = [
  song(1, 'Intro Signal', 'River North', ['River North'], 'Archive Night', 'C:\\\\Music\\\\Collections\\\\Live\\\\Sessions\\\\Archive\\\\Intro.mp3', 92, false),
  song(2, 'Glass Horizon', 'Noon Section', ['Noon Section'], 'Archive Night', 'C:\\\\Music\\\\Collections\\\\Live\\\\Sessions\\\\Archive\\\\Glass Horizon.mp3', 184, true),
  song(3, 'North Pier', 'Noon Section', ['Noon Section'], 'Archive Night', 'C:\\\\Music\\\\Collections\\\\Live\\\\Sessions\\\\Archive\\\\North Pier.mp3', 226, false),
  song(4, 'Last Light', 'River North', ['River North'], 'Encore', 'C:\\\\Music\\\\Collections\\\\Live\\\\Sessions\\\\Archive\\\\Encore\\\\Last Light.mp3', 203, false),
]
const folders = [
  { id: 5, path: 'C:\\\\Music\\\\Collections', parentId: 0, criterion: 0 },
  { id: 6, path: 'C:\\\\Music\\\\Collections\\\\Live', parentId: 5, criterion: 0 },
  { id: 7, path: 'C:\\\\Music\\\\Collections\\\\Live\\\\Sessions', parentId: 6, criterion: 0 },
  { id: 8, path: 'C:\\\\Music\\\\Collections\\\\Live\\\\Sessions\\\\Archive', parentId: 7, criterion: 0 },
  { id: 10, path: 'C:\\\\Music\\\\Collections\\\\Live\\\\Sessions\\\\Archive\\\\Encore', parentId: 8, criterion: 0 },
]
const playlists = [
  { id: 9, name: 'Now Playing', priority: 0, songCount: 1, songIds: [9], sortCriterion: 'title', isBuiltIn: true },
  { id: 20, name: 'Favorites', priority: 1, songCount: 1, songIds: [2], sortCriterion: 'title', isBuiltIn: true },
  { id: 30, name: 'Road Tape', priority: 2, songCount: 0, songIds: [], sortCriterion: 'title', isBuiltIn: false },
]
const snapshot = {
  settings: {
    rootPath: 'C:\\\\Music',
    useFilenameNotMusicName: false,
    smartMultiArtistRecognition: true,
    showCount: true,
    themeColor: '#0078D7',
    nightMode: brightness === 'dark' ? 'on' : 'never',
    nightModeStartTime: '20:00',
    nightModeEndTime: '06:00',
    notificationSend: 'never',
    notificationDisplay: 'normal',
    showNotifications: false,
    autoLyrics: true,
    showLyricsInNotification: false,
    notificationLyricsSource: 'internet',
    playerLyricsSource: 'auto',
    saveLyricsImmediately: true,
    preserveInternetLyricsTimestamps: true,
    desktopLyricsEnabled: false,
    desktopLyricsLocked: false,
    desktopLyricsColor: '#4aa8ff',
    desktopLyricsStrokeColor: '#111111',
    desktopLyricsFontSize: 28,
    desktopLyricsFontFamily: 'system',
    desktopLyricsOpacity: 88,
    desktopLyricsBounds: '',
    mainWindowBounds: '',
    mainWindowMaximized: false,
    preferredLanguage: 'en-US',
    musicLibrarySort: 'title',
    albumsSort: 'default',
    searchArtistsCriterion: 'default',
    searchAlbumsCriterion: 'default',
    searchSongsCriterion: 'default',
    searchPlaylistsCriterion: 'default',
    searchFoldersCriterion: 'default',
    lastMusicIndex: -1,
    volume: 50,
    isMuted: false,
    mode: 'once',
    musicProgress: 0,
    autoPlay: false,
    shuffleAfterOneRound: true,
    saveMusicProgress: true,
    hideMultiSelectCommandBarAfterOperation: true,
    localViewMode: 'grid',
    quitOnClose: true,
    lastPage: '/local',
    lastPlaylistId: 0,
    lastReleaseNotesVersion: '3.0.2',
  },
  counts: { songs: 4, artists: 2, albums: 2, folders: 5 },
  songs,
  folders,
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  playlists,
  favorites: { playlistId: 20, songIds: [2], sortCriterion: 'title' },
  nowPlaying: { playlistId: 9, songIds: [9] },
  search: { lastQuery: '', recentSearches: [] },
}
const shell = {
  settings: snapshot.settings,
  counts: snapshot.counts,
  playlists: snapshot.playlists,
  favorites: snapshot.favorites,
  nowPlaying: snapshot.nowPlaying,
  search: snapshot.search,
}
const noop = () => {}
const asyncNoop = async () => undefined
window.smplayer = {
  getLibraryShell: async () => shell,
  getLibrarySongs: async () => songs,
  getLibraryFolders: async () => folders,
  getRecentSongs: async () => [],
  getRecentPlaylists: async () => [],
  getRecentAlbums: async () => [],
  getRecentArtists: async () => [],
  getSongArtworkSnapshots: async (songIds) => songIds.map((songId) => ({ songId, artworkUrl: '', sourceUrl: '', sourcePath: '', source: 'none' })),
  getPreferenceSettings: async () => ({ enabled: { songs: true, artists: true, albums: true, playlists: true, folders: true }, songs: [], artists: [], albums: [], playlists: [], folders: [], others: [] }),
  getAppInfo: async () => ({ platform: 'darwin', version: '0.0.0' }),
  getWindowFullScreen: async () => false,
  getWindowMiniMode: async () => false,
  shouldCheckStartupArtistSplits: async () => false,
  takePendingExternalCommands: async () => [],
  takePendingOpenFiles: async () => [],
  onExternalCommand: () => noop,
  onOpenFiles: () => noop,
  onGlobalMediaCommand: () => noop,
  onWindowStateChange: () => noop,
  onWindowFullScreenChange: () => noop,
  onWindowMiniModeChange: () => noop,
  onTrayCommand: () => noop,
  onDesktopLyricsCommand: () => noop,
  onScanLocalFolderProgress: () => noop,
  onMoveLocalItemsProgress: () => noop,
  setWindowControlButtonVisibility: noop,
  setWindowControlsLight: noop,
  setWindowFullScreen: asyncNoop,
  setWindowMiniMode: asyncNoop,
  startWindowDrag: asyncNoop,
  stopWindowDrag: asyncNoop,
  setTrayPlaybackState: noop,
  showTrackNotification: noop,
  updateDesktopLyricsState: asyncNoop,
  getLyrics: async () => ({ lines: [], synced: false, source: 'none' }),
  onMpvPlaybackEvent: () => noop,
  loadMpvPlaybackSong: asyncNoop,
  playMpvPlayback: asyncNoop,
  pauseMpvPlayback: asyncNoop,
  stopMpvPlayback: asyncNoop,
  seekMpvPlayback: asyncNoop,
  setMpvPlaybackVolume: asyncNoop,
  setMpvPlaybackMuted: asyncNoop,
  savePlaybackSettingsImmediate: asyncNoop,
  saveViewState: asyncNoop,
  replaceNowPlaying: asyncNoop,
  markSongPlayed: asyncNoop,
  updateSongDuration: asyncNoop,
  addSongsToPlaylist: asyncNoop,
  addSongToPlaylist: asyncNoop,
  createPlaylist: async (name, songIds = []) => ({ id: 99, name, priority: 3, songCount: songIds.length, songIds, sortCriterion: 'title', isBuiltIn: false }),
  pickLibraryRoot: async () => null,
  revealItemInFolder: asyncNoop,
  prepareScanLocalFolder: async () => ({ operationId: 'verify', progressMax: 0 }),
  scanLocalFolder: async () => ({ filesAdded: [], filesRemoved: [], filesMoved: [], artistSplitsApplied: [], artistSplitSuggestions: [], artistMergeSuggestions: [] }),
}

function song(id, title, artist, artists, album, path, duration, favorite) {
  return {
    id,
    path,
    mediaUrl: '',
    artworkUrl: '',
    title,
    artist,
    artists,
    album,
    duration,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-31T00:00:00',
    favorite,
    thumbnailPath: '',
  }
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <AppRouter>
      <App />
    </AppRouter>
  </StrictMode>,
)
`
}

function electronCaptureMain() {
  return `const { app, BrowserWindow } = require('electron')
const { writeFile, mkdir } = require('node:fs/promises')
const { dirname } = require('node:path')

const width = Number(process.env.ELECTRON_LOCAL_VERIFY_WIDTH)
const height = Number(process.env.ELECTRON_LOCAL_VERIFY_HEIGHT)
const brightness = process.env.ELECTRON_LOCAL_VERIFY_BRIGHTNESS
const hoverTarget = process.env.ELECTRON_LOCAL_VERIFY_HOVER_TARGET || ''
const port = Number(process.env.ELECTRON_LOCAL_VERIFY_PORT)
const output = process.env.ELECTRON_LOCAL_VERIFY_OUTPUT
const geometryOutput = process.env.ELECTRON_LOCAL_VERIFY_GEOMETRY_OUTPUT

app.whenReady().then(async () => {
  const win = new BrowserWindow({
    width,
    height,
    show: false,
    useContentSize: true,
    frame: false,
    backgroundColor: brightness === 'dark' ? '#101419' : '#f6f8fb',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: false,
    },
  })
  await win.loadURL('http://127.0.0.1:' + port + '/?brightness=' + brightness)
  await new Promise((resolve) => setTimeout(resolve, 1800))
  await win.webContents.executeJavaScript('(' + openArchiveFolder.toString() + ')()')
  await new Promise((resolve) => setTimeout(resolve, 600))
  if (hoverTarget) {
    const hoverRect = await win.webContents.executeJavaScript('(' + resolveHoverRect.toString() + ')(' + JSON.stringify(hoverTarget) + ')')
    if (!hoverRect) {
      throw new Error('Unknown hover target: ' + hoverTarget)
    }
    win.webContents.sendInputEvent({
      type: 'mouseMove',
      x: Math.round(hoverRect.left + hoverRect.width / 2),
      y: Math.round(hoverRect.top + hoverRect.height / 2),
    })
    await new Promise((resolve) => setTimeout(resolve, 350))
  }
  const geometry = await win.webContents.executeJavaScript('(' + collectGeometry.toString() + ')()')
  const image = (await win.webContents.capturePage()).resize({ width, height, quality: 'best' })
  await mkdir(dirname(output), { recursive: true })
  await writeFile(output, image.toPNG())
  await writeFile(geometryOutput, JSON.stringify(geometry, null, 2))
  await win.destroy()
  app.quit()
})

async function openArchiveFolder() {
  const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
  const findFolderCard = (name) => [...document.querySelectorAll('.local-folder-card')]
    .find((element) => element.textContent?.includes(name))
  for (const name of ['Collections', 'Live', 'Sessions', 'Archive']) {
    const deadline = Date.now() + 3000
    let card = findFolderCard(name)
    while (!card && Date.now() < deadline) {
      await wait(100)
      card = findFolderCard(name)
    }
    if (!card) {
      throw new Error('Unable to find local folder card: ' + name)
    }
    card.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }))
    await wait(180)
  }
}

function resolveHoverRect(target) {
  const rect = (element) => {
    if (!element) return null
    const value = element.getBoundingClientRect()
    return {
      left: value.left,
      top: value.top,
      width: value.width,
      height: value.height,
    }
  }
  if (target === 'folder' || target === 'compactFolder') {
    return rect([...document.querySelectorAll('.local-folder-card')].find((element) => element.textContent?.includes('Encore')))
  }
  if (target === 'song' || target === 'compactSong') {
    return rect(document.querySelector('.local-grid-song-card, .local-compact-song-row'))
  }
  return null
}

function collectGeometry() {
  const rect = (element) => {
    if (!element) return null
    const value = element.getBoundingClientRect()
    const round = (number) => Math.round(number * 100) / 100
    return {
      left: round(value.left),
      top: round(value.top),
      width: round(value.width),
      height: round(value.height),
      right: round(value.right),
      bottom: round(value.bottom),
    }
  }
  const opacity = (element) => {
    if (!element) return null
    return Number.parseFloat(window.getComputedStyle(element).opacity)
  }
  const textElement = (text) => [...document.querySelectorAll('*')].find((element) => element.textContent === text)
  const folderChainDropdownButtons = [...document.querySelectorAll('.folder-chain-item-dropdown-button')]
  return {
    viewport: { width: window.innerWidth, height: window.innerHeight, devicePixelRatio: window.devicePixelRatio },
    appShell: rect(document.querySelector('.app-shell')),
    workspace: rect(document.querySelector('.workspace')),
    workspaceHeader: rect(document.querySelector('.workspace-header, .appbar')),
    localPage: rect(document.querySelector('.local-page')),
    commandbar: rect(document.querySelector('.local-commandbar')),
    folderSection: rect(document.querySelector('.local-content-section')),
    songSection: rect(document.querySelectorAll('.local-content-section')[1]),
    folderGrid: rect(document.querySelector('.local-folder-grid')),
    songGrid: rect(document.querySelector('.local-song-grid')),
    firstFolderCard: rect(document.querySelector('.local-folder-card')),
    firstSongRowOrCard: rect(document.querySelector('.local-grid-song-card, .local-compact-song-row')),
    toolbarSummaryText: rect(textElement('1 folder · 3 songs')),
    encoreText: rect(textElement('Encore')),
    folderInfoText: rect(textElement('1 song')),
    compactFolderActions: rect(document.querySelector('.local-folder-list-actions')),
    compactFolderActionsOpacity: opacity(document.querySelector('.local-folder-list-actions')),
    glassHorizonText: rect(textElement('Glass Horizon')),
    noonSectionText: rect(textElement('Noon Section')),
    introText: rect(textElement('Intro Signal')),
    glassHorizonDurationText: rect(textElement('3:04')),
    hiddenFoldersButton: rect(document.querySelector('.hidden-folders-list-button')),
    folderChainDropdownCount: folderChainDropdownButtons.length,
    folderChainDropdownButtons: folderChainDropdownButtons.map(rect),
    bodyNightMode: document.body.classList.contains('night-mode'),
  }
}
`
}

async function runElectronCapture(root) {
  await mkdir(dirname(output), { recursive: true })
  await new Promise((resolveRun, rejectRun) => {
    const child = spawn(electronBinary, [join(root, 'capture-main.cjs')], {
      cwd: root,
      env: {
        ...process.env,
        ELECTRON_LOCAL_VERIFY_WIDTH: String(width),
        ELECTRON_LOCAL_VERIFY_HEIGHT: String(height),
        ELECTRON_LOCAL_VERIFY_BRIGHTNESS: brightness,
        ELECTRON_LOCAL_VERIFY_PORT: String(port),
        ELECTRON_LOCAL_VERIFY_OUTPUT: output,
        ELECTRON_LOCAL_VERIFY_GEOMETRY_OUTPUT: geometryOutput,
        ELECTRON_LOCAL_VERIFY_HOVER_TARGET: process.env.ELECTRON_LOCAL_VERIFY_HOVER_TARGET || '',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    })
    child.stdout.on('data', (chunk) => process.stdout.write(chunk))
    child.stderr.on('data', (chunk) => process.stderr.write(chunk))
    child.on('error', rejectRun)
    child.on('exit', (code) => {
      if (code === 0) {
        resolveRun()
      } else {
        rejectRun(new Error(`Electron capture failed with exit code ${code}`))
      }
    })
  })
}

async function waitForServer(serverPort) {
  const deadline = Date.now() + 30000
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`http://127.0.0.1:${serverPort}/`)
      if (response.ok) {
        return
      }
    } catch {}
    await new Promise((resolveWait) => setTimeout(resolveWait, 200))
  }
  throw new Error(`Timed out waiting for Vite on ${serverPort}`)
}
