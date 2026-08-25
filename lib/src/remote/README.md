# Remote

Pairing, authorization, local HTTP APIs, streaming endpoints, and connection diagnostics.

## AI Agent API

The API is disabled by default and can be enabled from Settings > AI Agent. It
listens on `http://127.0.0.1:29643/agent` only while the player is running.

- `GET /agent` returns the active SQLite database path, the `Music.Id` song
  identifier mapping, and supported actions.
- `GET /agent/state` returns playback state and the current queue.
- `POST /agent/control` executes a playback action.

Example:

```json
{
  "action": "play_queue",
  "songIds": [12, 34, 56],
  "startIndex": 0
}
```

Supported actions are `play_song`, `play_queue`, `play`, `pause`, `next`,
`previous`, `seek`, and `set_volume`. Requests carrying a browser `Origin`
header or arriving from a non-loopback address are rejected.
