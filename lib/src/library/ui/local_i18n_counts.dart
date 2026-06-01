import '../../i18n/app_i18n.dart';

enum _CountUnit { folder, song }

String formatLocalFolderSongCount(SmPlayerI18n i18n, int value) {
  return _formatLocalizedCount(i18n.locale, value, _CountUnit.song);
}

String formatFolderCardStats(
  SmPlayerI18n i18n,
  int folderCount,
  int songCount,
) {
  return '${_formatLocalizedCount(i18n.locale, folderCount, _CountUnit.folder)} · ${formatLocalFolderSongCount(i18n, songCount)}';
}

String _formatLocalizedCount(String locale, int value, _CountUnit unit) {
  final forms = _unitLabels[locale]?[unit] ?? _unitLabels['en-US']![unit]!;
  final category = _pluralCategory(locale, value);
  final unitLabel = forms[category] ?? forms[_PluralCategory.other]!;
  return '$value $unitLabel';
}

enum _PluralCategory { one, few, many, other }

_PluralCategory _pluralCategory(String locale, int value) {
  switch (locale) {
    case 'fr':
      return value == 0 || value == 1
          ? _PluralCategory.one
          : _PluralCategory.other;
    case 'ru':
    case 'uk':
      final mod10 = value % 10;
      final mod100 = value % 100;
      if (mod10 == 1 && mod100 != 11) {
        return _PluralCategory.one;
      }
      if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
        return _PluralCategory.few;
      }
      if (mod10 == 0 ||
          (mod10 >= 5 && mod10 <= 9) ||
          (mod100 >= 11 && mod100 <= 14)) {
        return _PluralCategory.many;
      }
      return _PluralCategory.other;
    case 'cs':
      if (value == 1) {
        return _PluralCategory.one;
      }
      if (value >= 2 && value <= 4) {
        return _PluralCategory.few;
      }
      return _PluralCategory.other;
    default:
      return value == 1 ? _PluralCategory.one : _PluralCategory.other;
  }
}

const _unitLabels = {
  'en-US': {
    _CountUnit.folder: {
      _PluralCategory.one: 'folder',
      _PluralCategory.other: 'folders',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'song',
      _PluralCategory.other: 'songs',
    },
  },
  'zh-CN': {
    _CountUnit.folder: {_PluralCategory.other: '个文件夹'},
    _CountUnit.song: {_PluralCategory.other: '首歌曲'},
  },
  'zh-Hant': {
    _CountUnit.folder: {_PluralCategory.other: '個資料夾'},
    _CountUnit.song: {_PluralCategory.other: '首歌曲'},
  },
  'fr': {
    _CountUnit.folder: {
      _PluralCategory.one: 'dossier',
      _PluralCategory.other: 'dossiers',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'chanson',
      _PluralCategory.other: 'chansons',
    },
  },
  'ru': {
    _CountUnit.folder: {
      _PluralCategory.one: 'папка',
      _PluralCategory.few: 'папки',
      _PluralCategory.many: 'папок',
      _PluralCategory.other: 'папки',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'песня',
      _PluralCategory.few: 'песни',
      _PluralCategory.many: 'песен',
      _PluralCategory.other: 'песни',
    },
  },
  'ja': {
    _CountUnit.folder: {_PluralCategory.other: 'フォルダー'},
    _CountUnit.song: {_PluralCategory.other: '曲'},
  },
  'de': {
    _CountUnit.folder: {
      _PluralCategory.one: 'Ordner',
      _PluralCategory.other: 'Ordner',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'Lied',
      _PluralCategory.other: 'Lieder',
    },
  },
  'pt-BR': {
    _CountUnit.folder: {
      _PluralCategory.one: 'pasta',
      _PluralCategory.other: 'pastas',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'música',
      _PluralCategory.other: 'músicas',
    },
  },
  'es': {
    _CountUnit.folder: {
      _PluralCategory.one: 'carpeta',
      _PluralCategory.other: 'carpetas',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'canción',
      _PluralCategory.other: 'canciones',
    },
  },
  'it': {
    _CountUnit.folder: {
      _PluralCategory.one: 'cartella',
      _PluralCategory.other: 'cartelle',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'brano',
      _PluralCategory.other: 'brani',
    },
  },
  'nl': {
    _CountUnit.folder: {
      _PluralCategory.one: 'map',
      _PluralCategory.other: 'mappen',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'nummer',
      _PluralCategory.other: 'nummers',
    },
  },
  'cs': {
    _CountUnit.folder: {
      _PluralCategory.one: 'složka',
      _PluralCategory.few: 'složky',
      _PluralCategory.other: 'složek',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'skladba',
      _PluralCategory.few: 'skladby',
      _PluralCategory.other: 'skladeb',
    },
  },
  'uk': {
    _CountUnit.folder: {
      _PluralCategory.one: 'папка',
      _PluralCategory.few: 'папки',
      _PluralCategory.many: 'папок',
      _PluralCategory.other: 'папки',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'пісня',
      _PluralCategory.few: 'пісні',
      _PluralCategory.many: 'пісень',
      _PluralCategory.other: 'пісні',
    },
  },
  'sv': {
    _CountUnit.folder: {
      _PluralCategory.one: 'mapp',
      _PluralCategory.other: 'mappar',
    },
    _CountUnit.song: {
      _PluralCategory.one: 'låt',
      _PluralCategory.other: 'låtar',
    },
  },
  'id': {
    _CountUnit.folder: {_PluralCategory.other: 'folder'},
    _CountUnit.song: {_PluralCategory.other: 'lagu'},
  },
};
