part 'voice_assistant_localized_commands.dart';

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

  if (RegExp(r'取消[静靜]音').hasMatch(command)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.unMute);
  }

  if (RegExp(r'[静靜]音').hasMatch(command)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.mute);
  }

  if (command.startsWith('暂停')) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.pause);
  }

  if (RegExp(r'帮助|幫助').hasMatch(command)) {
    return const VoiceAssistantCommandResult(VoiceAssistantMatchType.help);
  }

  final search = _matchValue(command, RegExp(r'(?<=搜索|搜尋).*'));
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

  final playAlbum = _matchValue(command, RegExp(r'(?<=播放专辑|播放專輯).*'));
  if (playAlbum != null) {
    final albumSong = _parseChinesePlayMusicIn(
      command,
      RegExp(r'播放(?:专辑|專輯)(.+)中的(.+)'),
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

  final playPlaylist = _matchValue(
    command,
    RegExp(r'(?<=播放(?:播放列表|播放清單|列表|歌单|歌單)).*'),
  );
  if (playPlaylist != null) {
    final playlistSong = _parseChinesePlayMusicIn(
      command,
      RegExp(r'播放(?:播放列表|播放清單|列表|歌单|歌單)(.+)中的(.+)'),
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

  final playFolder = _matchValue(command, RegExp(r'(?<=播放文件夹|播放資料夾).*'));
  if (playFolder != null) {
    final folderSong = _parseChinesePlayMusicIn(
      command,
      RegExp(r'播放(?:文件夹|資料夾)(.+)中的(.+)'),
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
