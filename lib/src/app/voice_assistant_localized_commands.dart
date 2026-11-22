part of 'voice_assistant_model.dart';

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
  final language = locale.toLowerCase().split('-').first;
  final volumeTerms = normalizedLexicon['volume']!;
  final mentionsVolume =
      language == 'ja'
          ? _containsAny(command, volumeTerms)
          : volumeTerms.any((term) => ' $command '.contains(' $term '));
  if (mentionsVolume) {
    return VoiceAssistantCommandResult(
      VoiceAssistantMatchType.changeVolume,
      volumeRequest: _parseLocalizedVolumeRequest(command, normalizedLexicon),
    );
  }

  final namedPlayback = _matchNamedPlayback(text.trim(), language);
  if (namedPlayback != null) return namedPlayback;

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

final _namedPlaybackPatterns = {
  'de': [
    (
      VoiceAssistantMatchType.playAlbum,
      RegExp(r'^Album (.+) abspielen$', caseSensitive: false),
    ),
    (
      VoiceAssistantMatchType.playArtist,
      RegExp(r'^Musik von (.+) abspielen$', caseSensitive: false),
    ),
  ],
  'ja': [
    (VoiceAssistantMatchType.playAlbum, RegExp(r'^アルバム\s*(.+?)\s*を再生(?:して)?$')),
    (VoiceAssistantMatchType.playArtist, RegExp(r'^(.+?)\s*の曲を再生(?:して)?$')),
    (
      VoiceAssistantMatchType.playArtist,
      RegExp(r'^(?:アーティスト|歌手)\s*(.+?)\s*を再生(?:して)?$'),
    ),
    (
      VoiceAssistantMatchType.playPlaylist,
      RegExp(r'^プレイリスト\s*(.+?)\s*を再生(?:して)?$'),
    ),
    (
      VoiceAssistantMatchType.playFolder,
      RegExp(r'^フォルダー?\s*(.+?)\s*を再生(?:して)?$'),
    ),
    (
      VoiceAssistantMatchType.playMusic,
      RegExp(r'^(?:曲\s+)?(.+?)\s*を再生(?:して)?$'),
    ),
  ],
};

VoiceAssistantCommandResult? _matchNamedPlayback(String text, String language) {
  final patterns = _namedPlaybackPatterns[language];
  if (patterns == null) return null;
  for (final (kind, pattern) in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      return VoiceAssistantCommandResult(
        kind,
        value: _trimVoiceValue(match.group(1)!),
      );
    }
  }
  return null;
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
    'play': [
      'joue',
      'jouer',
      'lis',
      'lire',
      'lance',
      'lancer',
      'mets',
      'mettre',
    ],
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
    'playlist': ['liste de lecture', 'playlist', 'liste'],
    'folder': ['dossier'],
  },
  'ru': {
    'quickPlay': ['быстрое воспроизведение', 'случайная музыка'],
    'play': ['включи', 'воспроизведи', 'воспроизвести', 'проиграй', 'играй'],
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
    'quickPlay': ['schnellwiedergabe', 'schnelle wiedergabe', 'zufallsmusik'],
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
    'playlist': ['lista de reproducao', 'playlist', 'lista'],
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
    'playlist': ['lista de reproduccion', 'playlist', 'lista'],
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
    'quickPlay': ['rychle prehrat', 'rychle prehravani', 'nahodna hudba'],
    'play': ['prehraj', 'prehrat', 'pust', 'spust'],
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
    'playlist': ['seznam skladeb', 'playlist', 'seznam'],
    'folder': ['slozku'],
  },
  'uk': {
    'quickPlay': ['швидке відтворення', 'випадкова музика'],
    'play': ['увімкни', 'відтвори', 'відтворити', 'грай'],
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
    'playlist': ['список відтворення', 'плейлист', 'список'],
    'folder': ['папку'],
  },
  'sv': {
    'quickPlay': ['snabbuppspelning', 'snabb uppspelning', 'slumpad musik'],
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
    'album': ['album', 'albumet'],
    'playlist': ['spellista', 'playlist'],
    'folder': ['mapp'],
  },
  'id': {
    'quickPlay': ['putar cepat', 'pemutaran cepat', 'musik acak'],
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
