// ignore_for_file: experimental_member_use

import 'dart:io';
import 'dart:math';

import 'package:just_audio/just_audio.dart';

class LocalAudioFileSource extends StreamAudioSource {
  LocalAudioFileSource(String path)
    : _file = File(path),
      _contentType = _audioContentTypeForPath(path);

  final File _file;
  final String _contentType;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final length = await _file.length();
    final offset = start ?? 0;
    final effectiveEnd = min(end ?? length, length);
    return StreamAudioResponse(
      sourceLength: length,
      contentLength: effectiveEnd - offset,
      offset: offset,
      contentType: _contentType,
      stream: _file.openRead(offset, effectiveEnd),
    );
  }
}

String _audioContentTypeForPath(String path) {
  final dotIndex = path.lastIndexOf('.');
  final extension = dotIndex < 0 ? '' : path.substring(dotIndex).toLowerCase();
  return switch (extension) {
    '.aac' => 'audio/aac',
    '.aiff' || '.aif' => 'audio/aiff',
    '.alac' || '.m4a' || '.mp4' => 'audio/mp4',
    '.ape' => 'audio/ape',
    '.flac' => 'audio/flac',
    '.ogg' || '.oga' || '.opus' => 'audio/ogg',
    '.wav' => 'audio/wav',
    '.wma' => 'audio/x-ms-wma',
    _ => 'audio/mpeg',
  };
}
