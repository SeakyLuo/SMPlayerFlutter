# Remote

Pairing, authorization, local HTTP APIs, streaming endpoints, and connection diagnostics.

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
