part of 'id3_tag_service.dart';

extension _Id3TagServiceId3Frames on Id3TagService {
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
}
