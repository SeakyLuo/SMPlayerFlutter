# Remote

Pairing, authorization, local HTTP APIs, streaming endpoints, and connection diagnostics.

## LAN music sharing

The source selector above sidebar search scopes library browsing, artists,
albums, favorites and search. Playback and saved playlists retain complete,
source-independent song identities. File browsing keeps the selected music source. Source selection does not navigate away from the current page.

Sharing is off by default. Open Settings > External control and enable sharing for the configured local
music library. The connection QR code is displayed immediately. Both screens show
an eight-character code; approve a request only when those codes match.
The provider must remain awake with SMPlayer running.

Android and iOS clients can choose Scan to connect in Connect device.
The code contains only the HTTPS address and certificate fingerprint; scanning
pins that certificate before requesting approval and never bypasses the
matching-code authorization step. Select the shared network address when the
computer has multiple network interfaces. Camera failures return to manual
connection with a toast. New approval requests scroll into view on the host.

Device name, AI control port and remote playback port are edited directly in
External control. Authorized devices are managed in a separate dialog.
Music sharing uses a separate HTTPS listener (default port 29644) and UDP discovery
on port 29645. Manual address entry is available. Certificates are pinned after
pairing; private keys, client tokens and grant hashes use system secure storage.
The local AI Agent listener is unchanged and is never exposed by sharing.

Authorized endpoints are `/status`, `/catalog`, and `/songs/:id/audio`,
`/songs/:id/artwork`, `/songs/:id/lyrics`. Audio supports byte ranges and HEAD.
Playback uses a random, loopback-only bridge to the pinned HTTPS connection;
authorization tokens never appear in playback URLs. Remote files are read-only.

Imported metadata uses stable `smplayer-music://<device>/<song>` paths in Music,
so existing playlist, favorite, queue and history storage retain their identities.
Schema 8 removes the old `Music.RemoteAvailable` and `Music.RemoteDetailsLoaded`
columns. Removed remote songs use the existing `Music.State` deletion state,
leave ordinary browsing, and remain unavailable in saved queues. Changes
invalidate the relevant caches; accessed pages read data on demand. Offline
devices retain their last known metadata.

## AI Agent API

The API is disabled by default and can be enabled from Settings > AI Agent. It
listens on `http://127.0.0.1:<port>/agent` only while the player is running. The
port is configurable in Settings and defaults to `29643`.

- `GET /agent` returns the active SQLite database path, the `Music.Id` song
  identifier mapping, and supported actions.
- `GET /player/state` returns playback state and the current queue.
- `GET /settings` returns current editable preferences and their schema,
  including enum choices, installed fonts and numeric ranges.
- `POST /settings/update` changes only the supplied `properties` through the
  same SettingsController used by the UI, persists them and notifies consumers.
  Library root changes and the API's own enable/port controls are not exposed
  as plain settings updates; their operational workflows remain in the UI.
- `POST /app/sync` accepts changed `settings` keys and/or existing active
  `songIds` (at most 128 per request). Commit database changes first.
  Only the supplied settings are applied to the in-memory snapshot; song
  rows are read in one bounded batch and patched into display overrides.
  It does not invalidate whole-library snapshots, clear unrelated overrides,
  rescan files, write audio tags or replace the active playback session.
  This is an update operation, not a song insertion/deletion or playlist-edit
  operation. Unknown keys and missing/inactive songs are rejected.
- `POST /song/play` plays one song.
- `POST /queue/play` replaces and starts the queue.
- `POST /player/play`, `/player/pause`, `/player/next`, and `/player/previous`
  control playback.
- `POST /player/seek` changes playback position.
- `POST /player/volume` changes the volume.
- `POST /song/update` updates song information.

Example:

```json
{
  "songIds": [12, 34, 56],
  "startIndex": 0
}
```

Song updates use the same metadata path as the song information dialog, writing
both the audio tags and the library database. Only the properties included in
the request are changed.

```json
{
  "songId": 12,
  "properties": {
    "title": "New title",
    "artists": ["Artist one", "Artist two"],
    "album": "Album name",
    "year": 2026
  }
}
```

Requests carrying a browser `Origin` header or arriving from a non-loopback
address are rejected.

Settings example (desktop lyrics font and size):

```json
{
  "properties": {
    "desktopLyricsFontFamily": "system",
    "desktopLyricsFontSize": 32
  }
}
```

Query the database for song selection, but use the API for modifications.
Direct SQLite writes bypass in-memory state notifications. Commit your
transaction, then call `/app/sync` with the precise changed keys and song IDs
to synchronize their displayed values. Audio-tag writes and operational workflows still require their
corresponding actions. The API is not a filesystem sandbox: a local
agent with filesystem write access can still modify that database directly.

```json
{
  "settings": ["desktopLyricsFontSize"],
  "songIds": [12, 34]
}
```
