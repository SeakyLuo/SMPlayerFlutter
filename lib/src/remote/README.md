# Remote

Pairing, authorization, local HTTP APIs, streaming endpoints, and connection diagnostics.

## AI Agent API

The API is disabled by default and can be enabled from Settings > AI Agent. It
listens on `http://127.0.0.1:<port>/agent` only while the player is running. The
port is configurable in Settings and defaults to `29643`.

- `GET /agent` returns the active SQLite database path, the `Music.Id` song
  identifier mapping, and supported actions.
- `GET /player/state` returns playback state and the current queue.
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
