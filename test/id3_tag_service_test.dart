import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/data/id3_tag_service.dart';

void main() {
  test('Id3TagService writes song properties, lyrics, and artwork', () async {
    final directory = await Directory.systemTemp.createTemp('smplayer_id3_');
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}${Platform.pathSeparator}song.mp3');
    await songFile.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);

    const service = Id3TagService();
    await service.writeSongTagProperties(
      songFile.path,
      const Id3SongTagProperties(
        title: 'Title',
        subtitle: 'Subtitle',
        artist: 'Artist',
        album: 'Album',
        albumArtist: 'Album Artist',
        publisher: 'Publisher',
        trackNumber: 7,
        year: 2026,
        genre: 'Pop',
        composers: 'Composer',
      ),
    );
    await service.writeEmbeddedLyrics(songFile.path, '[00:01.00]Line');
    await service.writeSongArtwork(
      songFile.path,
      Id3Picture(
        data: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
        format: 'image/png',
      ),
    );

    final properties = await service.readSongTagProperties(songFile.path);
    final lyrics = await service.readEmbeddedLyrics(songFile.path);
    final picture = await service.readFirstPicture(songFile.path);

    expect(properties.title, 'Title');
    expect(properties.subtitle, 'Subtitle');
    expect(properties.artist, 'Artist');
    expect(properties.album, 'Album');
    expect(properties.albumArtist, 'Album Artist');
    expect(properties.publisher, 'Publisher');
    expect(properties.trackNumber, 7);
    expect(properties.year, 2026);
    expect(properties.genre, 'Pop');
    expect(properties.composers, 'Composer');
    expect(lyrics, '[00:01.00]Line');
    expect(picture?.format, 'image/png');
    expect(picture?.data, [0x89, 0x50, 0x4e, 0x47]);
  });
}
