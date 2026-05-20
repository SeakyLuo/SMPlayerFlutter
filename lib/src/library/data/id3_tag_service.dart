import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

class Id3SongTagProperties {
  const Id3SongTagProperties({
    this.title = '',
    this.subtitle = '',
    this.artist = '',
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
    if (p.extension(songPath).toLowerCase() != '.mp3') {
      return const Id3SongTagProperties();
    }

    final tag = _readId3Tag(await File(songPath).readAsBytes());
    return Id3SongTagProperties(
      title: _readTextFrame(tag, 'TIT2'),
      subtitle: _readTextFrame(tag, 'TIT3'),
      artist: _readTextFrame(tag, 'TPE1'),
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

  Future<String> readEmbeddedLyrics(String songPath) async {
    if (p.extension(songPath).toLowerCase() != '.mp3') {
      return '';
    }

    final tag = _readId3Tag(await File(songPath).readAsBytes());
    final unsynchronizedLyrics =
        tag.frames.where((frame) => frame.id == 'USLT').firstOrNull;
    if (unsynchronizedLyrics != null) {
      return _readUnsynchronizedLyrics(unsynchronizedLyrics.payload).trim();
    }

    return '';
  }

  Future<Id3Picture?> readFirstPicture(String songPath) async {
    if (p.extension(songPath).toLowerCase() != '.mp3') {
      return null;
    }

    final tag = _readId3Tag(await File(songPath).readAsBytes());
    final artworkFrame =
        tag.frames.where((frame) => frame.id == 'APIC').firstOrNull;
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
