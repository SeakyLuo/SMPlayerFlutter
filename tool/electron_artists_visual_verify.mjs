import { spawn } from 'node:child_process'
import { createRequire } from 'node:module'
import { copyFile, mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const flutterRoot = resolve(__dirname, '..')
const electronRoot = resolve(flutterRoot, '..', 'SMPlayerElectron')
const requireFromElectron = createRequire(join(electronRoot, 'package.json'))
const electronBinary = requireFromElectron('electron')
const viteBinary = join(electronRoot, 'node_modules', 'vite', 'bin', 'vite.js')
const port = Number(process.env.ELECTRON_ARTISTS_VERIFY_PORT ?? 5187)
const cases = [
  { width: 1200, height: 800, brightness: 'light' },
  { width: 1200, height: 800, brightness: 'dark' },
  { width: 860, height: 800, brightness: 'light' },
  { width: 700, height: 900, brightness: 'light' },
  { width: 700, height: 900, brightness: 'light', navMinimal: true },
]

const tempRoot = await mkdtemp(join(electronRoot, '.tmp-artists-verify-'))

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
  await writeFile(join(root, 'src', 'main.tsx'), electronRendererHarness())
  await writeFile(join(root, 'capture-main.cjs'), electronCaptureMain())
}

function electronRendererHarness() {
  const electronSrc = join(electronRoot, 'src')
  return `import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { AppRouter } from '${join(electronSrc, 'AppRouter.tsx')}'
import { ArtistsPage } from '${join(electronSrc, 'pages', 'ArtistsPage.tsx')}'
import { usePageSelectionStore } from '${join(electronSrc, 'state', 'usePageSelectionStore.ts')}'
import { usePreferenceStore } from '${join(electronSrc, 'state', 'usePreferenceStore.ts')}'
import '${join(electronSrc, 'index.css')}'
import '${join(electronSrc, 'App.css')}'

window.smplayer = {
  getSongArtworkSnapshots: async (songIds) => songIds.map((songId) => ({
    songId,
    artworkUrl: '',
    sourceUrl: '',
    sourcePath: '',
    source: 'none',
  })),
}

const params = new URLSearchParams(window.location.search)
const brightness = params.get('brightness') === 'dark' ? 'dark' : 'light'
const navMinimal = params.get('navMinimal') === '1'
document.body.classList.toggle('night-mode', brightness === 'dark')
document.documentElement.classList.toggle('night-mode', brightness === 'dark')

usePreferenceStore.setState({
  snapshot: {
    enabled: {
      songs: true,
      artists: true,
      albums: true,
      playlists: true,
      folders: true,
    },
    songs: [],
    artists: [],
    albums: [],
    playlists: [],
    folders: [],
    others: [],
  },
})
usePageSelectionStore.setState({ states: {} })

const messages = {
  'artists.albumSummary': '{songs} songs, {duration}',
  'artists.artistSummary': '{albums} albums, {songs} songs',
  'artists.emptyCopy': 'No artists yet.',
  'artists.locateArtist': 'Locate Artist',
  'artists.searchArtistsPlaceholder': 'Search artists',
  'artists.selectArtist': 'Select an artist',
  'albums.addSelectedTo': 'Add To',
  'albums.clearSelection': 'Clear Selection',
  'albums.playSelected': 'Play Selected',
  'albums.reverseSelection': 'Reverse Selection',
  'albums.selectAll': 'Select All',
  'albums.selectedCount': '{count} selected',
  'collection.artistNotFound': 'Artist not found',
  'collection.noArtists': 'No artists',
  'common.albumUnknown': 'Unknown Album',
  'common.artist': 'Artist',
  'common.artistSeparator': ' / ',
  'common.artists': 'Artists',
  'common.artistUnknown': 'Unknown Artist',
  'common.cancel': 'Cancel',
  'common.clear': 'Clear',
  'common.close': 'Close',
  'common.confirm': 'Confirm',
  'common.favorite': 'Favorite',
  'common.import': 'Import',
  'common.multiSelect': 'Multi Select',
  'common.myFavorites': 'My Favorites',
  'common.nowPlaying': 'Now Playing',
  'common.search': 'Search',
  'common.undo': 'Undo',
  'context.addToPlaylist': 'Add To',
  'context.deleteFromDisk': 'Delete From Disk',
  'context.deleteSongConfirm': 'Delete "{title}" from disk?',
  'context.pause': 'Pause',
  'context.play': 'Play',
  'context.playNext': 'Play Next',
  'context.seeAlbum': 'See Album',
  'context.seeAlbumArt': 'See Album Art',
  'context.seeArtist': 'See Artist',
  'context.seeLyrics': 'See Lyrics',
  'context.seeLocalFile': 'See In File Explorer',
  'context.seeMusicInfo': 'See Music Info',
  'context.select': 'Select',
  'context.view': 'View',
  'library.scanHelp': 'Scan music first.',
  'library.tryAnotherSearch': 'Try another search.',
  'notification.deletedFromDisk': 'Deleted {title} from disk',
  'notification.playNext': '"{title}" will play next',
  'notification.songAddedTo': 'Added "{title}" to {target}',
  'nowPlaying.loading': 'Loading',
  'nowPlaying.noLyrics': 'No Lyrics',
  'nowPlaying.randomPlay': 'Shuffle',
  'player.more': 'More',
  'player.pause': 'Pause',
  'playlists.create': 'Create',
  'playlists.createNew': 'Create New Playlist',
  'playlists.delete': 'Delete',
  'playlists.namePlaceholder': 'Playlist name',
  'playlists.newName': 'New Playlist',
  'playlists.newPlaylist': 'New Playlist',
  'preferences.level.dislike': 'Dislike',
  'preferences.level.do-not-appear': 'Do Not Appear',
  'preferences.level.high': 'High',
  'preferences.level.higher': 'Higher',
  'preferences.level.normal': 'Normal',
  'preferences.level.very-high': 'Very High',
  'preferences.undoPrefer': 'Undo Prefer',
  'quickJump.disabled': 'No {target} has {basis} starting with {group}',
  'quickJump.enabled': 'Jump to {target} whose {basis} starts with {group}',
  'quickJump.letterGroup': '{key}',
  'quickJump.symbolGroup': 'numbers, symbols, or other characters',
  'settings.preferenceSettings': 'Preference Settings',
  'settings.save': 'Save',
  'sidebar.back': 'Back',
  'sidebar.recentSearches': 'Recent searches',
  'sidebar.removeRecentSearch': 'Remove {query}',
  'song.changeArtwork': 'Change Artwork',
  'song.noAlbumArt': 'No Album Art',
}

const t = (key, params = {}) => {
  let value = messages[key] ?? key
  for (const [name, replacement] of Object.entries(params)) {
    value = value.replaceAll('{' + name + '}', String(replacement))
  }
  return value
}

const songs = [
  song(1, 'Blue Song', 'Artist A', ['Artist A'], 'Blue Hour', 120, false),
  song(2, 'Blue Song 2', 'Artist A', ['Artist A'], 'Blue Hour', 180, true),
  song(3, 'Green Song', 'Artist A; Artist B', ['Artist A', 'Artist B'], 'Green Hour', 210, false),
  song(4, 'Unknown Album Song', '', [], '', 95, false),
]

const playlists = [
  {
    id: 3,
    name: 'Built in',
    priority: 0,
    songCount: 0,
    songIds: [],
    sortCriterion: 'title',
    isBuiltIn: true,
  },
  {
    id: 10,
    name: 'Mix',
    priority: 1,
    songCount: 0,
    songIds: [],
    sortCriterion: 'title',
    isBuiltIn: false,
  },
]

const recentSearches = [
  {
    id: 31,
    query: 'Artist A',
    type: 'artists',
    searchedAt: '2026-05-21T00:00:00',
  },
]

function song(id, title, artist, artists, album, duration, favorite) {
  return {
    id,
    path: 'C:\\\\Music\\\\' + title + '.mp3',
    mediaUrl: '',
    artworkUrl: '',
    title,
    artist,
    artists,
    album,
    duration,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite,
  }
}

function VerifyPage() {
  const artistsPage = (
    <ArtistsPage
      t={t}
      songs={songs}
      selectedTrackId={null}
      isPlaying={false}
      searchQuery=""
      error={null}
      playlists={playlists}
      favoritePlaylistId={3}
      loading={false}
      scanning={false}
      onPlayTrack={() => {}}
      onMoveToMusicOrPlay={() => {}}
      onAddSongsToNowPlaying={() => {}}
      onCreatePlaylistWithSongs={() => {}}
      onTogglePlayPause={() => {}}
      onPlayNext={() => {}}
      onToggleFavorite={() => {}}
      onAddSongToPlaylist={() => {}}
      onAddSongsToPlaylist={() => {}}
      onRecordAlbumPlayed={() => {}}
      onRecordArtistPlayed={() => {}}
      onRevealSong={() => {}}
      onDeleteSongFromDisk={() => {}}
      recentSearches={recentSearches}
      onRecordSearch={() => {}}
      onRemoveRecentSearch={() => {}}
      onRemoveRecentSearches={() => {}}
    />
  )

  if (navMinimal) {
    return (
      <AppRouter>
        <div
          className="app-shell nav-minimal"
          style={{
            height: '100vh',
            background: brightness === 'dark' ? '#0f1318' : '#f8fbfe',
          }}
        >
          <div className="minimal-titlebar" />
          <div className="workspace custom-scrollbar-frame">
            <header className="workspace-header">
              <div className="appbar-title-group">
                <button className="appbar-icon-button appbar-menu-button" type="button" aria-label="Menu">
                  <span />
                </button>
                <span className="appbar-title-placeholder" aria-hidden="true" />
              </div>
              <div className="appbar-spacer drag-spacer" />
              <div className="appbar-actions">
                <div className="appbar-page-actions" id="smplayer-page-appbar-actions" />
              </div>
              <div className="appbar-bottom" id="smplayer-page-appbar-bottom" />
            </header>
            <main className="workspace-content custom-scrollbar-container">
              {artistsPage}
            </main>
          </div>
        </div>
      </AppRouter>
    )
  }

  return (
    <AppRouter>
      <div
        className={navMinimal ? 'app-shell nav-minimal' : 'app-shell'}
        style={{
          display: 'block',
          height: '100vh',
          background: brightness === 'dark' ? '#0f1318' : '#f8fbfe',
        }}
      >
        <main
          className="workspace-content custom-scrollbar-container"
          style={{ height: '100vh', minHeight: 0, padding: 0 }}
        >
          {artistsPage}
        </main>
      </div>
    </AppRouter>
  )
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <VerifyPage />
  </StrictMode>,
)
`
}

function electronCaptureMain() {
  return `const { app, BrowserWindow } = require('electron')
const { writeFile } = require('node:fs/promises')
const { join } = require('node:path')
const { tmpdir } = require('node:os')

const width = Number(process.env.ELECTRON_ARTISTS_VERIFY_WIDTH)
const height = Number(process.env.ELECTRON_ARTISTS_VERIFY_HEIGHT)
const brightness = process.env.ELECTRON_ARTISTS_VERIFY_BRIGHTNESS
const navMinimal = process.env.ELECTRON_ARTISTS_VERIFY_NAV_MINIMAL === '1'
const port = Number(process.env.ELECTRON_ARTISTS_VERIFY_PORT)

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
win.webContents.on('render-process-gone', (_event, details) => {
  console.error('[renderer:gone] ' + details.reason)
})
const targetUrl = 'http://127.0.0.1:' + port + '/?brightness=' + brightness + (navMinimal ? '&navMinimal=1' : '')
console.log('Loading ' + targetUrl)
await Promise.race([
  win.loadURL(targetUrl),
  new Promise((_resolve, reject) => setTimeout(() => reject(new Error('loadURL timeout')), 15000)),
])
console.log('Loaded ' + targetUrl)
await new Promise((resolve) => setTimeout(resolve, 1200))
const image = (await win.webContents.capturePage()).resize({ width, height, quality: 'best' })
const file = join(tmpdir(), 'electron_artists_verify_' + brightness + '_' + width + (navMinimal ? '_nav_minimal' : '') + '.png')
await writeFile(file, image.toPNG())
console.log('Electron artists verify screenshot: ' + file)
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
        ELECTRON_ARTISTS_VERIFY_WIDTH: String(verifyCase.width),
        ELECTRON_ARTISTS_VERIFY_HEIGHT: String(verifyCase.height),
        ELECTRON_ARTISTS_VERIFY_BRIGHTNESS: verifyCase.brightness,
        ELECTRON_ARTISTS_VERIFY_NAV_MINIMAL: verifyCase.navMinimal ? '1' : '0',
        ELECTRON_ARTISTS_VERIFY_PORT: String(port),
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
        resolvePromise(output)
      } else {
        reject(new Error(`electron capture exited with code ${code}`))
      }
    })
  })
}
