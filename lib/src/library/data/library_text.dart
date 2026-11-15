import 'package:lpinyin/lpinyin.dart';
import 'library_text_sort_key.dart';
export 'library_text_sort_key.dart';

const artistQuickJumpKeys = [
  '#',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];
String getArtistQuickJumpBucket(String artistName) {
  final trimmed = artistName.trim();
  if (trimmed.isEmpty) {
    return '#';
  }

  final firstChar = trimmed.substring(0, 1);
  final first = _foldLatinFirstChar(firstChar).toUpperCase();
  if (RegExp(r'^[A-Z]$').hasMatch(first)) {
    return first;
  }

  if (!_isCjkUnifiedIdeograph(firstChar)) {
    return '#';
  }

  final electronBucketOverride =
      _electronCjkQuickJumpBucketOverrides[firstChar];
  if (electronBucketOverride != null) {
    return electronBucketOverride;
  }

  final pinyin =
      PinyinHelper.getPinyinE(
        firstChar,
        separator: '',
        defPinyin: '',
        format: PinyinFormat.WITHOUT_TONE,
      ).toUpperCase();
  return pinyin.isNotEmpty && RegExp(r'^[A-Z]$').hasMatch(pinyin[0])
      ? pinyin[0]
      : '#';
}

const _electronCjkQuickJumpBucketOverrides = {
  // Electron's zh-Hans-CN-u-co-pinyin collator places this polyphonic
  // character at the Z boundary.
  '长': 'Z',
};

String _foldLatinFirstChar(String value) {
  const folded = {
    'À': 'A',
    'Á': 'A',
    'Â': 'A',
    'Ã': 'A',
    'Ä': 'A',
    'Å': 'A',
    'Ā': 'A',
    'Ă': 'A',
    'Ą': 'A',
    'Ç': 'C',
    'Ć': 'C',
    'Ĉ': 'C',
    'Ċ': 'C',
    'Č': 'C',
    'Ď': 'D',
    'È': 'E',
    'É': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Ē': 'E',
    'Ĕ': 'E',
    'Ė': 'E',
    'Ę': 'E',
    'Ě': 'E',
    'Ĝ': 'G',
    'Ğ': 'G',
    'Ġ': 'G',
    'Ģ': 'G',
    'Ĥ': 'H',
    'Ì': 'I',
    'Í': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Ĩ': 'I',
    'Ī': 'I',
    'Ĭ': 'I',
    'Į': 'I',
    'İ': 'I',
    'Ĵ': 'J',
    'Ĺ': 'L',
    'Ļ': 'L',
    'Ľ': 'L',
    'Ñ': 'N',
    'Ń': 'N',
    'Ņ': 'N',
    'Ň': 'N',
    'Ò': 'O',
    'Ó': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'Ö': 'O',
    'Ō': 'O',
    'Ŏ': 'O',
    'Ő': 'O',
    'Ŕ': 'R',
    'Ŗ': 'R',
    'Ř': 'R',
    'Ś': 'S',
    'Ŝ': 'S',
    'Ş': 'S',
    'Š': 'S',
    'Ţ': 'T',
    'Ť': 'T',
    'Ù': 'U',
    'Ú': 'U',
    'Û': 'U',
    'Ü': 'U',
    'Ũ': 'U',
    'Ū': 'U',
    'Ŭ': 'U',
    'Ů': 'U',
    'Ű': 'U',
    'Ų': 'U',
    'Ŵ': 'W',
    'Ý': 'Y',
    'Ŷ': 'Y',
    'Ÿ': 'Y',
    'Ź': 'Z',
    'Ż': 'Z',
    'Ž': 'Z',
  };
  return folded[value.toUpperCase()] ?? value;
}

ArtistTextSortKey buildArtistTextSortKey(String value) {
  return ArtistTextSortKey(
    bucketIndex: artistQuickJumpKeys.indexOf(getArtistQuickJumpBucket(value)),
    pinyinKey: _baseCollationKey(_pinyinCompareKey(value)),
    baseKey: _baseCollationKey(value),
  );
}

int compareArtistTextSortKeys(ArtistTextSortKey left, ArtistTextSortKey right) {
  return left.compareTo(right);
}

int compareArtistText(String left, String right) {
  return compareArtistTextSortKeys(
    buildArtistTextSortKey(left),
    buildArtistTextSortKey(right),
  );
}

int compareLocaleText(String left, String right) {
  final cjkCompare = _localeCjkGroup(left).compareTo(_localeCjkGroup(right));
  if (cjkCompare != 0) {
    return cjkCompare;
  }

  final keyCompare = _localeCompareKey(
    left,
  ).compareTo(_localeCompareKey(right));
  if (keyCompare != 0) {
    return keyCompare;
  }

  final accentCompare = _accentPriority(left).compareTo(_accentPriority(right));
  if (accentCompare != 0) {
    return accentCompare;
  }

  return _casePriority(left).compareTo(_casePriority(right));
}

bool _isCjkUnifiedIdeograph(String value) {
  final codePoint = value.runes.first;
  return codePoint >= 0x3400 && codePoint <= 0x9fff;
}

String _pinyinCompareKey(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (_isCjkUnifiedIdeograph(character)) {
      buffer.write(
        PinyinHelper.getPinyinE(
          character,
          separator: '',
          defPinyin: character,
          format: PinyinFormat.WITHOUT_TONE,
        ),
      );
    } else {
      buffer.write(character);
    }
  }
  return buffer.toString().toLowerCase();
}

String _localeCompareKey(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (_isCjkUnifiedIdeograph(character)) {
      buffer.write(
        PinyinHelper.getPinyinE(
          character,
          separator: '',
          defPinyin: character,
          format: PinyinFormat.WITHOUT_TONE,
        ),
      );
    } else {
      buffer.write(_foldLatinFirstChar(character));
    }
  }
  return buffer.toString().toLowerCase();
}

String _baseCollationKey(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    buffer.write(_foldLatinFirstChar(String.fromCharCode(rune)));
  }
  return buffer.toString().toLowerCase();
}

int _localeCjkGroup(String value) {
  final trimmed = value.trim();
  return trimmed.isNotEmpty && _isCjkUnifiedIdeograph(trimmed.substring(0, 1))
      ? 0
      : 1;
}

int _accentPriority(String value) {
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (_foldLatinFirstChar(character) != character) {
      return 0;
    }
  }
  return 1;
}

int _casePriority(String value) {
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (character.toLowerCase() == character &&
        character.toUpperCase() != character) {
      return 0;
    }
    if (character.toUpperCase() == character &&
        character.toLowerCase() != character) {
      return 1;
    }
  }
  return 0;
}

int evaluateString(String value, String keyword, [int offset = 0]) {
  if (value.isEmpty) {
    return 0;
  }

  if (value == keyword) {
    return 100 + offset;
  }

  final normalizedValue = value.toLowerCase();
  final normalizedKeyword = keyword.toLowerCase();

  if (normalizedValue == normalizedKeyword) {
    return 95 + offset;
  }

  if (value.startsWith(keyword)) {
    return 90 + offset;
  }

  if (normalizedValue.startsWith(normalizedKeyword)) {
    return 85 + offset;
  }

  if (value.contains(keyword)) {
    return 80 + offset;
  }

  if (normalizedValue.contains(normalizedKeyword)) {
    return 75 + offset;
  }

  if (normalizedKeyword.contains(normalizedValue)) {
    return 70 + offset;
  }

  final distance = _getEditDistance(value, keyword);
  final ratio =
      (distance * 100) ~/
      (value.length > keyword.length ? value.length : keyword.length);
  return ratio <= 60 ? 70 - ratio + offset : 0;
}

int _getEditDistance(String target, String given) {
  final rows = target.length;
  final columns = given.length;
  if (rows * columns == 0) {
    return rows + columns;
  }

  final dp = List.generate(
    rows + 1,
    (rowIndex) => List.generate(
      columns + 1,
      (columnIndex) =>
          rowIndex == 0
              ? columnIndex
              : columnIndex == 0
              ? rowIndex
              : 0,
    ),
  );

  for (var rowIndex = 1; rowIndex <= rows; rowIndex += 1) {
    for (var columnIndex = 1; columnIndex <= columns; columnIndex += 1) {
      final left = dp[rowIndex - 1][columnIndex] + 1;
      final down = dp[rowIndex][columnIndex - 1] + 1;
      final leftDown =
          dp[rowIndex - 1][columnIndex - 1] +
          (target[rowIndex - 1] == given[columnIndex - 1] ? 0 : 1);
      dp[rowIndex][columnIndex] = [
        left,
        down,
        leftDown,
      ].reduce((best, value) => value < best ? value : best);
    }
  }

  return dp[rows][columns];
}
