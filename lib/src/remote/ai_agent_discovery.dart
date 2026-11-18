Map<String, Object?> aiAgentDiscovery(String databasePath, String endpoint) => {
  'endpoint': endpoint,
  'guidance':
      'Read the database for song selection. Use API actions for '
      'writes so application state, audio tags and native features stay '
      'in sync. After direct database writes, commit before POST /app/sync '
      'with the changed setting keys and existing song IDs. '
      'Sync does not reload pages, write audio tags or run library scans. '
      'GET /settings returns editable values and allowed options. '
      'If the player is closed, POST /app/open first; use the returned endpoint '
      'for player operations. Follow HTTP 307 on sharing updates, preserving POST.',
  'endpoints': {
    'info': {'method': 'GET', 'path': '/agent'},
    'openPlayer': {'method': 'POST', 'path': '/app/open'},
    'sharing': {'method': 'GET', 'path': '/sharing'},
    'sharingUpdate': {
      'method': 'POST',
      'path': '/sharing/update',
      'body': {
        'enabled': 'boolean (optional)',
        'background': 'boolean (optional)',
      },
    },
    'playerState': {'method': 'GET', 'path': '/player/state'},
    'settings': {'method': 'GET', 'path': '/settings'},
    'settingsUpdate': {
      'method': 'POST',
      'path': '/settings/update',
      'body': {'properties': 'partial object matching GET /settings schema'},
    },
    'appSync': {
      'method': 'POST',
      'path': '/app/sync',
      'body': {
        'settings': 'editable setting key[] (optional)',
        'songIds': 'existing active song ID[] (optional, maximum 128)',
      },
    },
    'songPlay': {
      'method': 'POST',
      'path': '/song/play',
      'body': {'songId': 'integer'},
    },
    'queuePlay': {
      'method': 'POST',
      'path': '/queue/play',
      'body': {'songIds': 'integer[]', 'startIndex': 'integer'},
    },
    'playerPlay': {'method': 'POST', 'path': '/player/play'},
    'playerPause': {'method': 'POST', 'path': '/player/pause'},
    'playerNext': {'method': 'POST', 'path': '/player/next'},
    'playerPrevious': {'method': 'POST', 'path': '/player/previous'},
    'playerSeek': {
      'method': 'POST',
      'path': '/player/seek',
      'body': {'seconds': 'number'},
    },
    'playerVolume': {
      'method': 'POST',
      'path': '/player/volume',
      'body': {'value': 'integer (0-100)'},
    },
    'songUpdate': {
      'method': 'POST',
      'path': '/song/update',
      'body': {
        'songId': 'integer',
        'properties': {
          'title': 'string',
          'subtitle': 'string',
          'artists': 'string[] (maximum 6)',
          'album': 'string',
          'albumArtist': 'string',
          'publisher': 'string',
          'trackNumber': 'integer',
          'year': 'integer',
          'genre': 'string',
          'composers': 'string',
          'playCount': 'integer',
        },
      },
    },
  },
  'database': {
    'type': 'sqlite',
    'path': databasePath,
    'songTable': 'Music',
    'songIdColumn': 'Id',
  },
};
