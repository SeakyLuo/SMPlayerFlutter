enum VoiceAssistantMatchType {
  matchNone,
  play,
  playMusic,
  playArtist,
  playAlbum,
  playPlaylist,
  playFolder,
  searchAndPlay,
  quickPlay,
  playByArtistOrMusic,
  playByArtist,
  playByArtistAndMusic,
  playByArtistAndAlbum,
  playMusicIn,
  playMusicInAlbum,
  playMusicInFolder,
  playMusicInPlaylist,
  pause,
  previous,
  next,
  changeVolume,
  search,
  mute,
  unMute,
  help,
  nothing,
}

class VoiceAssistantCommandResult {
  const VoiceAssistantCommandResult(
    this.type, {
    this.value,
    this.request,
    this.volumeRequest,
  });

  final VoiceAssistantMatchType type;
  final String? value;
  final VoiceAssistantSplitRequest? request;
  final VoiceAssistantVolumeRequest? volumeRequest;
}

class VoiceAssistantSplitRequest {
  const VoiceAssistantSplitRequest({
    required this.left,
    required this.right,
    required this.original,
  });

  factory VoiceAssistantSplitRequest.parse(String original, String splitter) {
    final index = original.toLowerCase().indexOf(splitter);
    return VoiceAssistantSplitRequest(
      left: _trimVoiceValue(original.substring(0, index)),
      right: _trimVoiceValue(original.substring(index + splitter.length)),
      original: _trimVoiceValue(original),
    );
  }

  final String left;
  final String right;
  final String original;
}

class VoiceAssistantVolumeRequest {
  const VoiceAssistantVolumeRequest({
    required this.to,
    required this.turnUp,
    required this.percentage,
    required this.value,
  });

  final bool to;
  final bool turnUp;
  final bool percentage;
  final double value;
}

VoiceAssistantCommandResult parseVoiceAssistantCommand(
  String text,
  String locale,
) {
  final normalizedLocale = locale.toLowerCase();
  if (normalizedLocale.startsWith('zh')) {
    return parseChineseVoiceAssistantCommand(text);
  }

  final localizedResult = parseLocalizedVoiceAssistantCommand(text, locale);
  if (localizedResult.type != VoiceAssistantMatchType.matchNone) {
    return localizedResult;
  }

  return parseEnglishVoiceAssistantCommand(text);
}

VoiceAssistantCommandResult parseEnglishVoiceAssistantCommand(String text) {
  final command = text.trim();
  final lower = command.toLowerCase();
  if (RegExp(r'^(?!play).*quick play').hasMatch(lower) ||
      RegExp(r'^(?!play).*(give|get).*(me)? some music').hasMatch(lower)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.quickPlay);
  }

  if (lower == 'play') {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.play);
  }

  if (lower.contains('play')) {
    return _parseEnglishPlayCommand(command);
  }

  if (lower.contains('resume') || lower.contains('continue')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.play);
  }

  if (RegExp(
    r'volume|sound|turn up|turn down',
    caseSensitive: false,
  ).hasMatch(command)) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.changeVolume,
      volumeRequest: _parseEnglishVolumeRequest(command),
    );
  }

  if (lower.contains('previous')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.previous);
  }

  if (lower.contains('next')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.next);
  }

  if (lower.contains('unmute')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.unMute);
  }

  if (lower.contains('mute')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.mute);
  }

  if (lower.contains('pause')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.pause);
  }

  if (lower.contains('help')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.help);
  }

  final search = _matchValue(
    command,
    RegExp(r'(?<=search).+', caseSensitive: false),
  );
  if (search != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.search,
      value: search,
    );
  }

  if (lower.contains('nothing') || lower.contains('never mind')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.nothing);
  }

  return const VoiceAssistantCommandResult(VoiceAssistantMatchType.matchNone);
}

VoiceAssistantCommandResult parseChineseVoiceAssistantCommand(String text) {
  final command = text.trim();
  if (command.contains('快速播放')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.quickPlay);
  }

  if (command.contains('恢复') || command.contains('继续') || command == '播放') {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.play);
  }

  if (command.contains('前一首') || command.contains('上一首') || command == '上首') {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.previous);
  }

  if (command.contains('后一首') || command.contains('下一首') || command == '下首') {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.next);
  }

  if (command.contains('取消静音')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.unMute);
  }

  if (command.contains('静音')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.mute);
  }

  if (command.startsWith('暂停')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.pause);
  }

  if (command.contains('帮助')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.help);
  }

  final search = _matchValue(command, RegExp(r'(?<=搜索).*'));
  if (search != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.search,
      value: search,
    );
  }

  if (command.startsWith('没事') || command.startsWith('算了')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.nothing);
  }

  if (_isChinesePlayMusic(command)) {
    return _parseChinesePlayCommand(command);
  }

  if (command.contains('音量') || command.contains('声音')) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.changeVolume,
      volumeRequest: _parseChineseVolumeRequest(command),
    );
  }

  return const VoiceAssistantCommandResult(VoiceAssistantMatchType.matchNone);
}

VoiceAssistantCommandResult _parseEnglishPlayCommand(String command) {
  final playMusic = _matchValue(
    command,
    RegExp(r'(?<=play .*music).*', caseSensitive: false),
  );
  if (playMusic != null) {
    final playMusicByArtist = _matchValue(
      command,
      RegExp(r'(?<=play .*music).+ by .+', caseSensitive: false),
    );
    if (playMusicByArtist != null) {
      return VoiceAssistantCommandResult(
        VoiceAssistantMatchType.playByArtistAndMusic,
        request: VoiceAssistantSplitRequest.parse(playMusicByArtist, ' by '),
      );
    }

    final playMusicIn = _parseEnglishPlayMusicIn(command, 'play .*music');
    if (playMusicIn != null) {
      return playMusicIn;
    }

    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playMusic,
      value: playMusic,
    );
  }

  final playByArtist = _matchValue(
    command,
    RegExp(r'(?<=play) .+ by .+', caseSensitive: false),
  );
  if (playByArtist != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playByArtist,
      request: VoiceAssistantSplitRequest.parse(playByArtist, ' by '),
    );
  }

  final playIn = _parseEnglishPlayMusicIn(command, 'play .+');
  if (playIn != null) {
    return playIn;
  }

  final playByPossessiveArtist = _matchValue(
    command,
    RegExp(r"(?<=play) .+'s .+", caseSensitive: false),
  );
  if (playByPossessiveArtist != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playByArtist,
      request: VoiceAssistantSplitRequest.parse(playByPossessiveArtist, "'s "),
    );
  }

  final playArtist = _matchValue(
    command,
    RegExp(r'(?<=play .*(artist|musician|singer)).*', caseSensitive: false),
  );
  if (playArtist != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playArtist,
      value: playArtist,
    );
  }

  final playAlbum = _matchValue(
    command,
    RegExp(r'(?<=play .*album).*', caseSensitive: false),
  );
  if (playAlbum != null) {
    final playAlbumByArtist = _matchValue(
      command,
      RegExp(r'(?<=play .*album) .+ by .+', caseSensitive: false),
    );
    if (playAlbumByArtist != null) {
      return VoiceAssistantCommandResult(
        VoiceAssistantMatchType.playByArtistAndAlbum,
        request: VoiceAssistantSplitRequest.parse(playAlbumByArtist, ' by '),
      );
    }
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playAlbum,
      value: playAlbum,
    );
  }

  final playPlaylist = _matchValue(
    command,
    RegExp(r'(?<=play .*playlist).*', caseSensitive: false),
  );
  if (playPlaylist != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playPlaylist,
      value: playPlaylist,
    );
  }

  final playFolder = _matchValue(
    command,
    RegExp(r'(?<=play .*folder).*', caseSensitive: false),
  );
  if (playFolder != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playFolder,
      value: playFolder,
    );
  }

  final play = _matchValue(
    command,
    RegExp(r'(?<=play).*', caseSensitive: false),
  );
  return play == null
      ? const VoiceAssistantCommandResult(VoiceAssistantMatchType.matchNone)
      : VoiceAssistantCommandResult(
        VoiceAssistantMatchType.searchAndPlay,
        value: play,
      );
}

bool _isChinesePlayMusic(String text) {
  return text.contains('播放') ||
      RegExp(r'(来|放)(一)?(首|个|点|下)(歌)?').hasMatch(text);
}

VoiceAssistantCommandResult _parseChinesePlayCommand(String command) {
  final playArtist = _matchValue(command, RegExp(r'(?<=播放歌手).*'));
  if (playArtist != null) {
    final byArtistAndAlbum = _parseChineseByArtistWithTag(
      command,
      '播放歌手',
      '的专辑',
      VoiceAssistantMatchType.playByArtistAndAlbum,
    );
    if (byArtistAndAlbum != null) {
      return byArtistAndAlbum;
    }
    final byArtistAndMusic =
        _parseChineseByArtistWithTag(
          command,
          '播放歌手',
          '的歌曲',
          VoiceAssistantMatchType.playByArtistAndMusic,
        ) ??
        _parseChineseByArtistWithTag(
          command,
          '播放歌手',
          '的歌',
          VoiceAssistantMatchType.playByArtistAndMusic,
        );
    if (byArtistAndMusic != null) {
      return byArtistAndMusic;
    }
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playArtist,
      value: playArtist,
    );
  }

  final playAlbum = _matchValue(command, RegExp(r'(?<=播放专辑).*'));
  if (playAlbum != null) {
    final albumSong = _parseChinesePlayMusicIn(
      command,
      RegExp(r'播放专辑(.+)中的(.+)'),
      VoiceAssistantMatchType.playMusicInAlbum,
    );
    if (albumSong != null) {
      return albumSong;
    }
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playAlbum,
      value: playAlbum,
    );
  }

  final playPlaylist = _matchValue(command, RegExp(r'(?<=播放(列表|歌单)).*'));
  if (playPlaylist != null) {
    final playlistSong = _parseChinesePlayMusicIn(
      command,
      RegExp(r'播放(?:列表|歌单)(.+)中的(.+)'),
      VoiceAssistantMatchType.playMusicInPlaylist,
    );
    if (playlistSong != null) {
      return playlistSong;
    }
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playPlaylist,
      value: playPlaylist,
    );
  }

  final playFolder = _matchValue(command, RegExp(r'(?<=播放文件夹).*'));
  if (playFolder != null) {
    final folderSong = _parseChinesePlayMusicIn(
      command,
      RegExp(r'播放文件夹(.+)中的(.+)'),
      VoiceAssistantMatchType.playMusicInFolder,
    );
    if (folderSong != null) {
      return folderSong;
    }
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playFolder,
      value: playFolder,
    );
  }

  final playMusic = _matchValue(
    command,
    RegExp(r'(?<=(播放(歌曲|音乐)|(来|放)(一)?(首|下)(歌)?)).*'),
  );
  if (playMusic != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playMusic,
      value: playMusic,
    );
  }

  final prefix = RegExp(r'(?<=(播放|(来|放)(一)(个|下|点))).+');
  final byArtistAndAlbum = _parseChineseByArtistWithTag(
    command,
    prefix,
    '的专辑',
    VoiceAssistantMatchType.playByArtistAndAlbum,
  );
  if (byArtistAndAlbum != null) {
    return byArtistAndAlbum;
  }

  final byArtistAndMusic =
      _parseChineseByArtistWithTag(
        command,
        prefix,
        '的歌曲',
        VoiceAssistantMatchType.playByArtistAndMusic,
      ) ??
      _parseChineseByArtistWithTag(
        command,
        prefix,
        '的歌',
        VoiceAssistantMatchType.playByArtistAndMusic,
      );
  if (byArtistAndMusic != null) {
    return byArtistAndMusic;
  }

  final artistSongs = _matchValue(
    command,
    RegExp(r'(?<=(播放|(来|放)(一)(个|下|点))).+的歌.*'),
  );
  if (artistSongs != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playByArtistOrMusic,
      request: _parseChineseByArtistRequest(artistSongs, '的歌'),
    );
  }

  final playMusicIn = _parseChinesePlayMusicIn(
    command,
    RegExp(r'(?:播放|(来|放)(一)(个|下|点))(.+)中的(.+)'),
    VoiceAssistantMatchType.playMusicIn,
  );
  if (playMusicIn != null) {
    return playMusicIn;
  }

  final byArtist = _parseChineseByArtistWithTag(
    command,
    prefix,
    '的',
    VoiceAssistantMatchType.playByArtist,
  );
  if (byArtist != null) {
    return byArtist;
  }

  final play = _matchValue(command, prefix);
  return play == null
      ? const VoiceAssistantCommandResult(VoiceAssistantMatchType.matchNone)
      : VoiceAssistantCommandResult(
        VoiceAssistantMatchType.searchAndPlay,
        value: play,
      );
}

VoiceAssistantCommandResult? _parseChineseByArtistWithTag(
  String command,
  Object patternPrefix,
  String tag,
  VoiceAssistantMatchType type,
) {
  final value =
      patternPrefix is RegExp
          ? _matchValue(command, RegExp('${patternPrefix.pattern}$tag.+'))
          : _matchValue(command, RegExp('(?<=$patternPrefix).+$tag.+'));
  if (value == null) {
    return null;
  }
  final request = _parseChineseByArtistRequest(value, tag);
  return VoiceAssistantCommandResult(type, request: request);
}

VoiceAssistantSplitRequest _parseChineseByArtistRequest(
  String original,
  String splitter,
) {
  final index = original.indexOf(splitter);
  return VoiceAssistantSplitRequest(
    left: _trimVoiceValue(original.substring(index + splitter.length)),
    right: _trimVoiceValue(original.substring(0, index)),
    original: _trimVoiceValue(original),
  );
}

VoiceAssistantCommandResult? _parseChinesePlayMusicIn(
  String command,
  RegExp pattern,
  VoiceAssistantMatchType type,
) {
  final match = pattern.firstMatch(command);
  if (match == null) {
    return null;
  }
  final target = _trimVoiceValue(match.group(match.groupCount - 1)!);
  final song = _trimVoiceValue(match.group(match.groupCount)!);
  return VoiceAssistantCommandResult(
    type,
    request: VoiceAssistantSplitRequest(
      left: song.replaceFirst(RegExp(r'^(歌曲|歌)'), '').trim(),
      right: target,
      original: _trimVoiceValue('$target $song'),
    ),
  );
}

VoiceAssistantCommandResult parseLocalizedVoiceAssistantCommand(
  String text,
  String locale,
) {
  final lexicon = _localizedVoiceLexiconFor(locale);
  if (lexicon == null) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.matchNone);
  }

  final normalizedLexicon = _normalizeLocalizedLexicon(lexicon);
  final command = _normalizeLocalizedText(text);

  if (_containsAny(command, normalizedLexicon['cancel']!)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.nothing);
  }
  if (_containsAny(command, normalizedLexicon['quickPlay']!)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.quickPlay);
  }
  if (_containsAny(command, normalizedLexicon['unmute']!)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.unMute);
  }
  if (_containsAny(command, normalizedLexicon['mute']!)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.mute);
  }
  if (_containsAny(command, normalizedLexicon['previous']!)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.previous);
  }
  if (_containsAny(command, normalizedLexicon['next']!)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.next);
  }
  if (_containsAny(command, normalizedLexicon['pause']!)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.pause);
  }
  if (_containsAny(command, normalizedLexicon['help']!)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.help);
  }
  if (_containsAny(command, normalizedLexicon['volume']!)) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.changeVolume,
      volumeRequest: _parseLocalizedVolumeRequest(command, normalizedLexicon),
    );
  }

  final searchQuery = _remainderAfterAny(command, normalizedLexicon['search']!);
  if (searchQuery != null) {
    return searchQuery.isEmpty
        ? const VoiceAssistantCommandResult(VoiceAssistantMatchType.matchNone)
        : VoiceAssistantCommandResult(
          VoiceAssistantMatchType.search,
          value: searchQuery,
        );
  }

  final playRemainder = _remainderAfterAny(command, [
    ...normalizedLexicon['play']!,
    ...normalizedLexicon['resume']!,
  ]);
  if (playRemainder != null) {
    return _parseLocalizedPlayCommand(playRemainder, normalizedLexicon);
  }

  return const VoiceAssistantCommandResult(VoiceAssistantMatchType.matchNone);
}

VoiceAssistantCommandResult _parseLocalizedPlayCommand(
  String value,
  Map<String, List<String>> lexicon,
) {
  if (value.isEmpty) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.play);
  }

  final artist = _remainderAfterAny(value, lexicon['artist']!);
  if (artist != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playArtist,
      value: artist,
    );
  }

  final album = _remainderAfterAny(value, lexicon['album']!);
  if (album != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playAlbum,
      value: album,
    );
  }

  final playlist = _remainderAfterAny(value, lexicon['playlist']!);
  if (playlist != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playPlaylist,
      value: playlist,
    );
  }

  final folder = _remainderAfterAny(value, lexicon['folder']!);
  if (folder != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playFolder,
      value: folder,
    );
  }

  final music = _remainderAfterAny(value, lexicon['music']!);
  if (music != null) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playMusic,
      value: music,
    );
  }

  return VoiceAssistantCommandResult(
    VoiceAssistantMatchType.searchAndPlay,
    value: value,
  );
}

const _localizedVoiceLexicons = <String, Map<String, List<String>>>{
  'fr': {
    'quickPlay': ['lecture rapide', 'musique au hasard'],
    'play': ['joue', 'jouer', 'lance', 'lancer', 'mets', 'mettre'],
    'resume': ['reprendre', 'continue', 'continuer'],
    'pause': ['pause', 'mets en pause'],
    'previous': [
      'precedent',
      'precedente',
      'titre precedent',
      'morceau precedent',
    ],
    'next': ['suivant', 'suivante', 'titre suivant', 'morceau suivant'],
    'mute': ['muet', 'coupe le son', 'couper le son'],
    'unmute': ['remets le son', 'reactive le son', 'retablis le son'],
    'help': ['aide'],
    'cancel': ['rien', 'annule', 'laisse tomber'],
    'search': ['chercher', 'cherche', 'rechercher', 'recherche'],
    'volume': ['volume', 'son'],
    'volumeUp': ['augmente', 'monte', 'plus fort'],
    'volumeDown': ['baisse', 'diminue', 'moins fort'],
    'volumeTo': ['a', 'jusqu a'],
    'percent': ['pour cent', 'pourcent'],
    'music': ['musique', 'morceau', 'chanson', 'titre'],
    'artist': ['artiste', 'chanteur', 'chanteuse'],
    'album': ['album'],
    'playlist': ['playlist', 'liste'],
    'folder': ['dossier'],
  },
  'ru': {
    'quickPlay': ['быстрое воспроизведение', 'случайная музыка'],
    'play': ['включи', 'воспроизведи', 'проиграй', 'играй'],
    'resume': ['продолжи', 'возобнови'],
    'pause': ['пауза', 'поставь на паузу'],
    'previous': ['предыдущий', 'предыдущая', 'предыдущий трек'],
    'next': ['следующий', 'следующая', 'следующий трек'],
    'mute': ['без звука', 'выключи звук'],
    'unmute': ['включи звук', 'верни звук'],
    'help': ['помощь', 'справка'],
    'cancel': ['ничего', 'отмена'],
    'search': ['поиск', 'найди', 'искать'],
    'volume': ['громкость', 'звук'],
    'volumeUp': ['громче', 'увеличь', 'прибавь'],
    'volumeDown': ['тише', 'уменьши', 'убавь'],
    'volumeTo': ['до', 'на'],
    'percent': ['процент', 'процентов'],
    'music': ['музыку', 'песню', 'трек'],
    'artist': ['исполнителя', 'артиста', 'певца'],
    'album': ['альбом'],
    'playlist': ['плейлист', 'список'],
    'folder': ['папку'],
  },
  'ja': {
    'quickPlay': ['クイック再生', 'ランダム再生'],
    'play': ['再生', 'かけて', '流して'],
    'resume': ['再開', '続けて'],
    'pause': ['一時停止', '停止'],
    'previous': ['前の曲', '前へ'],
    'next': ['次の曲', '次へ'],
    'mute': ['ミュート'],
    'unmute': ['ミュート解除'],
    'help': ['ヘルプ', '助けて'],
    'cancel': ['キャンセル', 'やめて'],
    'search': ['検索', '探して'],
    'volume': ['音量', 'ボリューム'],
    'volumeUp': ['上げて', '大きく'],
    'volumeDown': ['下げて', '小さく'],
    'volumeTo': ['まで', 'に'],
    'percent': ['パーセント'],
    'music': ['曲', '音楽'],
    'artist': ['アーティスト', '歌手'],
    'album': ['アルバム'],
    'playlist': ['プレイリスト'],
    'folder': ['フォルダー', 'フォルダ'],
  },
  'de': {
    'quickPlay': ['schnellwiedergabe', 'zufallsmusik'],
    'play': ['spiele', 'spiel', 'abspielen'],
    'resume': ['fortsetzen', 'weiter'],
    'pause': ['pause', 'pausieren'],
    'previous': ['vorheriger', 'vorheriges lied', 'zuruck'],
    'next': ['nachster', 'nachstes lied', 'weiter'],
    'mute': ['stumm', 'ton aus'],
    'unmute': ['ton an', 'stumm aus'],
    'help': ['hilfe'],
    'cancel': ['nichts', 'abbrechen'],
    'search': ['suche', 'suchen'],
    'volume': ['lautstarke', 'ton'],
    'volumeUp': ['lauter', 'erhohe'],
    'volumeDown': ['leiser', 'senke'],
    'volumeTo': ['auf', 'bis'],
    'percent': ['prozent'],
    'music': ['musik', 'lied', 'titel'],
    'artist': ['kunstler', 'sanger'],
    'album': ['album'],
    'playlist': ['playlist', 'wiedergabeliste'],
    'folder': ['ordner'],
  },
  'pt-BR': {
    'quickPlay': ['reproducao rapida', 'tocar aleatorio'],
    'play': ['tocar', 'toque', 'reproduzir', 'reproduza'],
    'resume': ['continuar', 'continue'],
    'pause': ['pausar', 'pause'],
    'previous': ['anterior', 'musica anterior'],
    'next': ['proxima', 'proximo', 'musica seguinte'],
    'mute': ['silenciar', 'sem som'],
    'unmute': ['ativar som', 'tirar do mudo'],
    'help': ['ajuda'],
    'cancel': ['nada', 'cancelar'],
    'search': ['buscar', 'pesquisar', 'procure'],
    'volume': ['volume', 'som'],
    'volumeUp': ['aumentar', 'aumente', 'mais alto'],
    'volumeDown': ['diminuir', 'diminua', 'mais baixo'],
    'volumeTo': ['para', 'ate'],
    'percent': ['por cento'],
    'music': ['musica', 'cancao', 'faixa'],
    'artist': ['artista', 'cantor', 'cantora'],
    'album': ['album'],
    'playlist': ['playlist', 'lista'],
    'folder': ['pasta'],
  },
  'es': {
    'quickPlay': ['reproduccion rapida', 'musica aleatoria'],
    'play': ['reproduce', 'reproducir', 'pon', 'poner', 'toca'],
    'resume': ['continua', 'continuar', 'reanuda'],
    'pause': ['pausa', 'pausar'],
    'previous': ['anterior', 'cancion anterior'],
    'next': ['siguiente', 'proxima', 'cancion siguiente'],
    'mute': ['silencio', 'silenciar', 'quita el sonido'],
    'unmute': ['activar sonido', 'restaurar sonido'],
    'help': ['ayuda'],
    'cancel': ['nada', 'cancelar'],
    'search': ['buscar', 'busca'],
    'volume': ['volumen', 'sonido'],
    'volumeUp': ['sube', 'subir', 'aumenta'],
    'volumeDown': ['baja', 'bajar', 'disminuye'],
    'volumeTo': ['a', 'hasta'],
    'percent': ['por ciento'],
    'music': ['musica', 'cancion', 'tema', 'pista'],
    'artist': ['artista', 'cantante'],
    'album': ['album'],
    'playlist': ['playlist', 'lista'],
    'folder': ['carpeta'],
  },
  'it': {
    'quickPlay': ['riproduzione rapida', 'musica casuale'],
    'play': ['riproduci', 'metti', 'suona'],
    'resume': ['continua', 'riprendi'],
    'pause': ['pausa', 'metti in pausa'],
    'previous': ['precedente', 'brano precedente'],
    'next': ['successivo', 'prossimo', 'brano successivo'],
    'mute': ['muto', 'disattiva audio'],
    'unmute': ['attiva audio', 'riattiva audio'],
    'help': ['aiuto'],
    'cancel': ['niente', 'annulla'],
    'search': ['cerca', 'ricerca'],
    'volume': ['volume', 'audio'],
    'volumeUp': ['aumenta', 'alza'],
    'volumeDown': ['abbassa', 'diminuisci'],
    'volumeTo': ['a', 'fino a'],
    'percent': ['per cento'],
    'music': ['musica', 'canzone', 'brano'],
    'artist': ['artista', 'cantante'],
    'album': ['album'],
    'playlist': ['playlist', 'lista'],
    'folder': ['cartella'],
  },
  'nl': {
    'quickPlay': ['snel afspelen', 'willekeurige muziek'],
    'play': ['speel', 'afspelen'],
    'resume': ['hervatten', 'doorgaan'],
    'pause': ['pauze', 'pauzeren'],
    'previous': ['vorige', 'vorig nummer'],
    'next': ['volgende', 'volgend nummer'],
    'mute': ['dempen', 'geluid uit'],
    'unmute': ['geluid aan', 'dempen uit'],
    'help': ['help'],
    'cancel': ['niets', 'annuleren'],
    'search': ['zoek', 'zoeken'],
    'volume': ['volume', 'geluid'],
    'volumeUp': ['harder', 'verhoog'],
    'volumeDown': ['zachter', 'verlaag'],
    'volumeTo': ['naar', 'tot'],
    'percent': ['procent'],
    'music': ['muziek', 'nummer', 'lied'],
    'artist': ['artiest', 'zanger'],
    'album': ['album'],
    'playlist': ['playlist', 'afspeellijst'],
    'folder': ['map'],
  },
  'cs': {
    'quickPlay': ['rychle prehrat', 'nahodna hudba'],
    'play': ['prehraj', 'pust', 'spust'],
    'resume': ['pokracuj', 'obnov'],
    'pause': ['pauza', 'pozastav'],
    'previous': ['predchozi', 'predchozi skladba'],
    'next': ['dalsi', 'dalsi skladba'],
    'mute': ['ztlumit', 'vypnout zvuk'],
    'unmute': ['zapnout zvuk'],
    'help': ['pomoc', 'napoveda'],
    'cancel': ['nic', 'zrusit'],
    'search': ['hledat', 'najdi'],
    'volume': ['hlasitost', 'zvuk'],
    'volumeUp': ['zesil', 'zvys'],
    'volumeDown': ['ztis', 'sniz'],
    'volumeTo': ['na', 'do'],
    'percent': ['procent'],
    'music': ['hudbu', 'skladbu', 'pisnicku'],
    'artist': ['interpreta', 'umelce', 'zpevaka'],
    'album': ['album'],
    'playlist': ['playlist', 'seznam'],
    'folder': ['slozku'],
  },
  'uk': {
    'quickPlay': ['швидке відтворення', 'випадкова музика'],
    'play': ['увімкни', 'відтвори', 'грай'],
    'resume': ['продовжити', 'віднови'],
    'pause': ['пауза', 'постав на паузу'],
    'previous': ['попередній', 'попередня пісня'],
    'next': ['наступний', 'наступна пісня'],
    'mute': ['без звуку', 'вимкни звук'],
    'unmute': ['увімкни звук', 'поверни звук'],
    'help': ['допомога'],
    'cancel': ['нічого', 'скасувати'],
    'search': ['пошук', 'знайди', 'шукати'],
    'volume': ['гучність', 'звук'],
    'volumeUp': ['голосніше', 'збільш'],
    'volumeDown': ['тихіше', 'зменш'],
    'volumeTo': ['до', 'на'],
    'percent': ['відсотків', 'відсоток'],
    'music': ['музику', 'пісню', 'трек'],
    'artist': ['виконавця', 'артиста', 'співака'],
    'album': ['альбом'],
    'playlist': ['плейлист', 'список'],
    'folder': ['папку'],
  },
  'sv': {
    'quickPlay': ['snabbuppspelning', 'slumpad musik'],
    'play': ['spela', 'starta'],
    'resume': ['fortsatt', 'ateruppta'],
    'pause': ['pausa', 'paus'],
    'previous': ['foregaende', 'forra laten'],
    'next': ['nasta', 'nasta lat'],
    'mute': ['tysta', 'ljud av'],
    'unmute': ['ljud pa', 'sluta tysta'],
    'help': ['hjalp'],
    'cancel': ['inget', 'avbryt'],
    'search': ['sok', 'soka'],
    'volume': ['volym', 'ljud'],
    'volumeUp': ['hoj', 'hogre'],
    'volumeDown': ['sank', 'lagre'],
    'volumeTo': ['till'],
    'percent': ['procent'],
    'music': ['musik', 'lat', 'spar'],
    'artist': ['artist', 'sangare'],
    'album': ['album'],
    'playlist': ['spellista', 'playlist'],
    'folder': ['mapp'],
  },
  'id': {
    'quickPlay': ['putar cepat', 'musik acak'],
    'play': ['putar', 'mainkan'],
    'resume': ['lanjutkan'],
    'pause': ['jeda', 'pause'],
    'previous': ['sebelumnya', 'lagu sebelumnya'],
    'next': ['berikutnya', 'lagu berikutnya'],
    'mute': ['bisukan', 'matikan suara'],
    'unmute': ['nyalakan suara', 'batal bisu'],
    'help': ['bantuan'],
    'cancel': ['tidak jadi', 'batal'],
    'search': ['cari', 'pencarian'],
    'volume': ['volume', 'suara'],
    'volumeUp': ['naikkan', 'lebih keras'],
    'volumeDown': ['turunkan', 'lebih pelan'],
    'volumeTo': ['ke', 'sampai'],
    'percent': ['persen'],
    'music': ['musik', 'lagu', 'trek'],
    'artist': ['artis', 'penyanyi'],
    'album': ['album'],
    'playlist': ['playlist', 'daftar putar'],
    'folder': ['folder'],
  },
};

Map<String, List<String>>? _localizedVoiceLexiconFor(String locale) {
  final normalizedLocale = locale.toLowerCase();
  for (final entry in _localizedVoiceLexicons.entries) {
    if (entry.key.toLowerCase() == normalizedLocale) {
      return entry.value;
    }
  }
  return _localizedVoiceLexicons[normalizedLocale.split('-').first];
}

VoiceAssistantVolumeRequest _parseEnglishVolumeRequest(String text) {
  final fraction = _firstFraction(text);
  final number = _firstVoiceNumber(text);
  final lower = text.toLowerCase();
  final half = lower.contains('half');
  final quarter = lower.contains('quarter');

  if (number == null && fraction == null && !half && !quarter) {
    return VoiceAssistantVolumeRequest(
      to: false,
      turnUp: !RegExp(r'lower|down', caseSensitive: false).hasMatch(text),
      percentage: false,
      value: 10,
    );
  }

  return VoiceAssistantVolumeRequest(
    to: lower.contains('to'),
    turnUp: !RegExp(r'lower|down', caseSensitive: false).hasMatch(text),
    percentage: fraction != null || half || quarter || text.contains('%'),
    value:
        fraction != null
            ? _fractionToDouble(fraction)
            : half
            ? 50
            : quarter
            ? 25
            : number!.toDouble(),
  );
}

VoiceAssistantVolumeRequest _parseChineseVolumeRequest(String text) {
  final fraction = _firstFraction(text);
  final number = _firstVoiceNumber(text);
  final half = text.contains('一半');

  if (number == null && fraction == null && !half) {
    return VoiceAssistantVolumeRequest(
      to: false,
      turnUp: !text.contains('低'),
      percentage: false,
      value: 10,
    );
  }

  return VoiceAssistantVolumeRequest(
    to: text.contains('至') || text.contains('到') || text.contains('成'),
    turnUp: !text.contains('低'),
    percentage: fraction != null || half || text.contains('%'),
    value:
        fraction != null
            ? _fractionToDouble(fraction)
            : half
            ? 50
            : number!.toDouble(),
  );
}

VoiceAssistantVolumeRequest _parseLocalizedVolumeRequest(
  String text,
  Map<String, List<String>> lexicon,
) {
  final fraction = _firstFraction(text);
  final number = _firstVoiceNumber(text);
  final half = _containsAny(text, const [
    'half',
    'demi',
    'halb',
    'medio',
    'metade',
    'metà',
    'полов',
    '半分',
    'setengah',
  ]);

  if (number == null && fraction == null && !half) {
    return VoiceAssistantVolumeRequest(
      to: false,
      turnUp: !_containsAny(text, lexicon['volumeDown']!),
      percentage: false,
      value: 10,
    );
  }

  return VoiceAssistantVolumeRequest(
    to: _containsAny(text, lexicon['volumeTo']!),
    turnUp: !_containsAny(text, lexicon['volumeDown']!),
    percentage:
        fraction != null ||
        half ||
        text.contains('%') ||
        _containsAny(text, lexicon['percent']!),
    value:
        fraction != null
            ? _fractionToDouble(fraction)
            : half
            ? 50
            : number!.toDouble(),
  );
}

Map<String, List<String>> _normalizeLocalizedLexicon(
  Map<String, List<String>> lexicon,
) {
  return lexicon.map(
    (key, values) =>
        MapEntry(key, values.map(_normalizeLocalizedText).toList()),
  );
}

String _normalizeLocalizedText(String value) {
  return _removeLocalizedDiacritics(value)
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'''[，。！？、,.!?;:()[\]{}"“”'’]'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _removeLocalizedDiacritics(String value) {
  const replacements = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ā': 'a',
    'ă': 'a',
    'ą': 'a',
    'ç': 'c',
    'ć': 'c',
    'č': 'c',
    'ď': 'd',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ė': 'e',
    'ę': 'e',
    'ě': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ī': 'i',
    'ł': 'l',
    'ñ': 'n',
    'ń': 'n',
    'ň': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ō': 'o',
    'ř': 'r',
    'š': 's',
    'ś': 's',
    'ť': 't',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ū': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ž': 'z',
    'ź': 'z',
    'ż': 'z',
  };
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    final replacement = replacements[lower];
    buffer.write(
      replacement == null || char == lower
          ? replacement ?? char
          : replacement.toUpperCase(),
    );
  }
  return buffer.toString();
}

bool _containsAny(String text, List<String> values) {
  return values.any(text.contains);
}

String? _remainderAfterAny(String text, List<String> values) {
  for (final value in values) {
    if (text == value) {
      return '';
    }

    if (text.startsWith('$value ')) {
      return text.substring(value.length).trim();
    }

    final infix = ' $value ';
    final index = text.indexOf(infix);
    if (index >= 0) {
      return text.substring(index + infix.length).trim();
    }
  }

  return null;
}

String? _firstFraction(String text) {
  return RegExp(r'\d+/\d+').firstMatch(text)?.group(0);
}

num? _firstVoiceNumber(String text) {
  final value = RegExp(r'\d+').firstMatch(text)?.group(0);
  return value == null ? null : num.parse(value);
}

double _fractionToDouble(String fraction) {
  final values = fraction.split('/').map(num.parse).toList();
  return values.first / values.last;
}

VoiceAssistantCommandResult? _parseEnglishPlayMusicIn(
  String command,
  String patternPrefix,
) {
  final value = _playMusicInValue(command, patternPrefix);
  if (value == null) {
    return null;
  }

  final lower = value.toLowerCase();
  final splitter =
      lower.contains(' in ')
          ? ' in '
          : lower.contains(' from ')
          ? ' from '
          : ' of ';
  final request = VoiceAssistantSplitRequest.parse(value, splitter);
  final target = request.right.toLowerCase();

  if (target.contains('album')) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playMusicInAlbum,
      request: request,
    );
  }

  if (target.contains('playlist')) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playMusicInPlaylist,
      request: request,
    );
  }

  if (target.contains('folder')) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.playMusicInFolder,
      request: request,
    );
  }

  return VoiceAssistantCommandResult(
    VoiceAssistantMatchType.playMusicIn,
    request: request,
  );
}

String? _playMusicInValue(String command, String patternPrefix) {
  final pattern =
      patternPrefix == 'play .*music'
          ? RegExp(
            r'^play .*music\s+(.+ (in|from|of) .+)$',
            caseSensitive: false,
          )
          : RegExp(r'^play\s+(.+ (in|from|of) .+)$', caseSensitive: false);
  final value = pattern.firstMatch(command)?.group(1);
  if (value == null) {
    return null;
  }
  return _trimVoiceValue(value);
}

String? _matchValue(String text, RegExp pattern) {
  final value = pattern.firstMatch(text)?.group(0);
  if (value == null) {
    return null;
  }
  return _trimVoiceValue(value);
}

String _trimVoiceValue(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'^[\s:：,，。.!！?？"“”‘’《》]+'), '')
      .replaceAll(RegExp(r'[\s"“”‘’《》]+$'), '')
      .trim();
}
