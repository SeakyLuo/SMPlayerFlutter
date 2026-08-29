import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

part 'id3_tag_service_vorbis.dart';
part 'id3_tag_service_containers.dart';
part 'id3_tag_service_properties.dart';
part 'id3_tag_service_id3_frames.dart';
part 'id3_tag_service_binary.dart';
part 'id3_tag_service_models.dart';

class Id3SongTagProperties {
  const Id3SongTagProperties({
    this.title = '',
    this.subtitle = '',
    this.artist = '',
    this.artists = const [],
    this.album = '',
    this.albumArtist = '',
    this.publisher = '',
    this.trackNumber = 0,
    this.year = 0,
    this.genre = '',
    this.composers = '',
  });

  final String title;
  final String subtitle;
  final String artist;
  final List<String> artists;
  final String album;
  final String albumArtist;
  final String publisher;
  final int trackNumber;
  final int year;
  final String genre;
  final String composers;
}

class Id3Picture {
  const Id3Picture({required this.data, required this.format});

  final Uint8List data;
  final String format;
}

class Id3SongMetadata {
  const Id3SongMetadata({
    this.properties = const Id3SongTagProperties(),
    this.embeddedLyrics = '',
    this.picture,
  });

  final Id3SongTagProperties properties;
  final String embeddedLyrics;
  final Id3Picture? picture;
}

class Id3TagService {
  const Id3TagService();

  Future<Id3SongTagProperties> readSongTagProperties(String songPath) async {
    return (await readSongMetadata(songPath)).properties;
  }

  Future<String> readEmbeddedLyrics(String songPath) async {
    return (await readSongMetadata(songPath)).embeddedLyrics;
  }

  Future<Id3Picture?> readFirstPicture(String songPath) async {
    return (await readSongMetadata(songPath)).picture;
  }

  Future<Id3SongMetadata> readSongMetadata(String songPath) async {
    final bytes = await File(songPath).readAsBytes();
    return readSongMetadataBytes(songPath, bytes);
  }

  Id3SongMetadata readSongMetadataBytes(String songPath, Uint8List bytes) {
    final extension = p.extension(songPath).toLowerCase();
    if (extension == '.flac') {
      final metadata = _readFlacMetadata(bytes);
      return Id3SongMetadata(
        properties: _propertiesFromVorbisComments(metadata.comments),
        embeddedLyrics:
            _firstCommentValue(metadata.comments, [
              'UNSYNCEDLYRICS',
              'LYRICS',
            ]).trim(),
        picture: metadata.picture,
      );
    }
    if (extension == '.ogg' || extension == '.oga' || extension == '.opus') {
      final comments = _readOggComments(bytes);
      return Id3SongMetadata(
        properties: _propertiesFromVorbisComments(comments),
        embeddedLyrics:
            _firstCommentValue(comments, ['UNSYNCEDLYRICS', 'LYRICS']).trim(),
        picture: _pictureFromVorbisComments(comments),
      );
    }
    if (extension == '.m4a' ||
        extension == '.mp4' ||
        extension == '.aac' ||
        extension == '.alac') {
      final metadata = _readMp4Metadata(bytes);
      return Id3SongMetadata(
        properties: _propertiesFromMp4Atoms(metadata),
        picture: metadata.picture,
      );
    }
    if (extension == '.wav') {
      final metadata = _readWavMetadata(bytes);
      return Id3SongMetadata(properties: _propertiesFromWavInfo(metadata.info));
    }
    if (extension == '.aiff' || extension == '.aif') {
      final metadata = _readAiffMetadata(bytes);
      return Id3SongMetadata(
        properties: _propertiesFromId3Tag(metadata.tag),
        embeddedLyrics: _embeddedLyricsFromId3Tag(metadata.tag),
        picture: _pictureFromId3Tag(metadata.tag),
      );
    }
    if (extension == '.ape') {
      final metadata = _readApeMetadata(bytes);
      return Id3SongMetadata(
        properties: _propertiesFromApeValues(metadata.values),
        embeddedLyrics:
            _firstApeValue(metadata.values, [
              'LYRICS',
              'UNSYNCEDLYRICS',
              'UNSYNCED LYRICS',
            ]).trim(),
        picture: metadata.picture,
      );
    }
    if (extension == '.wma') {
      final metadata = _readAsfMetadata(bytes);
      return Id3SongMetadata(
        properties: _propertiesFromAsfMetadata(metadata),
        embeddedLyrics:
            _firstAsfValue(metadata.values, ['WM/LYRICS', 'LYRICS']).trim(),
        picture: metadata.picture,
      );
    }
    if (extension != '.mp3') {
      return const Id3SongMetadata();
    }

    final tag = _readId3Tag(bytes);
    return Id3SongMetadata(
      properties: _propertiesFromId3Tag(tag),
      embeddedLyrics: _embeddedLyricsFromId3Tag(tag),
      picture: _pictureFromId3Tag(tag),
    );
  }

  Future<void> writeSongTagProperties(
    String songPath,
    Id3SongTagProperties properties,
  ) async {
    if (p.extension(songPath).toLowerCase() != '.mp3') {
      return;
    }

    final fileBytes = await File(songPath).readAsBytes();
    final existingTag = _readId3Tag(fileBytes);
    final audioBytes = _extractCleanAudioBody(fileBytes, existingTag.endOffset);
    final tagVersion = existingTag.version == 4 ? 4 : 3;
    const replacedFrameIds = {
      'TIT2',
      'TIT3',
      'TPE1',
      'TALB',
      'TPE2',
      'TRCK',
      'TDRC',
      'TYER',
      'TCON',
      'TCOM',
      'TPUB',
    };
    final textFrames =
        [
          _createTextId3Frame(tagVersion, 'TIT2', properties.title),
          _createTextId3Frame(tagVersion, 'TIT3', properties.subtitle),
          _createTextId3Frame(tagVersion, 'TPE1', properties.artist),
          _createTextId3Frame(tagVersion, 'TALB', properties.album),
          _createTextId3Frame(tagVersion, 'TPE2', properties.albumArtist),
          _createTextId3Frame(
            tagVersion,
            'TRCK',
            properties.trackNumber == 0
                ? ''
                : properties.trackNumber.toString(),
          ),
          _createTextId3Frame(
            tagVersion,
            tagVersion == 4 ? 'TDRC' : 'TYER',
            properties.year == 0 ? '' : properties.year.toString(),
          ),
          _createTextId3Frame(tagVersion, 'TCON', properties.genre),
          _createTextId3Frame(tagVersion, 'TCOM', properties.composers),
          _createTextId3Frame(tagVersion, 'TPUB', properties.publisher),
        ].where((frame) => frame.isNotEmpty).toList();
    final preservedFrames =
        existingTag.frames
            .where((frame) => !replacedFrameIds.contains(frame.id))
            .map((frame) => frame.raw)
            .toList();

    await _writeTag(
      songPath,
      tagVersion,
      preservedFrames,
      textFrames,
      audioBytes,
    );
  }

  Future<void> writeEmbeddedLyrics(String songPath, String rawLyrics) async {
    if (p.extension(songPath).toLowerCase() != '.mp3') {
      return;
    }

    final fileBytes = await File(songPath).readAsBytes();
    final existingTag = _readId3Tag(fileBytes);
    final audioBytes = _extractCleanAudioBody(fileBytes, existingTag.endOffset);
    final tagVersion = existingTag.version == 4 ? 4 : 3;
    final preservedFrames =
        existingTag.frames
            .where((frame) => frame.id != 'USLT' && frame.id != 'SYLT')
            .map((frame) => frame.raw)
            .toList();
    final lyricsFrames =
        rawLyrics.trim().isEmpty
            ? <Uint8List>[]
            : [
              _createId3Frame(
                tagVersion,
                'USLT',
                _createUnsynchronizedLyricsPayload(tagVersion, rawLyrics),
              ),
            ];

    await _writeTag(
      songPath,
      tagVersion,
      preservedFrames,
      lyricsFrames,
      audioBytes,
    );
  }

  Future<void> writeSongArtwork(String songPath, Id3Picture? picture) async {
    if (p.extension(songPath).toLowerCase() != '.mp3') {
      return;
    }

    final fileBytes = await File(songPath).readAsBytes();
    final existingTag = _readId3Tag(fileBytes);
    final audioBytes = _extractCleanAudioBody(fileBytes, existingTag.endOffset);
    final tagVersion = existingTag.version == 4 ? 4 : 3;
    final preservedFrames =
        existingTag.frames
            .where((frame) => frame.id != 'APIC')
            .map((frame) => frame.raw)
            .toList();
    final artworkFrames =
        picture == null
            ? <Uint8List>[]
            : [
              _createId3Frame(
                tagVersion,
                'APIC',
                Uint8List.fromList([
                  3,
                  ...ascii.encode(picture.format),
                  0,
                  3,
                  0,
                  ...picture.data,
                ]),
              ),
            ];

    await _writeTag(
      songPath,
      tagVersion,
      preservedFrames,
      artworkFrames,
      audioBytes,
    );
  }
}
