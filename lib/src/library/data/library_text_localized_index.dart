part of 'library_text.dart';

enum LibraryIndex {
  standard,
  japanese,
  russian,
  ukrainian,
  spanish,
  czech,
  swedish;

  static LibraryIndex forLocale(String locale) => switch (locale) {
    'ja' => japanese,
    'ru' => russian,
    'uk' => ukrainian,
    'es' => spanish,
    'cs' => czech,
    'sv' => swedish,
    _ => standard,
  };
}

const _latinIndex = 'A B C D E F G H I J K L M N O P Q R S T U V W X Y Z';
const _localizedAlphabets = {
  LibraryIndex.russian:
      'А Б В Г Д Е Ж З И Й К Л М Н О П Р С Т У Ф Х Ц Ч Ш Щ Ы Э Ю Я $_latinIndex',
  LibraryIndex.ukrainian:
      'А Б В Г Ґ Д Е Є Ж З И І Ї Й К Л М Н О П Р С Т У Ф Х Ц Ч Ш Щ Ю Я $_latinIndex',
  LibraryIndex.spanish: 'A B C D E F G H I J K L M N Ñ O P Q R S T U V W X Y Z',
  LibraryIndex.czech:
      'A B C Č D E F G H CH I J K L M N O P Q R Ř S Š T U V W X Y Z Ž',
  LibraryIndex.swedish: '$_latinIndex Å Ä Ö',
};

final _localizedQuickJumpKeys = {
  for (final entry in _localizedAlphabets.entries)
    entry.key: List<String>.unmodifiable([...entry.value.split(' '), '#']),
};

final _localizedLetterWeights = {
  for (final entry in _localizedQuickJumpKeys.entries)
    entry.key: {
      for (final (index, letter) in entry.value.indexed) letter: 0xe000 + index,
    },
};

const _indexCompositions = {
  'A\u030a': 'Å',
  'A\u0308': 'Ä',
  'O\u0308': 'Ö',
  'N\u0303': 'Ñ',
  'C\u030c': 'Č',
  'R\u030c': 'Ř',
  'S\u030c': 'Š',
  'Z\u030c': 'Ž',
  'И\u0306': 'Й',
  'І\u0308': 'Ї',
  'Е\u0308': 'Ё',
};

String _uppercaseIndexLetter(int rune) =>
    String.fromCharCode(
      rune >= 0xff01 && rune <= 0xff5e ? rune - 0xfee0 : rune,
    ).toUpperCase();

Iterable<String> _localizedIndexLetters(String name, LibraryIndex index) sync* {
  final runes = name.trimLeft().runes.toList();
  final weights = _localizedLetterWeights[index]!;
  for (var i = 0; i < runes.length; i++) {
    final rune = runes[i];
    var letter = _uppercaseIndexLetter(rune);

    if (i + 1 < runes.length) {
      final next = runes[i + 1];
      final pair = '$letter${_uppercaseIndexLetter(next)}';
      if (_indexCompositions[pair] case final composed?) {
        letter = composed;
        i++;
      } else if (index == LibraryIndex.czech && pair == 'CH') {
        yield pair;
        i++;
        continue;
      }
    }
    if (letter == 'Ё') letter = 'Е';
    yield weights.containsKey(letter)
        ? letter
        : _foldLatinFirstChar(letter).toUpperCase();
  }
}

String _localizedQuickJumpBucket(String value, LibraryIndex index) {
  final letter = _localizedIndexLetters(value, index).firstOrNull ?? '#';
  return _localizedBucketForLetter(value, letter, index);
}

String _localizedBucketForLetter(
  String value,
  String letter,
  LibraryIndex index,
) =>
    _localizedLetterWeights[index]!.containsKey(letter)
        ? letter
        : _standardQuickJumpBucket(value);

ArtistTextSortKey _localizedTextSortKey(String value, LibraryIndex index) {
  final keys = _localizedQuickJumpKeys[index]!;
  final weights = _localizedLetterWeights[index]!;
  final letters = _localizedIndexLetters(value, index).toList();
  final bucket = _localizedBucketForLetter(
    value,
    letters.firstOrNull ?? '#',
    index,
  );
  final sortText = StringBuffer();
  for (final letter in letters) {
    if (weights[letter] case final weight?) {
      sortText.writeCharCode(weight);
    } else {
      sortText.write(letter);
    }
  }
  return ArtistTextSortKey(
    bucketIndex: keys.indexOf(bucket),
    pinyinParts: const [],
    baseKey: sortText.toString(),
  );
}
