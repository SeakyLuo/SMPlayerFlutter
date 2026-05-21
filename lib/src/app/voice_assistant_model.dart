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
  search,
  mute,
  unMute,
  help,
  nothing,
}

class VoiceAssistantCommandResult {
  const VoiceAssistantCommandResult(this.type, {this.value, this.request});

  final VoiceAssistantMatchType type;
  final String? value;
  final VoiceAssistantSplitRequest? request;
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
