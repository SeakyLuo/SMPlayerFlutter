import 'dart:convert';

import 'package:gbk_codec/gbk_codec.dart';

// Some older Chinese ID3 writers stored GBK under the Latin-1 encoding flag.
// Require both the characteristic Latin-1 symbols and a lossless GBK decode;
// a valid Western accented name alone is not evidence of a Chinese tag.
String decodeLegacyId3Text(List<int> bytes) {
  final declaredText = latin1.decode(bytes);
  return _decodeChineseTag(bytes) ?? declaredText;
}

bool hasLegacyId3Mojibake(String text) {
  final bytes = text.codeUnits;
  if (bytes.any((byte) => byte > 0xff)) {
    return false;
  }
  return _decodeChineseTag(bytes) != null;
}

String? _decodeChineseTag(List<int> bytes) {
  var hasMojibakeSymbol = false;
  var pairs = 0;
  for (var index = 0; index < bytes.length; index++) {
    final lead = bytes[index];
    if (lead < 0x80) {
      continue;
    }
    if (lead < 0x81 || lead > 0xfe || index + 1 == bytes.length) {
      return null;
    }
    final trail = bytes[++index];
    if (trail < 0x40 || trail > 0xfe || trail == 0x7f) {
      return null;
    }
    pairs++;
    hasMojibakeSymbol |= _isMojibakeSymbol(lead) || _isMojibakeSymbol(trail);
  }
  if (pairs < 2 || !hasMojibakeSymbol) {
    return null;
  }
  final decoded = gbk_bytes.decode(bytes);
  final hanCount =
      decoded.runes.where((rune) => rune >= 0x4e00 && rune <= 0x9fff).length;
  if (hanCount < 2 || hanCount * 5 < pairs * 4) {
    return null;
  }
  final encoded = gbk_bytes.encode(decoded);
  if (encoded.length != bytes.length ||
      encoded.indexed.any((entry) => entry.$2 != bytes[entry.$1])) {
    return null;
  }
  return decoded;
}

bool _isMojibakeSymbol(int byte) =>
    (byte >= 0x80 && byte <= 0xbf) || byte == 0xd7 || byte == 0xf7;
