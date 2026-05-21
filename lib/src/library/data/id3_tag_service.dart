import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

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

  Future<int> readDurationSeconds(String songPath) async {
    final extension = p.extension(songPath).toLowerCase();
    if (extension == '.flac') {
      final metadata = _readFlacMetadata(await File(songPath).readAsBytes());
      return metadata.durationSeconds;
    }
    if (extension == '.m4a' ||
        extension == '.mp4' ||
        extension == '.aac' ||
        extension == '.alac') {
      final atoms = _readMp4Metadata(await File(songPath).readAsBytes());
      return atoms.durationSeconds;
    }
    if (extension == '.wav') {
      final metadata = _readWavMetadata(await File(songPath).readAsBytes());
      return metadata.durationSeconds;
    }
    if (extension == '.aiff' || extension == '.aif') {
      final metadata = _readAiffMetadata(await File(songPath).readAsBytes());
      return metadata.durationSeconds;
    }
    if (extension == '.wma') {
      final metadata = _readAsfMetadata(await File(songPath).readAsBytes());
      return metadata.durationSeconds;
    }
    if (extension != '.mp3') {
      return 0;
    }

    final fileBytes = await File(songPath).readAsBytes();
    final tag = _readId3Tag(fileBytes);
    return _readMp3DurationSeconds(fileBytes, tag.endOffset);
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

  _FlacMetadata _readFlacMetadata(Uint8List fileBytes) {
    if (fileBytes.length < 4 ||
        ascii.decode(fileBytes.sublist(0, 4), allowInvalid: true) != 'fLaC') {
      return const _FlacMetadata(
        comments: {},
        durationSeconds: 0,
        picture: null,
      );
    }

    final comments = <String, List<String>>{};
    Id3Picture? picture;
    var durationSeconds = 0;
    var offset = 4;
    var lastBlock = false;

    while (!lastBlock && offset + 4 <= fileBytes.length) {
      final header = fileBytes[offset];
      lastBlock = (header & 0x80) != 0;
      final blockType = header & 0x7f;
      final blockLength =
          (fileBytes[offset + 1] << 16) |
          (fileBytes[offset + 2] << 8) |
          fileBytes[offset + 3];
      offset += 4;
      if (offset + blockLength > fileBytes.length) {
        break;
      }
      final block = Uint8List.fromList(
        fileBytes.sublist(offset, offset + blockLength),
      );
      if (blockType == 0 && block.length >= 18) {
        final sampleRate =
            (block[10] << 12) | (block[11] << 4) | (block[12] >> 4);
        final totalSamples =
            ((block[13] & 0x0f) << 32) |
            (block[14] << 24) |
            (block[15] << 16) |
            (block[16] << 8) |
            block[17];
        if (sampleRate > 0 && totalSamples > 0) {
          durationSeconds = (totalSamples / sampleRate).round();
        }
      } else if (blockType == 4) {
        comments.addAll(_readVorbisCommentBlock(block));
      } else if (blockType == 6) {
        picture ??= _readFlacPictureBlock(block);
      }
      offset += blockLength;
    }

    return _FlacMetadata(
      comments: comments,
      durationSeconds: durationSeconds,
      picture: picture ?? _pictureFromVorbisComments(comments),
    );
  }

  Map<String, List<String>> _readOggComments(Uint8List fileBytes) {
    final vorbisOffset = _indexOfBytes(fileBytes, ascii.encode('\x03vorbis'));
    if (vorbisOffset != -1) {
      return _readVorbisCommentBlock(
        Uint8List.fromList(fileBytes.sublist(vorbisOffset + 7)),
      );
    }

    final opusOffset = _indexOfBytes(fileBytes, ascii.encode('OpusTags'));
    if (opusOffset != -1) {
      return _readVorbisCommentBlock(
        Uint8List.fromList(fileBytes.sublist(opusOffset + 8)),
      );
    }

    return const {};
  }

  Map<String, List<String>> _readVorbisCommentBlock(Uint8List block) {
    var offset = 0;
    if (offset + 4 > block.length) {
      return const {};
    }
    final vendorLength = _readUint32Le(block, offset);
    offset += 4 + vendorLength;
    if (offset + 4 > block.length) {
      return const {};
    }
    final commentCount = _readUint32Le(block, offset);
    offset += 4;
    final comments = <String, List<String>>{};
    for (var i = 0; i < commentCount && offset + 4 <= block.length; i += 1) {
      final commentLength = _readUint32Le(block, offset);
      offset += 4;
      if (offset + commentLength > block.length) {
        break;
      }
      final comment = utf8.decode(
        block.sublist(offset, offset + commentLength),
        allowMalformed: true,
      );
      offset += commentLength;
      final separator = comment.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = comment.substring(0, separator).toUpperCase();
      final value = comment.substring(separator + 1).trim();
      if (value.isNotEmpty) {
        comments.putIfAbsent(key, () => []).add(value);
      }
    }
    return comments;
  }

  Id3SongTagProperties _propertiesFromVorbisComments(
    Map<String, List<String>> comments,
  ) {
    return Id3SongTagProperties(
      title: _firstCommentValue(comments, ['TITLE']),
      subtitle: _firstCommentValue(comments, ['SUBTITLE', 'VERSION']),
      artist: _firstCommentValue(comments, ['ARTIST', 'PERFORMER']),
      artists: _commentValues(comments, ['ARTIST', 'PERFORMER']),
      album: _firstCommentValue(comments, ['ALBUM']),
      albumArtist: _firstCommentValue(comments, [
        'ALBUMARTIST',
        'ALBUM ARTIST',
      ]),
      publisher: _firstCommentValue(comments, [
        'PUBLISHER',
        'LABEL',
        'ORGANIZATION',
      ]),
      trackNumber: _readTrackNumber(
        _firstCommentValue(comments, ['TRACKNUMBER', 'TRACK']),
      ),
      year: _readYear(_firstCommentValue(comments, ['DATE', 'YEAR'])),
      genre: _firstCommentValue(comments, ['GENRE']),
      composers: _firstCommentValue(comments, ['COMPOSER']),
    );
  }

  String _firstCommentValue(
    Map<String, List<String>> comments,
    List<String> keys,
  ) {
    for (final key in keys) {
      final values = comments[key];
      if (values != null && values.isNotEmpty) {
        return values.first.trim();
      }
    }
    return '';
  }

  List<String> _commentValues(
    Map<String, List<String>> comments,
    List<String> keys,
  ) {
    return [
      for (final key in keys)
        ...?comments[key]
            ?.map((value) => value.trim())
            .where((value) => value.isNotEmpty),
    ];
  }

  Id3Picture? _readFlacPictureBlock(Uint8List block) {
    var offset = 0;
    if (block.length < 32) {
      return null;
    }
    offset += 4;
    final mimeLength = _readUint32Be(block, offset);
    offset += 4;
    if (offset + mimeLength > block.length) {
      return null;
    }
    final mime = ascii.decode(
      block.sublist(offset, offset + mimeLength),
      allowInvalid: true,
    );
    offset += mimeLength;
    if (offset + 4 > block.length) {
      return null;
    }
    final descriptionLength = _readUint32Be(block, offset);
    offset += 4 + descriptionLength + 16;
    if (offset + 4 > block.length) {
      return null;
    }
    final dataLength = _readUint32Be(block, offset);
    offset += 4;
    if (offset + dataLength > block.length) {
      return null;
    }
    return Id3Picture(
      data: Uint8List.fromList(block.sublist(offset, offset + dataLength)),
      format: mime,
    );
  }

  Id3Picture? _pictureFromVorbisComments(Map<String, List<String>> comments) {
    final pictureValue = _firstCommentValue(comments, [
      'METADATA_BLOCK_PICTURE',
    ]);
    if (pictureValue.isEmpty) {
      return null;
    }
    try {
      return _readFlacPictureBlock(base64.decode(pictureValue));
    } on FormatException {
      return null;
    }
  }

  _Mp4Metadata _readMp4Metadata(Uint8List fileBytes) {
    final atoms = _readMp4Atoms(fileBytes, 0, fileBytes.length);
    final textValues = <String, String>{};
    Id3Picture? picture;
    var durationSeconds = 0;

    for (final atom in atoms) {
      if (atom.path.endsWith('/mvhd')) {
        durationSeconds = _readMp4MovieDuration(atom.payload);
      }
      if (!atom.path.contains('/ilst/')) {
        continue;
      }
      if (atom.type == 'covr') {
        picture ??= _readMp4Cover(atom.payload);
        continue;
      }
      if (atom.type == 'trkn') {
        final track = _readMp4TrackNumber(atom.payload);
        if (track > 0) {
          textValues[atom.type] = track.toString();
        }
        continue;
      }
      final value = _readMp4DataText(atom.payload);
      if (value.isNotEmpty) {
        textValues[atom.type] = value;
      }
    }

    return _Mp4Metadata(
      values: textValues,
      durationSeconds: durationSeconds,
      picture: picture,
    );
  }

  _WavMetadata _readWavMetadata(Uint8List fileBytes) {
    if (fileBytes.length < 12 ||
        ascii.decode(fileBytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(fileBytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      return const _WavMetadata(info: {}, durationSeconds: 0);
    }

    final info = <String, String>{};
    var byteRate = 0;
    var dataBytes = 0;
    var offset = 12;
    while (offset + 8 <= fileBytes.length) {
      final type = ascii.decode(
        fileBytes.sublist(offset, offset + 4),
        allowInvalid: true,
      );
      final size = _readUint32Le(fileBytes, offset + 4);
      final payloadStart = offset + 8;
      final payloadEnd = payloadStart + size;
      if (payloadEnd > fileBytes.length) {
        break;
      }
      final payload = Uint8List.fromList(
        fileBytes.sublist(payloadStart, payloadEnd),
      );
      if (type == 'fmt ' && payload.length >= 16) {
        byteRate = _readUint32Le(payload, 8);
      } else if (type == 'data') {
        dataBytes += size;
      } else if (type == 'LIST' &&
          payload.length >= 4 &&
          ascii.decode(payload.sublist(0, 4), allowInvalid: true) == 'INFO') {
        info.addAll(_readWavInfoList(payload));
      }
      offset = payloadEnd + (size.isOdd ? 1 : 0);
    }

    return _WavMetadata(
      info: info,
      durationSeconds:
          byteRate > 0 && dataBytes > 0 ? (dataBytes / byteRate).round() : 0,
    );
  }

  _AiffMetadata _readAiffMetadata(Uint8List fileBytes) {
    if (fileBytes.length < 12 ||
        ascii.decode(fileBytes.sublist(0, 4), allowInvalid: true) != 'FORM' ||
        ascii.decode(fileBytes.sublist(8, 12), allowInvalid: true) != 'AIFF') {
      return const _AiffMetadata(tag: null, durationSeconds: 0);
    }

    _Id3Tag? tag;
    var durationSeconds = 0;
    var offset = 12;
    while (offset + 8 <= fileBytes.length) {
      final type = ascii.decode(
        fileBytes.sublist(offset, offset + 4),
        allowInvalid: true,
      );
      final size = _readUint32Be(fileBytes, offset + 4);
      final payloadStart = offset + 8;
      final payloadEnd = payloadStart + size;
      if (payloadEnd > fileBytes.length) {
        break;
      }
      final payload = Uint8List.fromList(
        fileBytes.sublist(payloadStart, payloadEnd),
      );
      if (type == 'COMM' && payload.length >= 18) {
        final sampleFrames = _readUint32Be(payload, 2);
        final sampleRate = _readAiffExtendedSampleRate(payload, 8);
        if (sampleFrames > 0 && sampleRate > 0) {
          durationSeconds = (sampleFrames / sampleRate).round();
        }
      } else if (type.trim() == 'ID3') {
        final id3Tag = _readId3Tag(payload);
        if (id3Tag.frames.isNotEmpty) {
          tag ??= id3Tag;
        }
      }
      offset = payloadEnd + (size.isOdd ? 1 : 0);
    }

    return _AiffMetadata(tag: tag, durationSeconds: durationSeconds);
  }

  int _readAiffExtendedSampleRate(Uint8List payload, int offset) {
    if (offset + 10 > payload.length) {
      return 0;
    }

    final exponent = ((payload[offset] & 0x7f) << 8) | payload[offset + 1];
    if (exponent == 0) {
      return 0;
    }

    final highMantissa = _readUint32Be(payload, offset + 2);
    final lowMantissa = _readUint32Be(payload, offset + 6);
    final mantissa = highMantissa * 4294967296.0 + lowMantissa;
    final value = mantissa * math.pow(2, exponent - 16383 - 63);
    if (!value.isFinite || value <= 0) {
      return 0;
    }
    return value.round();
  }

  _ApeMetadata _readApeMetadata(Uint8List fileBytes) {
    if (fileBytes.length < 32) {
      return const _ApeMetadata(values: {}, picture: null);
    }

    final footerOffset = fileBytes.length - 32;
    if (ascii.decode(
          fileBytes.sublist(footerOffset, footerOffset + 8),
          allowInvalid: true,
        ) !=
        'APETAGEX') {
      return const _ApeMetadata(values: {}, picture: null);
    }

    final tagSize = _readUint32Le(fileBytes, footerOffset + 12);
    final itemCount = _readUint32Le(fileBytes, footerOffset + 16);
    final flags = _readUint32Le(fileBytes, footerOffset + 20);
    final hasHeader = (flags & 0x80000000) != 0;
    var offset = footerOffset - tagSize + 32;
    if (hasHeader) {
      offset += 32;
    }
    if (tagSize < 32 || offset < 0 || offset > footerOffset) {
      return const _ApeMetadata(values: {}, picture: null);
    }

    final values = <String, List<String>>{};
    Id3Picture? picture;
    for (
      var index = 0;
      index < itemCount && offset + 8 <= footerOffset;
      index += 1
    ) {
      final valueSize = _readUint32Le(fileBytes, offset);
      final itemFlags = _readUint32Le(fileBytes, offset + 4);
      offset += 8;

      final keyStart = offset;
      while (offset < footerOffset && fileBytes[offset] != 0) {
        offset += 1;
      }
      if (offset >= footerOffset) {
        break;
      }
      final key =
          latin1
              .decode(fileBytes.sublist(keyStart, offset), allowInvalid: true)
              .trim();
      offset += 1;

      final valueEnd = offset + valueSize;
      if (valueEnd > footerOffset) {
        break;
      }
      final valueBytes = Uint8List.fromList(
        fileBytes.sublist(offset, valueEnd),
      );
      offset = valueEnd;

      final normalizedKey = key.toUpperCase();
      final itemType = (itemFlags >> 1) & 0x03;
      if (itemType == 0) {
        final value =
            utf8
                .decode(valueBytes, allowMalformed: true)
                .replaceAll('\u0000', '; ')
                .trim();
        if (value.isNotEmpty) {
          values.putIfAbsent(normalizedKey, () => []).add(value);
        }
      } else if (picture == null && normalizedKey == 'COVER ART (FRONT)') {
        picture = _readApeCoverArt(valueBytes);
      }
    }

    return _ApeMetadata(values: values, picture: picture);
  }

  Id3Picture? _readApeCoverArt(Uint8List valueBytes) {
    var dataOffset = 0;
    while (dataOffset < valueBytes.length && valueBytes[dataOffset] != 0) {
      dataOffset += 1;
    }
    if (dataOffset >= valueBytes.length - 1) {
      return null;
    }
    dataOffset += 1;
    final data = Uint8List.fromList(valueBytes.sublist(dataOffset));
    return Id3Picture(data: data, format: _imageMimeTypeFromBytes(data));
  }

  _AsfMetadata _readAsfMetadata(Uint8List fileBytes) {
    if (fileBytes.length < 30 || !_matchesGuid(fileBytes, 0, _asfHeaderGuid)) {
      return const _AsfMetadata(values: {}, durationSeconds: 0, picture: null);
    }

    final headerSize = _readUint64Le(fileBytes, 16);
    final objectCount = _readUint32Le(fileBytes, 24);
    final headerEnd = math.min(fileBytes.length, headerSize);
    final values = <String, List<String>>{};
    Id3Picture? picture;
    var durationSeconds = 0;
    var offset = 30;

    for (
      var index = 0;
      index < objectCount && offset + 24 <= headerEnd;
      index += 1
    ) {
      final objectSize = _readUint64Le(fileBytes, offset + 16);
      final objectEnd = offset + objectSize;
      if (objectSize < 24 || objectEnd > headerEnd) {
        break;
      }
      final payloadOffset = offset + 24;
      final payloadLength = objectSize - 24;
      if (_matchesGuid(fileBytes, offset, _asfFilePropertiesGuid)) {
        durationSeconds = _readAsfDurationSeconds(
          fileBytes,
          payloadOffset,
          payloadLength,
        );
      } else if (_matchesGuid(fileBytes, offset, _asfContentDescriptionGuid)) {
        values.addAll(
          _readAsfContentDescription(fileBytes, payloadOffset, payloadLength),
        );
      } else if (_matchesGuid(
        fileBytes,
        offset,
        _asfExtendedContentDescriptionGuid,
      )) {
        final extended = _readAsfExtendedContentDescription(
          fileBytes,
          payloadOffset,
          payloadLength,
        );
        for (final entry in extended.values.entries) {
          values.putIfAbsent(entry.key, () => []).addAll(entry.value);
        }
        picture ??= extended.picture;
      }
      offset = objectEnd;
    }

    return _AsfMetadata(
      values: values,
      durationSeconds: durationSeconds,
      picture: picture,
    );
  }

  int _readAsfDurationSeconds(Uint8List bytes, int offset, int length) {
    if (length < 64) {
      return 0;
    }
    final playDuration = _readUint64Le(bytes, offset + 40);
    final preroll = _readUint64Le(bytes, offset + 56);
    if (playDuration <= 0) {
      return 0;
    }
    return math.max(0, (playDuration / 10000000 - preroll / 1000).round());
  }

  Map<String, List<String>> _readAsfContentDescription(
    Uint8List bytes,
    int offset,
    int length,
  ) {
    if (length < 10) {
      return const {};
    }
    final keys = ['TITLE', 'ARTIST', 'COPYRIGHT', 'DESCRIPTION', 'RATING'];
    final lengths = [
      for (var index = 0; index < 5; index += 1)
        _readUint16Le(bytes, offset + index * 2),
    ];
    final values = <String, List<String>>{};
    var valueOffset = offset + 10;
    final endOffset = offset + length;
    for (var index = 0; index < keys.length; index += 1) {
      final valueLength = lengths[index];
      final valueEnd = valueOffset + valueLength;
      if (valueEnd > endOffset) {
        break;
      }
      final value = _decodeAsfUtf16(bytes, valueOffset, valueEnd).trim();
      if (value.isNotEmpty) {
        values[keys[index]] = [value];
      }
      valueOffset = valueEnd;
    }
    return values;
  }

  _AsfExtendedMetadata _readAsfExtendedContentDescription(
    Uint8List bytes,
    int offset,
    int length,
  ) {
    final endOffset = offset + length;
    if (length < 2) {
      return const _AsfExtendedMetadata(values: {}, picture: null);
    }
    final values = <String, List<String>>{};
    Id3Picture? picture;
    final descriptorCount = _readUint16Le(bytes, offset);
    var descriptorOffset = offset + 2;
    for (
      var index = 0;
      index < descriptorCount && descriptorOffset + 6 <= endOffset;
      index += 1
    ) {
      final nameLength = _readUint16Le(bytes, descriptorOffset);
      descriptorOffset += 2;
      final nameEnd = descriptorOffset + nameLength;
      if (nameEnd + 4 > endOffset) {
        break;
      }
      final name = _decodeAsfUtf16(bytes, descriptorOffset, nameEnd).trim();
      descriptorOffset = nameEnd;
      final valueType = _readUint16Le(bytes, descriptorOffset);
      final valueLength = _readUint16Le(bytes, descriptorOffset + 2);
      descriptorOffset += 4;
      final valueEnd = descriptorOffset + valueLength;
      if (valueEnd > endOffset) {
        break;
      }
      final normalizedName = name.toUpperCase();
      if (valueType == 0) {
        final value = _decodeAsfUtf16(bytes, descriptorOffset, valueEnd).trim();
        if (value.isNotEmpty) {
          values.putIfAbsent(normalizedName, () => []).add(value);
        }
      } else if (picture == null &&
          valueType == 1 &&
          normalizedName == 'WM/PICTURE') {
        picture = _readAsfPicture(
          Uint8List.fromList(bytes.sublist(descriptorOffset, valueEnd)),
        );
      }
      descriptorOffset = valueEnd;
    }
    return _AsfExtendedMetadata(values: values, picture: picture);
  }

  Id3Picture? _readAsfPicture(Uint8List bytes) {
    if (bytes.length < 5) {
      return null;
    }
    final dataLength = _readUint32Le(bytes, 1);
    var offset = 5;
    final mimeEnd = _findUtf16Null(bytes, offset);
    if (mimeEnd == -1) {
      return null;
    }
    final mime = _decodeAsfUtf16(bytes, offset, mimeEnd).trim();
    offset = mimeEnd + 2;
    final descriptionEnd = _findUtf16Null(bytes, offset);
    if (descriptionEnd == -1) {
      return null;
    }
    offset = descriptionEnd + 2;
    if (offset + dataLength > bytes.length) {
      return null;
    }
    final data = Uint8List.fromList(bytes.sublist(offset, offset + dataLength));
    return Id3Picture(
      data: data,
      format: mime.isEmpty ? _imageMimeTypeFromBytes(data) : mime,
    );
  }

  Map<String, String> _readWavInfoList(Uint8List payload) {
    final values = <String, String>{};
    var offset = 4;
    while (offset + 8 <= payload.length) {
      final key = ascii.decode(
        payload.sublist(offset, offset + 4),
        allowInvalid: true,
      );
      final size = _readUint32Le(payload, offset + 4);
      final valueStart = offset + 8;
      final valueEnd = valueStart + size;
      if (valueEnd > payload.length) {
        break;
      }
      final value =
          utf8
              .decode(
                payload.sublist(valueStart, valueEnd),
                allowMalformed: true,
              )
              .replaceAll('\u0000', '')
              .trim();
      if (value.isNotEmpty) {
        values[key] = value;
      }
      offset = valueEnd + (size.isOdd ? 1 : 0);
    }
    return values;
  }

  List<_Mp4Atom> _readMp4Atoms(
    Uint8List bytes,
    int start,
    int end, [
    String path = '',
  ]) {
    final atoms = <_Mp4Atom>[];
    var offset = start;
    while (offset + 8 <= end && offset + 8 <= bytes.length) {
      var atomSize = _readUint32Be(bytes, offset);
      final type = latin1.decode(
        bytes.sublist(offset + 4, offset + 8),
        allowInvalid: true,
      );
      var payloadOffset = offset + 8;
      if (atomSize == 1 && offset + 16 <= end) {
        atomSize = _readUint64Be(bytes, offset + 8);
        payloadOffset = offset + 16;
      }
      if (atomSize < payloadOffset - offset || offset + atomSize > end) {
        break;
      }
      final atomEnd = offset + atomSize;
      final atomPath = '$path/$type';
      final payload = Uint8List.fromList(bytes.sublist(payloadOffset, atomEnd));
      atoms.add(_Mp4Atom(type: type, path: atomPath, payload: payload));
      final childStart = type == 'meta' ? payloadOffset + 4 : payloadOffset;
      if (_mp4ContainerAtomTypes.contains(type) && childStart < atomEnd) {
        atoms.addAll(_readMp4Atoms(bytes, childStart, atomEnd, atomPath));
      }
      offset = atomEnd;
    }
    return atoms;
  }

  int _readMp4MovieDuration(Uint8List payload) {
    if (payload.length < 20) {
      return 0;
    }
    final version = payload[0];
    if (version == 1) {
      if (payload.length < 32) {
        return 0;
      }
      final timescale = _readUint32Be(payload, 20);
      final duration = _readUint64Be(payload, 24);
      return timescale > 0 ? (duration / timescale).round() : 0;
    }
    final timescale = _readUint32Be(payload, 12);
    final duration = _readUint32Be(payload, 16);
    return timescale > 0 ? (duration / timescale).round() : 0;
  }

  Id3SongTagProperties _propertiesFromMp4Atoms(_Mp4Metadata metadata) {
    return Id3SongTagProperties(
      title: metadata.values['©nam'] ?? '',
      subtitle: metadata.values['desc'] ?? metadata.values['©des'] ?? '',
      artist: metadata.values['©ART'] ?? '',
      artists: _singleArtistValue(metadata.values['©ART'] ?? ''),
      album: metadata.values['©alb'] ?? '',
      albumArtist: metadata.values['aART'] ?? '',
      publisher: metadata.values['cprt'] ?? '',
      trackNumber: int.tryParse(metadata.values['trkn'] ?? '') ?? 0,
      year: _readYear(metadata.values['©day'] ?? ''),
      genre: metadata.values['©gen'] ?? '',
      composers: metadata.values['©wrt'] ?? '',
    );
  }

  Id3SongTagProperties _propertiesFromWavInfo(Map<String, String> info) {
    final yearText = info['ICRD'] ?? '';
    return Id3SongTagProperties(
      title: info['INAM'] ?? '',
      artist: info['IART'] ?? '',
      artists: _singleArtistValue(info['IART'] ?? ''),
      album: info['IPRD'] ?? '',
      year: _readYear(yearText),
      genre: info['IGNR'] ?? '',
      composers: info['ICMT'] ?? '',
    );
  }

  Id3SongTagProperties _propertiesFromApeValues(
    Map<String, List<String>> values,
  ) {
    return Id3SongTagProperties(
      title: _firstApeValue(values, ['TITLE']),
      subtitle: _firstApeValue(values, ['SUBTITLE', 'VERSION']),
      artist: _firstApeValue(values, ['ARTIST']),
      artists: _apeValues(values, ['ARTIST']),
      album: _firstApeValue(values, ['ALBUM']),
      albumArtist: _firstApeValue(values, ['ALBUM ARTIST', 'ALBUMARTIST']),
      publisher: _firstApeValue(values, ['PUBLISHER', 'LABEL']),
      trackNumber: _readTrackNumber(
        _firstApeValue(values, ['TRACK', 'TRACKNUMBER']),
      ),
      year: _readYear(_firstApeValue(values, ['DATE', 'YEAR'])),
      genre: _firstApeValue(values, ['GENRE']),
      composers: _firstApeValue(values, ['COMPOSER']),
    );
  }

  Id3SongTagProperties _propertiesFromAsfMetadata(_AsfMetadata metadata) {
    return Id3SongTagProperties(
      title: _firstAsfValue(metadata.values, ['TITLE']),
      subtitle: _firstAsfValue(metadata.values, ['WM/SUBTITLE', 'DESCRIPTION']),
      artist: _firstAsfValue(metadata.values, ['ARTIST', 'WM/AUTHOR']),
      artists: _asfValues(metadata.values, ['ARTIST', 'WM/AUTHOR']),
      album: _firstAsfValue(metadata.values, ['WM/ALBUMTITLE']),
      albumArtist: _firstAsfValue(metadata.values, [
        'WM/ALBUMARTIST',
        'WM/ALBUM ARTIST',
      ]),
      publisher: _firstAsfValue(metadata.values, ['WM/PUBLISHER']),
      trackNumber: _readTrackNumber(
        _firstAsfValue(metadata.values, ['WM/TRACKNUMBER', 'WM/TRACK']),
      ),
      year: _readYear(_firstAsfValue(metadata.values, ['WM/YEAR', 'WM/DATE'])),
      genre: _firstAsfValue(metadata.values, ['WM/GENRE']),
      composers: _firstAsfValue(metadata.values, ['WM/COMPOSER']),
    );
  }

  String _firstAsfValue(Map<String, List<String>> values, List<String> keys) {
    for (final key in keys) {
      final itemValues = values[key];
      if (itemValues != null && itemValues.isNotEmpty) {
        return itemValues.first.trim();
      }
    }
    return '';
  }

  List<String> _asfValues(Map<String, List<String>> values, List<String> keys) {
    return [
      for (final key in keys)
        ...?values[key]
            ?.map((value) => value.trim())
            .where((value) => value.isNotEmpty),
    ];
  }

  String _firstApeValue(Map<String, List<String>> values, List<String> keys) {
    for (final key in keys) {
      final itemValues = values[key];
      if (itemValues != null && itemValues.isNotEmpty) {
        return itemValues.first.trim();
      }
    }
    return '';
  }

  List<String> _apeValues(Map<String, List<String>> values, List<String> keys) {
    return [
      for (final key in keys)
        ...?values[key]
            ?.map((value) => value.trim())
            .where((value) => value.isNotEmpty),
    ];
  }

  Id3SongTagProperties _propertiesFromId3Tag(_Id3Tag? tag) {
    if (tag == null) {
      return const Id3SongTagProperties();
    }

    final artistValues = _readTextFrameValues(tag, 'TPE1');
    return Id3SongTagProperties(
      title: _readTextFrame(tag, 'TIT2'),
      subtitle: _readTextFrame(tag, 'TIT3'),
      artist: artistValues.join(', '),
      artists: artistValues,
      album: _readTextFrame(tag, 'TALB'),
      albumArtist: _readTextFrame(tag, 'TPE2'),
      publisher: _readTextFrame(tag, 'TPUB'),
      trackNumber: int.tryParse(_readTextFrame(tag, 'TRCK')) ?? 0,
      year:
          int.tryParse(
            _readTextFrame(tag, tag.version == 4 ? 'TDRC' : 'TYER'),
          ) ??
          0,
      genre: _readTextFrame(tag, 'TCON'),
      composers: _readTextFrame(tag, 'TCOM'),
    );
  }

  String _embeddedLyricsFromId3Tag(_Id3Tag? tag) {
    if (tag == null) {
      return '';
    }

    final unsynchronizedLyrics =
        tag.frames.where((frame) => frame.id == 'USLT').firstOrNull;
    if (unsynchronizedLyrics != null) {
      return _readUnsynchronizedLyrics(unsynchronizedLyrics.payload).trim();
    }

    return '';
  }

  Id3Picture? _pictureFromId3Tag(_Id3Tag? tag) {
    final artworkFrame =
        tag?.frames.where((frame) => frame.id == 'APIC').firstOrNull;
    if (artworkFrame == null || artworkFrame.payload.length < 5) {
      return null;
    }

    final payload = artworkFrame.payload;
    var offset = 1;
    while (offset < payload.length && payload[offset] != 0) {
      offset += 1;
    }
    final format = ascii.decode(payload.sublist(1, offset), allowInvalid: true);
    offset += 2;
    final encoding = payload[0];
    if (encoding == 1 || encoding == 2) {
      while (offset + 1 < payload.length) {
        if (payload[offset] == 0 && payload[offset + 1] == 0) {
          offset += 2;
          break;
        }
        offset += 2;
      }
    } else {
      while (offset < payload.length) {
        if (payload[offset] == 0) {
          offset += 1;
          break;
        }
        offset += 1;
      }
    }

    if (offset >= payload.length) {
      return null;
    }

    return Id3Picture(
      data: Uint8List.fromList(payload.sublist(offset)),
      format: format,
    );
  }

  String _imageMimeTypeFromBytes(Uint8List data) {
    if (data.length >= 4 &&
        data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4e &&
        data[3] == 0x47) {
      return 'image/png';
    }
    if (data.length >= 2 && data[0] == 0xff && data[1] == 0xd8) {
      return 'image/jpeg';
    }
    if (data.length >= 3 &&
        ascii.decode(data.sublist(0, 3), allowInvalid: true) == 'GIF') {
      return 'image/gif';
    }
    return 'application/octet-stream';
  }

  String _readMp4DataText(Uint8List payload) {
    for (final data in _readMp4DataPayloads(payload)) {
      if (data.length <= 8) {
        continue;
      }
      return utf8.decode(data.sublist(8), allowMalformed: true).trim();
    }
    return '';
  }

  int _readMp4TrackNumber(Uint8List payload) {
    for (final data in _readMp4DataPayloads(payload)) {
      if (data.length >= 12) {
        return (data[10] << 8) | data[11];
      }
      if (data.length >= 10) {
        return (data[8] << 8) | data[9];
      }
    }
    return 0;
  }

  Id3Picture? _readMp4Cover(Uint8List payload) {
    for (final data in _readMp4DataPayloads(payload)) {
      if (data.length <= 8) {
        continue;
      }
      final flags = _readUint32Be(data, 0) & 0x00ffffff;
      final format = flags == 14 ? 'image/png' : 'image/jpeg';
      return Id3Picture(
        data: Uint8List.fromList(data.sublist(8)),
        format: format,
      );
    }
    return null;
  }

  List<Uint8List> _readMp4DataPayloads(Uint8List payload) {
    final values = <Uint8List>[];
    var offset = 0;
    while (offset + 8 <= payload.length) {
      final atomSize = _readUint32Be(payload, offset);
      if (atomSize < 8 || offset + atomSize > payload.length) {
        break;
      }
      final type = latin1.decode(
        payload.sublist(offset + 4, offset + 8),
        allowInvalid: true,
      );
      if (type == 'data') {
        values.add(
          Uint8List.fromList(payload.sublist(offset + 8, offset + atomSize)),
        );
      }
      offset += atomSize;
    }
    return values;
  }

  int _readTrackNumber(String value) {
    if (value.isEmpty) {
      return 0;
    }
    return int.tryParse(value.split('/').first.trim()) ?? 0;
  }

  List<String> _singleArtistValue(String value) {
    final artist = value.trim();
    return artist.isEmpty ? const [] : [artist];
  }

  int _readYear(String value) {
    if (value.length < 4) {
      return 0;
    }
    return int.tryParse(value.substring(0, 4)) ?? 0;
  }

  int _indexOfBytes(Uint8List bytes, List<int> pattern) {
    for (var offset = 0; offset + pattern.length <= bytes.length; offset += 1) {
      var matches = true;
      for (var index = 0; index < pattern.length; index += 1) {
        if (bytes[offset + index] != pattern[index]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return offset;
      }
    }
    return -1;
  }

  bool _matchesGuid(Uint8List bytes, int offset, List<int> guid) {
    if (offset + guid.length > bytes.length) {
      return false;
    }
    for (var index = 0; index < guid.length; index += 1) {
      if (bytes[offset + index] != guid[index]) {
        return false;
      }
    }
    return true;
  }

  String _decodeAsfUtf16(Uint8List bytes, int start, int end) {
    var actualEnd = end;
    while (actualEnd - start >= 2 &&
        bytes[actualEnd - 2] == 0 &&
        bytes[actualEnd - 1] == 0) {
      actualEnd -= 2;
    }
    return _decodeUtf16(
      Uint8List.fromList(bytes.sublist(start, actualEnd)),
      bigEndian: false,
    );
  }

  int _findUtf16Null(Uint8List bytes, int start) {
    for (var offset = start; offset + 1 < bytes.length; offset += 2) {
      if (bytes[offset] == 0 && bytes[offset + 1] == 0) {
        return offset;
      }
    }
    return -1;
  }

  Future<void> _writeTag(
    String songPath,
    int tagVersion,
    List<Uint8List> preservedFrames,
    List<Uint8List> newFrames,
    Uint8List audioBytes,
  ) async {
    final tagBody = Uint8List.fromList([
      for (final frame in preservedFrames) ...frame,
      for (final frame in newFrames) ...frame,
    ]);
    final padding = Uint8List(2048);
    final header = Uint8List(10);
    header.setRange(0, 3, ascii.encode('ID3'));
    header[3] = tagVersion;
    _writeSynchsafeSize(header, 6, tagBody.length + padding.length);

    await File(
      songPath,
    ).writeAsBytes([...header, ...tagBody, ...padding, ...audioBytes]);
  }

  _Id3Tag _readId3Tag(Uint8List fileBytes) {
    if (fileBytes.length < 10 ||
        ascii.decode(fileBytes.sublist(0, 3), allowInvalid: true) != 'ID3') {
      return const _Id3Tag(version: 3, endOffset: 0, frames: []);
    }

    final tagSize = _readSynchsafeSize(fileBytes, 6);
    final endOffset = 10 + tagSize;
    final version = fileBytes[3];
    final frames = <_Id3Frame>[];
    var offset = 10;

    while (offset + 10 <= endOffset && offset + 10 <= fileBytes.length) {
      final frameHeader = fileBytes.sublist(offset, offset + 10);
      final id = ascii.decode(frameHeader.sublist(0, 4), allowInvalid: true);
      if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(id)) {
        break;
      }

      final frameSize =
          version == 4
              ? _readSynchsafeSize(frameHeader, 4)
              : _readUint32Be(frameHeader, 4);
      if (frameSize <= 0 ||
          offset + 10 + frameSize > endOffset ||
          offset + 10 + frameSize > fileBytes.length) {
        break;
      }

      final raw = Uint8List.fromList(
        fileBytes.sublist(offset, offset + 10 + frameSize),
      );
      frames.add(
        _Id3Frame(
          id: id,
          raw: raw,
          payload: Uint8List.fromList(raw.sublist(10)),
        ),
      );
      offset += 10 + frameSize;
    }

    return _Id3Tag(version: version, endOffset: endOffset, frames: frames);
  }

  int _readMp3DurationSeconds(Uint8List fileBytes, int startOffset) {
    final headerOffset = _findFirstMpegFrameHeader(fileBytes, startOffset);
    if (headerOffset == -1) {
      return 0;
    }

    final xingDuration = _readXingDurationSeconds(fileBytes, headerOffset);
    if (xingDuration > 0) {
      return xingDuration;
    }

    final bitrateKbps = _readMpegBitrateKbps(
      fileBytes[headerOffset + 1],
      fileBytes[headerOffset + 2],
    );
    if (bitrateKbps <= 0) {
      return 0;
    }

    final audioByteLength = fileBytes.length - headerOffset;
    return (audioByteLength * 8 / (bitrateKbps * 1000)).round();
  }

  int _readXingDurationSeconds(Uint8List fileBytes, int headerOffset) {
    if (headerOffset + 48 > fileBytes.length) {
      return 0;
    }

    final secondHeaderByte = fileBytes[headerOffset + 1];
    final thirdHeaderByte = fileBytes[headerOffset + 2];
    final fourthHeaderByte = fileBytes[headerOffset + 3];
    final version = (secondHeaderByte >> 3) & 0x03;
    final layer = (secondHeaderByte >> 1) & 0x03;
    if (version == 1 || layer != 1) {
      return 0;
    }

    final sampleRate = _readMpegSampleRate(version, thirdHeaderByte);
    if (sampleRate <= 0) {
      return 0;
    }

    final channelMode = (fourthHeaderByte >> 6) & 0x03;
    final xingOffset =
        version == 3
            ? (channelMode == 3 ? 21 : 36)
            : (channelMode == 3 ? 13 : 21);
    final xingStart = headerOffset + xingOffset;
    if (xingStart + 12 > fileBytes.length) {
      return 0;
    }

    final marker = ascii.decode(
      fileBytes.sublist(xingStart, xingStart + 4),
      allowInvalid: true,
    );
    if (marker != 'Xing' && marker != 'Info') {
      return 0;
    }

    final flags = _readUint32Be(fileBytes, xingStart + 4);
    if ((flags & 0x01) == 0) {
      return 0;
    }
    final frameCount = _readUint32Be(fileBytes, xingStart + 8);
    if (frameCount <= 0) {
      return 0;
    }

    final samplesPerFrame = version == 3 ? 1152 : 576;
    return (frameCount * samplesPerFrame / sampleRate).round();
  }

  int _findFirstMpegFrameHeader(Uint8List fileBytes, int startOffset) {
    for (
      var index = startOffset.clamp(0, fileBytes.length);
      index + 3 < fileBytes.length;
      index += 1
    ) {
      if (fileBytes[index] != 0xff || (fileBytes[index + 1] & 0xe0) != 0xe0) {
        continue;
      }
      if (_readMpegBitrateKbps(fileBytes[index + 1], fileBytes[index + 2]) >
          0) {
        return index;
      }
    }
    return -1;
  }

  int _readMpegBitrateKbps(int secondHeaderByte, int thirdHeaderByte) {
    final version = (secondHeaderByte >> 3) & 0x03;
    final layer = (secondHeaderByte >> 1) & 0x03;
    final bitrateIndex = (thirdHeaderByte >> 4) & 0x0f;
    if (version == 1 ||
        layer != 1 ||
        bitrateIndex == 0 ||
        bitrateIndex == 0x0f) {
      return 0;
    }

    const mpeg1Layer3Bitrates = [
      0,
      32,
      40,
      48,
      56,
      64,
      80,
      96,
      112,
      128,
      160,
      192,
      224,
      256,
      320,
    ];
    const mpeg2Layer3Bitrates = [
      0,
      8,
      16,
      24,
      32,
      40,
      48,
      56,
      64,
      80,
      96,
      112,
      128,
      144,
      160,
    ];
    return version == 3
        ? mpeg1Layer3Bitrates[bitrateIndex]
        : mpeg2Layer3Bitrates[bitrateIndex];
  }

  int _readMpegSampleRate(int version, int thirdHeaderByte) {
    final sampleRateIndex = (thirdHeaderByte >> 2) & 0x03;
    if (sampleRateIndex == 0x03) {
      return 0;
    }
    const mpeg1SampleRates = [44100, 48000, 32000];
    const mpeg2SampleRates = [22050, 24000, 16000];
    const mpeg25SampleRates = [11025, 12000, 8000];
    return switch (version) {
      3 => mpeg1SampleRates[sampleRateIndex],
      2 => mpeg2SampleRates[sampleRateIndex],
      0 => mpeg25SampleRates[sampleRateIndex],
      _ => 0,
    };
  }

  Uint8List _extractCleanAudioBody(Uint8List fileBytes, int id3v2EndOffset) {
    var endIndex = fileBytes.length;
    var stripped = true;

    while (stripped && endIndex > id3v2EndOffset) {
      stripped = false;

      if (endIndex - id3v2EndOffset >= 128 &&
          ascii.decode(
                fileBytes.sublist(endIndex - 128, endIndex - 125),
                allowInvalid: true,
              ) ==
              'TAG') {
        endIndex -= 128;
        stripped = true;
        continue;
      }

      if (endIndex - id3v2EndOffset >= 32 &&
          ascii.decode(
                fileBytes.sublist(endIndex - 32, endIndex - 24),
                allowInvalid: true,
              ) ==
              'APETAGEX') {
        final apeSize = _readUint32Le(fileBytes, endIndex - 32 + 12);
        final apeFlags = _readUint32Le(fileBytes, endIndex - 32 + 20);
        final hasHeader = (apeFlags & 0x80000000) != 0;
        final totalLength = apeSize + (hasHeader ? 32 : 0);
        if (totalLength > 0 && endIndex - totalLength >= id3v2EndOffset) {
          endIndex -= totalLength;
          stripped = true;
        }
      }
    }

    return Uint8List.fromList(fileBytes.sublist(id3v2EndOffset, endIndex));
  }

  Uint8List _createId3Frame(int version, String id, Uint8List payload) {
    final frame = Uint8List(10 + payload.length);
    frame.setRange(0, 4, ascii.encode(id));
    if (version == 4) {
      _writeSynchsafeSize(frame, 4, payload.length);
    } else {
      _writeUint32Be(frame, 4, payload.length);
    }
    frame.setRange(10, 10 + payload.length, payload);
    return frame;
  }

  Uint8List _createTextId3Frame(int version, String id, String text) {
    final value = text.trim();
    if (value.isEmpty) {
      return Uint8List(0);
    }

    return _createId3Frame(
      version,
      id,
      _createEncodedTextPayload(version, value),
    );
  }

  Uint8List _createUnsynchronizedLyricsPayload(int version, String rawLyrics) {
    if (version == 4) {
      return Uint8List.fromList([
        3,
        ...ascii.encode('eng'),
        0,
        ...utf8.encode(rawLyrics),
      ]);
    }

    return Uint8List.fromList([
      1,
      ...ascii.encode('eng'),
      0xff,
      0xfe,
      0,
      0,
      0xff,
      0xfe,
      ..._utf16LeBytes(rawLyrics),
    ]);
  }

  Uint8List _createEncodedTextPayload(int version, String value) {
    if (version == 4) {
      return Uint8List.fromList([3, ...utf8.encode(value)]);
    }

    return Uint8List.fromList([1, 0xff, 0xfe, ..._utf16LeBytes(value)]);
  }

  String _readTextFrame(_Id3Tag tag, String frameId) {
    final frame = tag.frames.where((frame) => frame.id == frameId).firstOrNull;
    if (frame == null || frame.payload.isEmpty) {
      return '';
    }

    return _decodeEncodedText(frame.payload).trim();
  }

  List<String> _readTextFrameValues(_Id3Tag tag, String frameId) {
    final frame = tag.frames.where((frame) => frame.id == frameId).firstOrNull;
    if (frame == null || frame.payload.isEmpty) {
      return const [];
    }
    return _decodeEncodedTextValues(frame.payload);
  }

  List<String> _decodeEncodedTextValues(Uint8List payload) {
    if (payload.isEmpty) {
      return const [];
    }

    final encoding = payload[0];
    final data = payload.sublist(1);
    final text =
        encoding == 1
            ? _decodeUtf16WithNullsFromBom(data)
            : encoding == 2
            ? _decodeUtf16WithNulls(data, bigEndian: true)
            : encoding == 3
            ? utf8.decode(data, allowMalformed: true)
            : latin1.decode(data, allowInvalid: true);
    return text
        .split('\u0000')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String _readUnsynchronizedLyrics(Uint8List payload) {
    if (payload.length <= 4) {
      return '';
    }

    final encoding = payload[0];
    var offset = 4;
    if (encoding == 1 || encoding == 2) {
      while (offset + 1 < payload.length) {
        if (payload[offset] == 0 && payload[offset + 1] == 0) {
          offset += 2;
          break;
        }
        offset += 2;
      }
    } else {
      while (offset < payload.length) {
        if (payload[offset] == 0) {
          offset += 1;
          break;
        }
        offset += 1;
      }
    }

    return _decodeEncodedText(
      Uint8List.fromList([encoding, ...payload.sublist(offset)]),
    );
  }

  String _decodeEncodedText(Uint8List payload) {
    if (payload.isEmpty) {
      return '';
    }

    final encoding = payload[0];
    final data = payload.sublist(1);
    if (encoding == 1) {
      final hasBom = data.length >= 2;
      final bigEndian = hasBom && data[0] == 0xfe && data[1] == 0xff;
      final start =
          hasBom && ((data[0] == 0xff && data[1] == 0xfe) || bigEndian) ? 2 : 0;
      return _decodeUtf16(data.sublist(start), bigEndian: bigEndian);
    }
    if (encoding == 2) {
      return _decodeUtf16(data, bigEndian: true);
    }
    if (encoding == 3) {
      return utf8.decode(data, allowMalformed: true);
    }

    return latin1.decode(data, allowInvalid: true);
  }

  String _decodeUtf16(Uint8List bytes, {required bool bigEndian}) {
    final codeUnits = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final codeUnit =
          bigEndian
              ? (bytes[i] << 8) | bytes[i + 1]
              : bytes[i] | (bytes[i + 1] << 8);
      if (codeUnit == 0) {
        continue;
      }
      codeUnits.add(codeUnit);
    }
    return String.fromCharCodes(codeUnits);
  }

  String _decodeUtf16WithNullsFromBom(Uint8List bytes) {
    final hasBom = bytes.length >= 2;
    final bigEndian = hasBom && bytes[0] == 0xfe && bytes[1] == 0xff;
    final start =
        hasBom && ((bytes[0] == 0xff && bytes[1] == 0xfe) || bigEndian) ? 2 : 0;
    return _decodeUtf16WithNulls(bytes.sublist(start), bigEndian: bigEndian);
  }

  String _decodeUtf16WithNulls(Uint8List bytes, {required bool bigEndian}) {
    final codeUnits = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      codeUnits.add(
        bigEndian
            ? (bytes[i] << 8) | bytes[i + 1]
            : bytes[i] | (bytes[i + 1] << 8),
      );
    }
    return String.fromCharCodes(codeUnits);
  }

  Uint8List _utf16LeBytes(String value) {
    final bytes = BytesBuilder();
    for (final codeUnit in value.codeUnits) {
      bytes.addByte(codeUnit & 0xff);
      bytes.addByte((codeUnit >> 8) & 0xff);
    }
    return bytes.toBytes();
  }

  int _readSynchsafeSize(Uint8List buffer, int offset) {
    return (buffer[offset] << 21) |
        (buffer[offset + 1] << 14) |
        (buffer[offset + 2] << 7) |
        buffer[offset + 3];
  }

  void _writeSynchsafeSize(Uint8List buffer, int offset, int size) {
    buffer[offset] = (size >> 21) & 0x7f;
    buffer[offset + 1] = (size >> 14) & 0x7f;
    buffer[offset + 2] = (size >> 7) & 0x7f;
    buffer[offset + 3] = size & 0x7f;
  }

  int _readUint32Be(Uint8List buffer, int offset) {
    return (buffer[offset] << 24) |
        (buffer[offset + 1] << 16) |
        (buffer[offset + 2] << 8) |
        buffer[offset + 3];
  }

  int _readUint32Le(Uint8List buffer, int offset) {
    return buffer[offset] |
        (buffer[offset + 1] << 8) |
        (buffer[offset + 2] << 16) |
        (buffer[offset + 3] << 24);
  }

  int _readUint16Le(Uint8List buffer, int offset) {
    return buffer[offset] | (buffer[offset + 1] << 8);
  }

  int _readUint64Be(Uint8List buffer, int offset) {
    var value = 0;
    for (var index = 0; index < 8; index += 1) {
      value = (value << 8) | buffer[offset + index];
    }
    return value;
  }

  int _readUint64Le(Uint8List buffer, int offset) {
    var value = 0;
    for (var index = 7; index >= 0; index -= 1) {
      value = (value << 8) | buffer[offset + index];
    }
    return value;
  }

  void _writeUint32Be(Uint8List buffer, int offset, int value) {
    buffer[offset] = (value >> 24) & 0xff;
    buffer[offset + 1] = (value >> 16) & 0xff;
    buffer[offset + 2] = (value >> 8) & 0xff;
    buffer[offset + 3] = value & 0xff;
  }
}

class _Id3Tag {
  const _Id3Tag({
    required this.version,
    required this.endOffset,
    required this.frames,
  });

  final int version;
  final int endOffset;
  final List<_Id3Frame> frames;
}

class _Id3Frame {
  const _Id3Frame({required this.id, required this.raw, required this.payload});

  final String id;
  final Uint8List raw;
  final Uint8List payload;
}

class _FlacMetadata {
  const _FlacMetadata({
    required this.comments,
    required this.durationSeconds,
    required this.picture,
  });

  final Map<String, List<String>> comments;
  final int durationSeconds;
  final Id3Picture? picture;
}

class _Mp4Metadata {
  const _Mp4Metadata({
    required this.values,
    required this.durationSeconds,
    required this.picture,
  });

  final Map<String, String> values;
  final int durationSeconds;
  final Id3Picture? picture;
}

class _WavMetadata {
  const _WavMetadata({required this.info, required this.durationSeconds});

  final Map<String, String> info;
  final int durationSeconds;
}

class _AiffMetadata {
  const _AiffMetadata({required this.tag, required this.durationSeconds});

  final _Id3Tag? tag;
  final int durationSeconds;
}

class _ApeMetadata {
  const _ApeMetadata({required this.values, required this.picture});

  final Map<String, List<String>> values;
  final Id3Picture? picture;
}

class _AsfMetadata {
  const _AsfMetadata({
    required this.values,
    required this.durationSeconds,
    required this.picture,
  });

  final Map<String, List<String>> values;
  final int durationSeconds;
  final Id3Picture? picture;
}

class _AsfExtendedMetadata {
  const _AsfExtendedMetadata({required this.values, required this.picture});

  final Map<String, List<String>> values;
  final Id3Picture? picture;
}

class _Mp4Atom {
  const _Mp4Atom({
    required this.type,
    required this.path,
    required this.payload,
  });

  final String type;
  final String path;
  final Uint8List payload;
}

const _mp4ContainerAtomTypes = {
  'moov',
  'trak',
  'mdia',
  'minf',
  'stbl',
  'udta',
  'meta',
  'ilst',
};

const _asfHeaderGuid = [
  0x30,
  0x26,
  0xb2,
  0x75,
  0x8e,
  0x66,
  0xcf,
  0x11,
  0xa6,
  0xd9,
  0x00,
  0xaa,
  0x00,
  0x62,
  0xce,
  0x6c,
];
const _asfFilePropertiesGuid = [
  0xa1,
  0xdc,
  0xab,
  0x8c,
  0x47,
  0xa9,
  0xcf,
  0x11,
  0x8e,
  0xe4,
  0x00,
  0xc0,
  0x0c,
  0x20,
  0x53,
  0x65,
];
const _asfContentDescriptionGuid = [
  0x33,
  0x26,
  0xb2,
  0x75,
  0x8e,
  0x66,
  0xcf,
  0x11,
  0xa6,
  0xd9,
  0x00,
  0xaa,
  0x00,
  0x62,
  0xce,
  0x6c,
];
const _asfExtendedContentDescriptionGuid = [
  0x40,
  0xa4,
  0xd0,
  0xd2,
  0x07,
  0xe3,
  0xd2,
  0x11,
  0x97,
  0xf0,
  0x00,
  0xa0,
  0xc9,
  0x5e,
  0xa8,
  0x50,
];
