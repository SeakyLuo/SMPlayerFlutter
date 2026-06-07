import { spawn } from 'node:child_process'
import { createServer } from 'node:net'
import { createRequire } from 'node:module'
import { copyFile, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const flutterRoot = resolve(__dirname, '..')
const electronRoot = resolve(flutterRoot, '..', 'SMPlayerElectron')
const requireFromElectron = createRequire(join(electronRoot, 'package.json'))
const electronBinary = requireFromElectron('electron')
const viteBinary = join(electronRoot, 'node_modules', 'vite', 'bin', 'vite.js')
const port = await findAvailablePort(
  Number(process.env.ELECTRON_MUSIC_DIALOG_VERIFY_PORT ?? 5191),
)
const cases = [
  { mode: 'properties', brightness: 'light' },
  { mode: 'properties', brightness: 'dark' },
  { mode: 'lyrics', brightness: 'light' },
  { mode: 'lyrics', brightness: 'dark' },
  {
    mode: 'lyrics',
    brightness: 'light',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
  {
    mode: 'lyrics',
    brightness: 'dark',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
  { mode: 'lyrics-dirty-timed', brightness: 'light' },
  { mode: 'lyrics-dirty-timed', brightness: 'dark' },
  {
    mode: 'lyrics-dirty-timed',
    brightness: 'light',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
  {
    mode: 'lyrics-dirty-timed',
    brightness: 'dark',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
  { mode: 'lyrics-empty', brightness: 'light' },
  { mode: 'lyrics-empty', brightness: 'dark' },
  { mode: 'lyrics-loading', brightness: 'light' },
  { mode: 'lyrics-loading', brightness: 'dark' },
  { mode: 'lyrics-saving', brightness: 'light' },
  { mode: 'lyrics-saving', brightness: 'dark' },
  {
    mode: 'lyrics-saving',
    brightness: 'light',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
  {
    mode: 'lyrics-saving',
    brightness: 'dark',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
  { mode: 'album-art', brightness: 'light' },
  { mode: 'album-art-source-menu', brightness: 'light' },
  { mode: 'album-art-delete-confirm', brightness: 'light' },
  { mode: 'album-art-recommendation', brightness: 'light' },
  { mode: 'album-artwork', brightness: 'light' },
  { mode: 'album-artwork-source-menu', brightness: 'light' },
  { mode: 'album-artwork-delete-confirm', brightness: 'light' },
  { mode: 'album-artwork', brightness: 'dark' },
  {
    mode: 'album-artwork',
    brightness: 'light',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
  { mode: 'album-art-library-picker', brightness: 'light' },
  { mode: 'album-art-library-picker', brightness: 'dark' },
  { mode: 'album-art-library-picker-history', brightness: 'light' },
  { mode: 'album-art-library-picker-history', brightness: 'dark' },
  { mode: 'album-art-library-picker-empty', brightness: 'light' },
  {
    mode: 'album-art-library-picker-empty',
    brightness: 'light',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
  {
    mode: 'album-art-library-picker',
    brightness: 'light',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
  { mode: 'lyrics-discard-confirm', brightness: 'light' },
  { mode: 'lyrics-discard-confirm', brightness: 'dark' },
  {
    mode: 'lyrics-discard-confirm',
    brightness: 'light',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
  {
    mode: 'lyrics-discard-confirm',
    brightness: 'dark',
    viewport: 'mobile',
    width: 640,
    height: 820,
  },
]

const tempRoot = await mkdtemp(join(electronRoot, '.tmp-music-dialog-verify-'))

try {
  await writeHarness(tempRoot)
  const vite = spawn(
    process.execPath,
    [
      viteBinary,
      '--host',
      '127.0.0.1',
      '--port',
      String(port),
      '--strictPort',
    ],
    {
      cwd: tempRoot,
      env: {
        ...process.env,
        SMPLAYER_ELECTRON_ROOT: electronRoot,
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  )
  vite.stdout.on('data', (chunk) => process.stdout.write(chunk))
  vite.stderr.on('data', (chunk) => process.stderr.write(chunk))
  await waitForServer(port)

  for (const verifyCase of cases) {
    await runElectronCapture(tempRoot, verifyCase)
  }

  vite.kill('SIGTERM')
} finally {
  await rm(tempRoot, { recursive: true, force: true })
}

async function writeHarness(root) {
  await mkdir(join(root, 'src'), { recursive: true })
  await mkdir(join(root, 'public'), { recursive: true })
  await copyFile(join(electronRoot, 'public', 'app-icon.png'), join(root, 'public', 'app-icon.png'))
  await writeFile(
    join(root, 'index.html'),
    '<!doctype html><html><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>',
  )
  await writeFile(
    join(root, 'vite.config.mjs'),
    `import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  resolve: {
    dedupe: ['react', 'react-dom', 'zustand'],
  },
  server: {
    fs: {
      allow: [${JSON.stringify(root)}, ${JSON.stringify(electronRoot)}],
    },
  },
})
`,
  )
  await writeFile(join(root, 'src', 'main.tsx'), electronRendererHarness())
  await writeFile(join(root, 'capture-main.cjs'), electronCaptureMain())
}

async function findAvailablePort(startPort) {
  for (let candidate = startPort; candidate < startPort + 100; candidate += 1) {
    if (await canListen(candidate)) {
      return candidate
    }
  }
  throw new Error(`No available Vite port near ${startPort}`)
}

async function canListen(candidate) {
  return new Promise((resolveCanListen) => {
    const server = createServer()
    server.once('error', () => resolveCanListen(false))
    server.once('listening', () => {
      server.close(() => resolveCanListen(true))
    })
    server.listen(candidate, '127.0.0.1')
  })
}

function electronRendererHarness() {
  const electronSrc = join(electronRoot, 'src')
  return `import { createRoot } from 'react-dom/client'
import { MusicDialog } from '${join(electronSrc, 'components', 'MusicDialog.tsx')}'
import { AlbumArtworkDialog } from '${join(electronSrc, 'components', 'AlbumArtworkDialog.tsx')}'
import { AlbumArtLibraryPickerDialog } from '${join(electronSrc, 'components', 'AlbumArtLibraryPickerDialog.tsx')}'
import { DialogHost } from '${join(electronSrc, 'components', 'DialogHost.tsx')}'
import { applyThemeColor } from '${join(electronSrc, 'appModel.ts')}'
import { useLibraryStore } from '${join(electronSrc, 'state', 'useLibraryStore.ts')}'
import '${join(electronSrc, 'index.css')}'
import '${join(electronSrc, 'App.css')}'

const params = new URLSearchParams(window.location.search)
const mode = params.get('mode') || 'properties'
const brightness = params.get('brightness') === 'dark' ? 'dark' : 'light'
document.body.classList.toggle('night-mode', brightness === 'dark')
document.documentElement.classList.toggle('night-mode', brightness === 'dark')
applyThemeColor('#0078D7')

const currentSong = {
  id: 1,
  path: '/Users/me/Music/Current Song.mp3',
  mediaUrl: '',
  artworkUrl: '',
  title: 'Current Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 245,
  playCount: 12,
  lyricsOffsetMs: 0,
  dateAdded: '2026-06-01T00:00:00Z',
  favorite: false,
}
const matchSong = {
  id: 2,
  path: '/Users/me/Music/Match Song.mp3',
  mediaUrl: '',
  artworkUrl: '',
  title: 'Match Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 4,
  lyricsOffsetMs: 0,
  dateAdded: '2026-06-01T00:00:00Z',
  favorite: false,
}

useLibraryStore.setState({
  snapshot: {
    songs: [currentSong, matchSong],
    playlists: [],
    favoritePlaylistId: null,
    search: {
      recentSearches:
        mode === 'album-art-library-picker-history'
          ? [
              {
                id: 7,
                query: 'History Query',
                type: 'sidebar',
                searchedAt: '2026-06-05T00:00:00Z',
              },
            ]
          : [],
    },
    hasLibrary: true,
    sortCriterion: 'title',
    albumsSort: 'default',
    databasePath: '',
  },
})

const t = (key, params = {}) => {
  let value = messages[key] ?? key
  for (const [name, replacement] of Object.entries(params)) {
    value = value.replaceAll('{' + name + '}', String(replacement))
  }
  return value
}

window.smplayer = {
  getSongProperties: async () => ({
    songId: 1,
    path: '/Users/me/Music/Current Song.mp3',
    title: 'Current Song',
    subtitle: 'Live session',
    artist: 'Artist, Guest',
    artists: ['Artist', 'Guest'],
    album: 'Album',
    albumArtist: 'Artist',
    publisher: 'SM Records',
    trackNumber: 3,
    year: 2026,
    genre: 'Pop, Rock',
    composers: 'Composer A, Composer B',
    duration: 245,
    bitrate: 320,
    fileSize: 7340032,
    dateCreated: '2026-06-01T08:00:00Z',
    dateModified: '2026-06-05T09:30:00Z',
    fileType: 'MP3',
    playCount: 12,
  }),
  getLyrics: async () => {
    if (mode === 'lyrics-loading') {
      return new Promise(() => {})
    }
    if (mode === 'lyrics-empty') {
      return {
        source: 'none',
        isSynced: false,
        rawText: '',
        lines: [],
      }
    }
    return {
      source: 'lrcFile',
      isSynced: true,
      rawText: '[00:01.00]First line\\n[00:04.00]Second line',
      lines: [
        { id: 0, timestampMs: 1000, text: 'First line' },
        { id: 1, timestampMs: 4000, text: 'Second line' },
      ],
    }
  },
  getSongArtworkSnapshot: async () => ({
    songId: 1,
    artworkUrl: '',
    sourceUrl: '',
    sourcePath: '',
    source: 'none',
  }),
  getSongArtworkSnapshots: async (songIds) => songIds.map((songId) => {
    const currentMissing = mode === 'album-art-recommendation' && songId === 1
    return {
      songId,
      artworkUrl: currentMissing ? '' : '/app-icon.png',
      sourceUrl: currentMissing ? '' : '/app-icon.png',
      sourcePath: currentMissing ? '' : '/app-icon.png',
      source: currentMissing ? 'none' : 'cached',
    }
  }),
  updateSongProperties: async () => {},
  updateSongPlayCount: async () => {},
  saveSongLyrics: async () => {
    if (mode === 'lyrics-saving') {
      return new Promise(() => {})
    }
  },
  saveSongArtwork: async () => {},
  deleteSongArtwork: async () => {},
  openLyricsSearchInBrowser: async () => true,
  importLyrics: async () => ({ canceled: true }),
  pickSongArtworkSource: async () => ({ canceled: true }),
  pickAlbumArtworkSource: async () => ({ canceled: true }),
  saveAlbumArtwork: async () => {},
  deleteAlbumArtwork: async () => {},
  startWindowDrag: async () => {},
  stopWindowDrag: async () => {},
}

function VerifyPage() {
  return (
    <div
      className="app-shell"
      style={{
        display: 'block',
        height: '100vh',
        background: brightness === 'dark' ? '#05090f' : '#eef3f8',
      }}
    >
      {mode === 'album-artwork' || mode === 'album-artwork-source-menu' || mode === 'album-artwork-delete-confirm' ? (
        <AlbumArtworkDialog
          albumName="Album"
          artworkUrl="/app-icon.png"
          songId={1}
          t={t}
          onClose={() => {}}
          onSaved={() => {}}
        />
      ) : mode === 'album-art-library-picker' || mode === 'album-art-library-picker-history' || mode === 'album-art-library-picker-empty' ? (
        <AlbumArtLibraryPickerDialog
          albumName="Album"
          currentSong={currentSong}
          songs={mode === 'album-art-library-picker-empty' ? [currentSong] : [currentSong, matchSong]}
          t={t}
          onApply={() => {}}
          onClose={() => {}}
        />
      ) : (
        <MusicDialog
          song={currentSong}
          mode={
            mode === 'lyrics-discard-confirm' || mode === 'lyrics-loading' || mode === 'lyrics-empty' || mode === 'lyrics-dirty-timed' || mode === 'lyrics-saving'
                ? 'lyrics'
                : mode === 'album-art-recommendation' || mode === 'album-art-source-menu' || mode === 'album-art-delete-confirm'
                  ? 'album-art'
                  : mode
          }
          t={t}
          currentTrackId={1}
          isPlaying={mode === 'properties'}
          queueSongIds={[1, 2]}
          onClose={() => {}}
          onTogglePlayPause={() => {}}
          onPlayTrack={() => {}}
        />
      )}
      <DialogHost t={t} />
    </div>
  )
}

createRoot(document.getElementById('root')).render(<VerifyPage />)

const messages = {
  'common.add': 'Add',
  'common.album': 'Album',
  'common.artist': 'Artist',
  'common.artistSeparator': ' / ',
  'common.artistUnknown': 'Unknown Artist',
  'common.cancel': 'Cancel',
  'common.clear': 'Clear',
  'common.close': 'Close',
  'common.comma': ', ',
  'common.confirm': 'Confirm',
  'common.duration': 'Duration',
  'common.import': 'Import',
  'common.playCount': 'Play Count',
  'common.reset': 'Reset',
  'common.search': 'Search',
  'common.yes': 'Yes',
  'context.pause': 'Pause',
  'context.play': 'Play',
  'context.seeAlbumArt': 'See Album Art',
  'context.seeLyrics': 'See Lyrics',
  'context.seeMusicInfo': 'Music Info',
  'lyrics.title': 'Lyrics',
  'nowPlaying.loading': 'Loading',
  'nowPlaying.noLyrics': 'No lyrics found',
  'playlists.delete': 'Delete',
  'playlists.removeSelected': 'Remove',
  'settings.save': 'Save',
  'song.albumArtist': 'Album Artist',
  'song.albumArt': 'Album Art',
  'song.albumArtDeleted': 'Album art deleted',
  'song.albumArtRecommendationPrefix': 'Smart match: use {artist}\\'s ',
  'song.albumArtRecommendationSuffix': ' as the cover',
  'song.albumArtRecommendationTitle': '"{title}"',
  'song.albumArtUpdated': 'Album art updated',
  'song.bitrate': 'Bitrate',
  'song.changeArtwork': 'Change Artwork',
  'song.chooseArtworkFromLibrary': 'Choose from library',
  'song.chooseArtworkFromLocal': 'Choose local file',
  'song.clearPlayCount': 'Clear',
  'song.composers': 'Composers',
  'song.dateCreated': 'Date Created',
  'song.dateModified': 'Date Modified',
  'song.discardChanges': 'Discard Changes',
  'song.discardLyricsConfirm': 'Discard unsaved lyrics changes?',
  'song.fileSize': 'File Size',
  'song.fileType': 'File Type',
  'song.genre': 'Genre',
  'song.getLyricsFailed': 'Failed to get lyrics. Please try again later.',
  'song.importLyricsFailed': 'Failed to import lyrics.',
  'song.lyricsReset': 'Lyrics reset',
  'song.lyricsUpdated': 'The lyrics of "{title}" have been updated!',
  'song.lyricsUpdatedAndRefreshed': 'The lyrics of "{savedTitle}" have been updated. Now showing the lyrics of "{currentTitle}".',
  'song.noAlbumArt': 'No album art',
  'song.noLibraryArtwork': 'No available album art in the library',
  'song.nothingChanged': 'No changes were detected.',
  'song.openBrowserSuccessful': 'Browser opened.',
  'song.pendingSaveLyrics': 'The lyrics of "{title}" have been changed but not saved.',
  'song.processingRequest': 'Processing',
  'song.propertiesReset': 'Properties reset',
  'song.propertiesUpdated': 'Properties updated',
  'song.publisher': 'Publisher',
  'song.removeAlbumArt': 'Remove {title} art?',
  'song.searchLibraryArtwork': 'Search songs, artists, or albums',
  'song.searchLyricsFailed': 'No matching lyrics found.',
  'song.saveImmediately': 'Save Immediately',
  'song.showInExplorer': 'Show in Explorer',
  'song.showLyricsTimestamps': 'Show timestamps',
  'song.subtitle': 'Subtitle',
  'song.trackNumber': 'Track Number',
  'song.updateFailed': 'Update failed',
  'song.useSelectedArtwork': 'Use this cover',
  'song.year': 'Year',
  'sidebar.recentSearches': 'Recent searches',
  'sidebar.removeRecentSearch': 'Remove {query}',
  'table.title': 'Title',
}
`
}

function electronCaptureMain() {
  return `const { app, BrowserWindow } = require('electron')
const { writeFile } = require('node:fs/promises')
const { join } = require('node:path')
const { tmpdir } = require('node:os')

const width = Number(process.env.ELECTRON_MUSIC_DIALOG_VERIFY_WIDTH ?? 1200)
const height = Number(process.env.ELECTRON_MUSIC_DIALOG_VERIFY_HEIGHT ?? 900)
const mode = process.env.ELECTRON_MUSIC_DIALOG_VERIFY_MODE
const brightness = process.env.ELECTRON_MUSIC_DIALOG_VERIFY_BRIGHTNESS
const viewport = process.env.ELECTRON_MUSIC_DIALOG_VERIFY_VIEWPORT || ''
const port = Number(process.env.ELECTRON_MUSIC_DIALOG_VERIFY_PORT)

async function main() {
app.commandLine.appendSwitch('disable-gpu')
app.commandLine.appendSwitch('force-device-scale-factor', '1')
await app.whenReady()
const win = new BrowserWindow({
  show: false,
  width,
  height,
  frame: false,
  useContentSize: true,
  webPreferences: {
    contextIsolation: false,
    nodeIntegration: false,
  },
})
win.webContents.on('console-message', (_event, level, message) => {
  console.log('[renderer:' + level + '] ' + message)
})
win.webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL) => {
  console.error('[renderer:did-fail-load] ' + errorCode + ' ' + errorDescription + ' ' + validatedURL)
})
const targetUrl = 'http://127.0.0.1:' + port + '/?mode=' + encodeURIComponent(mode) + '&brightness=' + brightness
console.log('Loading ' + targetUrl)
await Promise.race([
  win.loadURL(targetUrl),
  new Promise((_resolve, reject) => setTimeout(() => reject(new Error('loadURL timeout')), 15000)),
])
await new Promise((resolve) => setTimeout(resolve, 1400))
	if (mode === 'lyrics-discard-confirm') {
	  await win.webContents.executeJavaScript("(() => { const textarea = document.querySelector('.song-dialog textarea'); const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set; setter.call(textarea, 'Dirty lyrics'); textarea.dispatchEvent(new Event('input', { bubbles: true })); document.querySelector('.song-dialog-tabs .song-dialog-icon-button').click(); })()")
	  await new Promise((resolve) => setTimeout(resolve, 400))
	}
	if (mode === 'lyrics-dirty-timed') {
	  await win.webContents.executeJavaScript("(() => { const textarea = document.querySelector('.song-dialog textarea'); const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set; setter.call(textarea, '[00:01.00]First line edited\\\\n[00:04.00]Second line'); textarea.dispatchEvent(new Event('input', { bubbles: true })); })()")
	  await new Promise((resolve) => setTimeout(resolve, 400))
	}
	if (mode === 'lyrics-saving') {
	  await win.webContents.executeJavaScript("(() => { const textarea = document.querySelector('.song-dialog textarea'); const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set; setter.call(textarea, '[00:01.00]First line saving\\\\n[00:04.00]Second line'); textarea.dispatchEvent(new Event('input', { bubbles: true })); const saveButton = Array.from(document.querySelectorAll('.song-dialog-commandbar button')).find((button) => button.textContent?.includes('Save')); saveButton?.click(); })()")
	  await new Promise((resolve) => setTimeout(resolve, 400))
	}
if (mode === 'album-art-delete-confirm' || mode === 'album-artwork-delete-confirm') {
  await win.webContents.executeJavaScript("(() => { document.querySelector('.DeleteAlbumArtButton')?.click(); })()")
  await new Promise((resolve) => setTimeout(resolve, 400))
}
if (mode === 'album-art-source-menu' || mode === 'album-artwork-source-menu') {
  await win.webContents.executeJavaScript("(() => { document.querySelector('.ChangeAlbumArtButton')?.click(); })()")
  await new Promise((resolve) => setTimeout(resolve, 400))
}
if (mode === 'album-art-library-picker-history') {
  await win.webContents.executeJavaScript("(() => { const input = document.querySelector('#album-art-library-search'); input?.focus(); input?.dispatchEvent(new FocusEvent('focusin', { bubbles: true })); })()")
  await new Promise((resolve) => setTimeout(resolve, 400))
}
const dialogStateScript = "(() => { const fallback = document.querySelector('.album-art-control-fallback'); const recommendation = document.querySelector('.album-art-recommendation'); const artworkImage = document.querySelector('img.album-art-control'); const defaultArtworkLogo = document.querySelector('.default-album-artwork-logo'); const rectOf = (element) => { if (!element) return null; const rect = element.getBoundingClientRect(); return { x: rect.x, y: rect.y, width: rect.width, height: rect.height }; }; const styleFor = (element) => { if (!element) return null; const style = getComputedStyle(element); return { color: style.color, backgroundColor: style.backgroundColor, borderColor: style.borderColor, borderRadius: style.borderRadius, boxShadow: style.boxShadow, display: style.display, fontFamily: style.fontFamily, fontSize: style.fontSize, fontWeight: style.fontWeight, height: style.height, minWidth: style.minWidth, objectFit: style.objectFit, overflow: style.overflow, paddingLeft: style.paddingLeft, paddingRight: style.paddingRight, textOverflow: style.textOverflow, whiteSpace: style.whiteSpace, width: style.width, rect: rectOf(element) }; }; const styleOf = (selector) => styleFor(document.querySelector(selector)); const recommendationSpans = Array.from(document.querySelectorAll('.album-art-recommendation span')).map((span) => ({ text: span.textContent ?? '', className: span.className, style: styleFor(span) })); const propertyRows = Array.from(document.querySelectorAll('.song-dialog-property-row')).map((row) => { const label = row.querySelector('.song-dialog-property-label'); const control = row.querySelector('.song-dialog-property-control'); return { label: label?.textContent ?? '', row: rectOf(row), labelRect: rectOf(label), controlRect: rectOf(control) }; }); const commandBarButtons = Array.from(document.querySelectorAll('.song-dialog-commandbar .uwp-commandbar-button')).map((button) => ({ text: button.textContent ?? '', className: button.className, style: styleFor(button) })); const menuFlyoutButtons = Array.from(document.querySelectorAll('.library-context-menu button')).map((button) => ({ text: button.textContent ?? '', className: button.className, style: styleFor(button) })); const pickerChoices = Array.from(document.querySelectorAll('.album-art-library-picker-source-item')).map((choice) => ({ text: choice.textContent ?? '', className: choice.className, rect: rectOf(choice), style: styleFor(choice) })); const pickerFooterButtons = Array.from(document.querySelectorAll('.album-art-library-picker-footer button')).map((button) => ({ text: button.textContent ?? '', className: button.className, style: styleFor(button) })); const searchHistoryItems = Array.from(document.querySelectorAll('.search-history-item')).map((item) => ({ text: item.textContent ?? '', className: item.className, style: styleFor(item) })); const artworkWarningButtons = Array.from(document.querySelectorAll('.RemoveAlbumArtWarningPanel button')).map((button) => ({ text: button.textContent ?? '', className: button.className, style: styleFor(button) })); return { mode: " + JSON.stringify(mode) + ", fallbackText: fallback?.innerText ?? '', fallbackClassName: fallback?.className ?? '', hasArtworkImage: Boolean(artworkImage), artworkImageComplete: artworkImage?.complete ?? false, artworkNaturalWidth: artworkImage?.naturalWidth ?? 0, artworkNaturalHeight: artworkImage?.naturalHeight ?? 0, defaultArtworkLogoInfo: defaultArtworkLogo ? { naturalWidth: defaultArtworkLogo.naturalWidth, naturalHeight: defaultArtworkLogo.naturalHeight, clientWidth: defaultArtworkLogo.clientWidth, clientHeight: defaultArtworkLogo.clientHeight, offsetWidth: defaultArtworkLogo.offsetWidth, offsetHeight: defaultArtworkLogo.offsetHeight, rect: rectOf(defaultArtworkLogo) } : null, hasRecommendation: Boolean(recommendation), recommendationText: recommendation?.innerText ?? '', recommendationSpans, propertyRows, commandBarButtons, menuFlyoutButtons, pickerChoices, pickerFooterButtons, searchHistoryItems, artworkWarningButtons, styles: { dialog: styleOf('.song-dialog'), commandbar: styleOf('.song-dialog-commandbar'), saveProgress: styleOf('.SaveProgress'), body: styleOf('.song-dialog-body'), propertyList: styleOf('.song-dialog-property-list'), label: styleOf('.song-dialog-property-label'), input: styleOf('.song-dialog input:not(:disabled)'), disabledInput: styleOf('.song-dialog input:disabled'), clearPlayCountButton: styleOf('.ClearPlayCountButton'), addArtistButton: styleOf('.AddArtistButton'), removeArtistButton: styleOf('.RemoveArtistButton'), closeButton: styleOf('.song-dialog-tabs .song-dialog-icon-button'), commandBarButton: styleOf('.song-dialog-commandbar .uwp-commandbar-button:not(.song-dialog-primary-button)'), primaryButton: styleOf('.song-dialog-primary-button'), activeTab: styleOf('.song-dialog-tabs button.is-active'), inactiveTab: styleOf('.song-dialog-tabs button:not(.is-active):not(.song-dialog-icon-button)'), textarea: styleOf('.song-dialog textarea'), lyricsTimestampToggle: styleOf('.song-dialog-lyrics-timestamp-toggle'), menuFlyout: styleOf('.library-context-menu'), menuFlyoutLocalItem: styleOf('.library-context-menu button:nth-of-type(1)'), menuFlyoutLibraryItem: styleOf('.library-context-menu button:nth-of-type(2)'), artworkImage: styleOf('img.album-art-control'), artworkFallback: styleOf('.album-art-control-fallback'), defaultArtworkRoot: styleOf('.default-album-artwork'), defaultArtworkLogo: styleOf('.default-album-artwork-logo'), albumArtRecommendation: styleOf('.album-art-recommendation'), albumArtRecommendationButton: styleOf('.album-art-recommendation-button'), albumArtRecommendationPreview: styleOf('.album-art-recommendation-preview'), albumArtDeleteConfirm: styleOf('.RemoveAlbumArtWarningPanel'), albumArtDeleteConfirmText: styleOf('.RemoveAlbumArtWarningTextBlock'), pickerNav: styleOf('.album-art-library-picker-nav'), pickerTitleBlock: styleOf('.album-art-library-picker-nav .popup-dialog-title-block'), pickerTitle: styleOf('.album-art-library-picker-nav h2'), pickerBody: styleOf('.album-art-library-picker'), pickerSearchShell: styleOf('.album-art-library-picker-search-shell'), pickerSearchForm: styleOf('.album-art-library-picker-search-shell .search-form'), pickerSearchInput: styleOf('#album-art-library-search'), pickerSearchCommitButton: styleOf('.album-art-library-picker-search-shell .search-commit-button'), pickerSearchHistoryPanel: styleOf('.search-history-panel'), pickerSearchHistoryHeader: styleOf('.search-history-header'), pickerSearchHistorySelect: styleOf('.search-history-select'), pickerSearchHistoryRemove: styleOf('.search-history-remove'), pickerContent: styleOf('.album-art-library-picker-content'), pickerListFrame: styleOf('.album-art-library-picker-list-frame'), pickerMessage: styleOf('.album-art-library-picker-message'), pickerChoice: styleOf('.album-art-library-picker-source-item'), pickerChoiceArtwork: styleOf('.album-art-library-picker-list .album-art-library-picker-artwork'), pickerChoiceTitle: styleOf('.album-art-library-picker-list .album-art-library-picker-copy strong'), pickerPreview: styleOf('.album-art-library-picker-preview'), pickerPreviewArtwork: styleOf('.album-art-library-picker-preview .album-art-control'), pickerPreviewTitle: styleOf('.album-art-library-picker-preview strong'), pickerFooter: styleOf('.album-art-library-picker-footer'), inputDialog: styleOf('.input-dialog') } }; })()"
const dialogState = await win.webContents.executeJavaScript(dialogStateScript)
console.log('Electron MusicDialog DOM state: ' + JSON.stringify(dialogState))
const image = (await win.webContents.capturePage()).resize({ width, height, quality: 'best' })
const file = join(tmpdir(), 'electron_music_dialog_' + mode.replace(/[^a-z0-9]+/gi, '_') + (viewport ? '_' + viewport : '') + '_' + brightness + '.png')
await writeFile(file, image.toPNG())
console.log('Electron MusicDialog screenshot: ' + file)
await app.quit()
}

main().catch((error) => {
  console.error(error)
  app.quit().finally(() => process.exit(1))
})
`
}

async function waitForServer(serverPort) {
  const deadline = Date.now() + 30000
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`http://127.0.0.1:${serverPort}`)
      if (response.ok) {
        return
      }
    } catch {
      // Retry until Vite has finished starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 250))
  }
  throw new Error(`Vite server did not start on ${serverPort}`)
}

async function runElectronCapture(root, verifyCase) {
  await new Promise((resolvePromise, reject) => {
    const child = spawn(electronBinary, [join(root, 'capture-main.cjs')], {
      cwd: root,
      env: {
        ...process.env,
        ELECTRON_MUSIC_DIALOG_VERIFY_MODE: verifyCase.mode,
        ELECTRON_MUSIC_DIALOG_VERIFY_BRIGHTNESS: verifyCase.brightness,
        ELECTRON_MUSIC_DIALOG_VERIFY_VIEWPORT: verifyCase.viewport ?? '',
        ELECTRON_MUSIC_DIALOG_VERIFY_WIDTH: String(verifyCase.width ?? 1200),
        ELECTRON_MUSIC_DIALOG_VERIFY_HEIGHT: String(verifyCase.height ?? 900),
        ELECTRON_MUSIC_DIALOG_VERIFY_PORT: String(port),
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    })
    const timeout = setTimeout(() => {
      child.kill('SIGKILL')
      reject(new Error('electron capture timed out'))
    }, 30000)
    let output = ''
    child.stdout.on('data', (chunk) => {
      output += chunk
      process.stdout.write(chunk)
    })
    child.stderr.on('data', (chunk) => process.stderr.write(chunk))
    child.on('error', reject)
    child.on('exit', (code) => {
      clearTimeout(timeout)
      if (code === 0) {
        resolvePromise()
      } else {
        reject(new Error(`electron capture exited with ${code}\\n${output}`))
      }
    })
  })
}
