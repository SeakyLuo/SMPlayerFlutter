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

  test('English helper parses Electron volume requests', () {
    final defaultStep = parseEnglishVoiceAssistantCommand('turn down volume');
    expect(defaultStep.type, VoiceAssistantMatchType.changeVolume);
    expect(defaultStep.volumeRequest!.to, isFalse);
    expect(defaultStep.volumeRequest!.turnUp, isFalse);
    expect(defaultStep.volumeRequest!.percentage, isFalse);
    expect(defaultStep.volumeRequest!.value, 10);

    final half = parseEnglishVoiceAssistantCommand('turn up volume by half');
    expect(half.type, VoiceAssistantMatchType.changeVolume);
    expect(half.volumeRequest!.turnUp, isTrue);
    expect(half.volumeRequest!.percentage, isTrue);
    expect(half.volumeRequest!.value, 50);
  });

  test('Chinese helper parses artist music requests for Shell execution', () {
    final artistSongs = parseChineseVoiceAssistantCommand('播放周杰伦的歌');
    expect(artistSongs.type, VoiceAssistantMatchType.playByArtistOrMusic);
    expect(artistSongs.request!.left, isEmpty);
    expect(artistSongs.request!.right, '周杰伦');

    final artistSong = parseChineseVoiceAssistantCommand('播放周杰伦的歌曲晴天');
    expect(artistSong.type, VoiceAssistantMatchType.playByArtistAndMusic);
    expect(artistSong.request!.left, '晴天');
    expect(artistSong.request!.right, '周杰伦');
  });

  test('Chinese helper parses Electron volume requests', () {
    final result = parseChineseVoiceAssistantCommand('音量调低一半');

    expect(result.type, VoiceAssistantMatchType.changeVolume);
    expect(result.volumeRequest!.to, isFalse);
    expect(result.volumeRequest!.turnUp, isFalse);
    expect(result.volumeRequest!.percentage, isTrue);
    expect(result.volumeRequest!.value, 50);
  });

  test('Localized helper uses current locale before English fallback', () {
    final search = parseVoiceAssistantCommand('recherche Blue', 'fr');
    expect(search.type, VoiceAssistantMatchType.search);
    expect(search.value, 'blue');

    final volume = parseVoiceAssistantCommand(
      'augmente le volume à 30 pour cent',
      'fr',
    );
    expect(volume.type, VoiceAssistantMatchType.changeVolume);
    expect(volume.volumeRequest!.to, isTrue);
    expect(volume.volumeRequest!.turnUp, isTrue);
    expect(volume.volumeRequest!.percentage, isTrue);
    expect(volume.volumeRequest!.value, 30);
  });
}
