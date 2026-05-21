import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/voice_assistant_model.dart';

void main() {
  test('English helper parses play song by artist like Electron', () {
    final result = parseEnglishVoiceAssistantCommand('play Blue by Artist A');

    expect(result.type, VoiceAssistantMatchType.playByArtist);
    expect(result.request!.left, 'Blue');
    expect(result.request!.right, 'Artist A');
  });

  test('English helper parses play music in album scopes', () {
    final result = parseEnglishVoiceAssistantCommand(
      'play Blue in album Blue Hour',
    );

    expect(result.type, VoiceAssistantMatchType.playMusicInAlbum);
    expect(result.request!.left, 'Blue');
    expect(result.request!.right, 'album Blue Hour');
  });

  test('English helper parses play music from playlist scopes', () {
    final result = parseEnglishVoiceAssistantCommand(
      'play Blue from playlist Mix',
    );

    expect(result.type, VoiceAssistantMatchType.playMusicInPlaylist);
    expect(result.request!.left, 'Blue');
    expect(result.request!.right, 'playlist Mix');
  });

  test('English helper keeps existing command controls', () {
    expect(
      parseEnglishVoiceAssistantCommand('quick play').type,
      VoiceAssistantMatchType.quickPlay,
    );
    expect(
      parseEnglishVoiceAssistantCommand('next song').type,
      VoiceAssistantMatchType.next,
    );
    expect(
      parseEnglishVoiceAssistantCommand('search blue').type,
      VoiceAssistantMatchType.search,
    );
  });
}
