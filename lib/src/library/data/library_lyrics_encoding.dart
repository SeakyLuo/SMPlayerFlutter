import 'dart:convert';
import 'dart:io';

import 'package:gbk_codec/gbk_codec.dart';

/// Local lyrics can be UTF-8 or legacy GBK. Never replace undecodable bytes.
Future<String> readLocalLyricsText(File file) async {
  final bytes = await file.readAsBytes();
  try {
    return utf8.decode(bytes);
  } on FormatException {
    final text = gbk_bytes.decode(bytes);
    final encoded = gbk_bytes.encode(text);
    if (encoded.length != bytes.length) rethrow;
    for (var i = 0; i < bytes.length; i++) {
      if (encoded[i] != bytes[i]) rethrow;
    }
    return text;
  }
}
