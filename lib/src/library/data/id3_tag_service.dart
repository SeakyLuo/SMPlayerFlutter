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

class Id3TagService {
  const Id3TagService();

  Future<Id3SongTagProperties> readSongTagProperties(String songPath) async {
    final extension = p.extension(songPath).toLowerCase();
    if (extension == '.flac') {
      final metadata = _readFlacMetadata(await File(songPath).readAsBytes());
      return _propertiesFromVorbisComments(metadata.comments);
    }
    if (extension == '.ogg' || extension == '.oga' || extension == '.opus') {
      final comments = _readOggComments(await File(songPath).readAsBytes());
      return _propertiesFromVorbisComments(comments);
    }
    if (extension == '.m4a' ||
        extension == '.mp4' ||
        extension == '.aac' ||
        extension == '.alac') {
      final atoms = _readMp4Metadata(await File(songPath).readAsBytes());
      return _propertiesFromMp4Atoms(atoms);
    }
    if (extension == '.wav') {
      final metadata = _readWavMetadata(await File(songPath).readAsBytes());
      return _propertiesFromWavInfo(metadata.info);
    }
    if (extension == '.aiff' || extension == '.aif') {
      final metadata = _readAiffMetadata(await File(songPath).readAsBytes());
      return _propertiesFromId3Tag(metadata.tag);
    }
    if (extension == '.ape') {
      final metadata = _readApeMetadata(await File(songPath).readAsBytes());
      return _propertiesFromApeValues(metadata.values);
    }
    if (extension == '.wma') {
      final metadata = _readAsfMetadata(await File(songPath).readAsBytes());
      return _propertiesFromAsfMetadata(metadata);
    }
    if (extension != '.mp3') {
      return const Id3SongTagProperties();
    }

    final tag = _readId3Tag(await File(songPath).readAsBytes());
    return _propertiesFromId3Tag(tag);
  }

  Future<String> readEmbeddedLyrics(String songPath) async {
    final extension = p.extension(songPath).toLowerCase();
    if (extension == '.flac') {
      final metadata = _readFlacMetadata(await File(songPath).readAsBytes());
      return _firstCommentValue(metadata.comments, [
        'UNSYNCEDLYRICS',
        'LYRICS',
      ]).trim();
    }
    if (extension == '.ogg' || extension == '.oga' || extension == '.opus') {
      final comments = _readOggComments(await File(songPath).readAsBytes());
      return _firstCommentValue(comments, ['UNSYNCEDLYRICS', 'LYRICS']).trim();
    }
    if (extension == '.aiff' || extension == '.aif') {
      final metadata = _readAiffMetadata(await File(songPath).readAsBytes());
      return _embeddedLyricsFromId3Tag(metadata.tag);
    }
    if (extension == '.ape') {
      final metadata = _readApeMetadata(await File(songPath).readAsBytes());
      return _firstApeValue(metadata.values, [
        'LYRICS',
        'UNSYNCEDLYRICS',
        'UNSYNCED LYRICS',
      ]).trim();
    }
    if (extension == '.wma') {
      final metadata = _readAsfMetadata(await File(songPath).readAsBytes());
      return _firstAsfValue(metadata.values, ['WM/LYRICS', 'LYRICS']).trim();
    }
    if (extension != '.mp3') {
      return '';
    }

    final tag = _readId3Tag(await File(songPath).readAsBytes());
    return _embeddedLyricsFromId3Tag(tag);
  }

  Future<Id3Picture?> readFirstPicture(String songPath) async {
    final extension = p.extension(songPath).toLowerCase();
    if (extension == '.flac') {
      final metadata = _readFlacMetadata(await File(songPath).readAsBytes());
      return metadata.picture;
    }
    if (extension == '.ogg' || extension == '.oga' || extension == '.opus') {
      final comments = _readOggComments(await File(songPath).readAsBytes());
      return _pictureFromVorbisComments(comments);
    }
    if (extension == '.m4a' ||
        extension == '.mp4' ||
        extension == '.aac' ||
        extension == '.alac') {
      final atoms = _readMp4Metadata(await File(songPath).readAsBytes());
      return atoms.picture;
    }
    if (extension == '.aiff' || extension == '.aif') {
      final metadata = _readAiffMetadata(await File(songPath).readAsBytes());
      return _pictureFromId3Tag(metadata.tag);
    }
    if (extension == '.ape') {
      final metadata = _readApeMetadata(await File(songPath).readAsBytes());
      return metadata.picture;
    }
    if (extension == '.wma') {
      final metadata = _readAsfMetadata(await File(songPath).readAsBytes());
      return metadata.picture;
    }
    if (extension != '.mp3') {
      return null;
    }

    final tag = _readId3Tag(await File(songPath).readAsBytes());
    return _pictureFromId3Tag(tag);
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
