import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';

void main() {
  test('externalAudioPathsFromArgs keeps existing audio files only', () {
    final directory = Directory.systemTemp.createTempSync('smplayer-open-');
    addTearDown(() {
      directory.deleteSync(recursive: true);
    });
    final audioFile = File('${directory.path}/song.mp3')..writeAsStringSync('');
    final textFile = File('${directory.path}/note.txt')..writeAsStringSync('');

    expect(externalAudioPathsFromArgs([audioFile.path, textFile.path]), [
      audioFile.path,
    ]);
  });

  test('externalAppCommandsFromArgs parses smplayer protocol commands', () {
    final commands = externalAppCommandsFromArgs([
      'smplayer://command/play-pause',
      'smplayer://quick-play',
      'smplayer://command?name=toggle-desktop-lyrics',
      'https://example.com',
    ]);

    expect(commands.map((command) => command.kind), [
      ExternalAppCommandKind.playPause,
      ExternalAppCommandKind.quickPlay,
      ExternalAppCommandKind.toggleDesktopLyrics,
    ]);
  });
}
