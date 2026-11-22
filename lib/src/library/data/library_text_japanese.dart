part of 'library_text.dart';

const _kanaRows = ['あ', 'か', 'さ', 'た', 'な', 'は', 'ま', 'や', 'ら', 'わ'];
final _japaneseQuickJumpKeys = List<String>.unmodifiable([
  ..._kanaRows,
  '他',
  ...artistQuickJumpKeys.skip(1),
  '#',
]);

const _kanaGroups = [
  ['あぁ', 'いぃ', 'うぅゔ', 'えぇ', 'おぉ'],
  ['かがゕ', 'きぎ', 'くぐ', 'けげゖ', 'こご'],
  ['さざ', 'しじ', 'すず', 'せぜ', 'そぞ'],
  ['ただ', 'ちぢ', 'つっづ', 'てで', 'とど'],
  ['な', 'に', 'ぬ', 'ね', 'の'],
  ['はばぱ', 'ひびぴ', 'ふぶぷ', 'へべぺ', 'ほぼぽ'],
  ['ま', 'み', 'む', 'め', 'も'],
  ['やゃ', 'ゆゅ', 'よょ'],
  ['ら', 'り', 'る', 'れ', 'ろ'],
  ['わゎ', 'ゐ', 'ゑ', 'を', 'ん'],
];

final _kanaRowsByCharacter = {
  for (final (row, groups) in _kanaGroups.indexed)
    for (final group in groups)
      for (final rune in group.runes) rune: _kanaRows[row],
};

final _kanaBaseCharacters = {
  for (final groups in _kanaGroups)
    for (final group in groups)
      for (final rune in group.runes) rune: group.runes.first,
};

const _halfwidthKana =
    'をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん';

int _japaneseIndexRune(int rune) {
  if (rune >= 0x30a1 && rune <= 0x30f6) return rune - 0x60;
  if (rune >= 0xff66 && rune <= 0xff9d) {
    return _halfwidthKana.codeUnitAt(rune - 0xff66);
  }
  if (rune >= 0xff01 && rune <= 0xff5e) return rune - 0xfee0;
  return switch (rune) {
    0x30f7 => 0x308f, // ヷ
    0x30f8 => 0x3090, // ヸ
    0x30f9 => 0x3091, // ヹ
    0x30fa => 0x3092, // ヺ
    _ => rune,
  };
}

String _japaneseQuickJumpBucket(String name) {
  final first = name.trimLeft().runes.firstOrNull;
  if (first == null) return '#';

  final rune = _japaneseIndexRune(first);
  final kana = _kanaRowsByCharacter[rune];
  if (kana != null) return kana;

  final character = String.fromCharCode(rune);
  final latin = _foldLatinFirstChar(character).toUpperCase();
  if (RegExp(r'^[A-Z]$').hasMatch(latin)) return latin;
  if (_isCjkUnifiedIdeograph(character) ||
      (rune >= 0xf900 && rune <= 0xfaff) ||
      (rune >= 0x20000 && rune <= 0x323af) ||
      rune == 0x3005 ||
      rune == 0x3007) {
    return '他';
  }
  return '#';
}

ArtistTextSortKey _japaneseTextSortKey(String value) {
  final folded = StringBuffer();
  for (final original in value.trimLeft().runes) {
    final rune = _japaneseIndexRune(original);
    if (rune == 0x3099 || rune == 0x309a || rune == 0xff9e || rune == 0xff9f) {
      continue;
    }
    folded.writeCharCode(_kanaBaseCharacters[rune] ?? rune);
  }
  return ArtistTextSortKey(
    bucketIndex: _japaneseQuickJumpKeys.indexOf(
      _japaneseQuickJumpBucket(value),
    ),
    pinyinParts: const [],
    baseKey: _baseCollationKey(folded.toString()),
  );
}
