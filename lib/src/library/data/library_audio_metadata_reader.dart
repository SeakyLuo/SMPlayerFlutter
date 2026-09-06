part of 'library_audio_metadata_service.dart';

Future<(Id3SongMetadata, int)> _readAudioFileContents(String path) async {
  final file = await File(path).open();
  try {
    final length = await file.length();
    final extension = p.extension(path).toLowerCase();
    if (extension == '.mp3') {
      return await _readMp3File(file, length, path);
    }
    if (extension == '.wav' || extension == '.aiff' || extension == '.aif') {
      return await _readChunkedAudioFile(
        file,
        length,
        path,
        extension == '.wav',
      );
    }
    final bytes = switch (extension) {
      '.flac' => await _readFlacFile(file, length),
      '.m4a' || '.mp4' || '.aac' || '.alac' => await _readMp4File(file, length),
      '.wma' => await _readAsfFile(file, length),
      '.ape' => await _readApeFile(file, length),
      '.ogg' || '.oga' || '.opus' => await _readOggFile(file, length),
      _ => Uint8List(0),
    };
    return (
      _id3TagService.readSongMetadataBytes(path, bytes),
      _readAudioDurationSecondsFromBytes(path, bytes),
    );
  } finally {
    await file.close();
  }
}

Future<Uint8List> _readAudioRange(
  RandomAccessFile file,
  int offset,
  int length,
) async {
  await file.setPosition(offset);
  final bytes = Uint8List(length);
  var read = 0;
  while (read < length) {
    final count = await file.readInto(bytes, read);
    if (count == 0) throw const FormatException('Truncated audio metadata');
    read += count;
  }
  return bytes;
}

Future<(Id3SongMetadata, int)> _readMp3File(
  RandomAccessFile file,
  int length,
  String path,
) async {
  final header = await _readAudioRange(file, 0, min(10, length));
  final tagEnd = _readId3EndOffset(header);
  final tag = await _readAudioRange(file, 0, min(tagEnd, length));
  final metadata = _id3TagService.readSongMetadataBytes(path, tag);
  var offset = min(tagEnd, length);
  const chunkSize = 64 * 1024;
  while (offset + 3 < length) {
    final bytes = await _readAudioRange(
      file,
      offset,
      min(chunkSize, length - offset),
    );
    final frame = _findFirstMpegFrameHeader(bytes, 0);
    if (frame != -1) {
      final frameOffset = offset + frame;
      final frameHeader = await _readAudioRange(
        file,
        frameOffset,
        min(128, length - frameOffset),
      );
      final xingDuration = _readXingDurationSeconds(frameHeader, 0);
      final bitrate = _readMpegBitrateKbps(frameHeader[1], frameHeader[2]);
      final duration =
          xingDuration > 0
              ? xingDuration
              : ((length - frameOffset) * 8 / (bitrate * 1000)).round();
      return (metadata, duration);
    }
    offset += bytes.length - 3;
  }
  return (metadata, 0);
}

Future<Uint8List> _readFlacFile(RandomAccessFile file, int length) async {
  final signature = await _readAudioRange(file, 0, min(4, length));
  if (signature.length != 4 ||
      ascii.decode(signature, allowInvalid: true) != 'fLaC') {
    return Uint8List(0);
  }
  final output = BytesBuilder(copy: false)..add(signature);
  var offset = 4;
  while (offset + 4 <= length) {
    final header = await _readAudioRange(file, offset, 4);
    final size = (header[1] << 16) | (header[2] << 8) | header[3];
    if (offset + 4 + size > length) break;
    final type = header[0] & 0x7f;
    if (type == 0 || type == 4 || type == 6) {
      output.add(header);
      output.add(await _readAudioRange(file, offset + 4, size));
    }
    offset += 4 + size;
    if ((header[0] & 0x80) != 0) break;
  }
  return output.takeBytes();
}

Future<Uint8List> _readMp4File(RandomAccessFile file, int length) async {
  var offset = 0;
  while (offset + 8 <= length) {
    final header = await _readAudioRange(
      file,
      offset,
      min(16, length - offset),
    );
    var size = _readAudioUint32Be(header, 0);
    var headerSize = 8;
    if (size == 1) {
      if (header.length < 16) break;
      size = _readAudioUint64Be(header, 8);
      headerSize = 16;
    } else if (size == 0) {
      size = length - offset;
    }
    if (size < headerSize || offset + size > length) break;
    final type = ascii.decode(
      Uint8List.sublistView(header, 4, 8),
      allowInvalid: true,
    );
    if (type == 'moov') {
      // Media data is outside moov; seek over mdat even when it precedes tags.
      return _readAudioRange(file, offset, size);
    }
    offset += size;
  }
  return Uint8List(0);
}

Future<(Id3SongMetadata, int)> _readChunkedAudioFile(
  RandomAccessFile file,
  int length,
  String path,
  bool wav,
) async {
  final header = await _readAudioRange(file, 0, min(12, length));
  if (header.length < 12 ||
      ascii.decode(Uint8List.sublistView(header, 0, 4), allowInvalid: true) !=
          (wav ? 'RIFF' : 'FORM') ||
      ascii.decode(Uint8List.sublistView(header, 8, 12), allowInvalid: true) !=
          (wav ? 'WAVE' : 'AIFF')) {
    return (const Id3SongMetadata(), 0);
  }
  final output = BytesBuilder(copy: false)..add(header);
  var offset = 12;
  var byteRate = 0;
  var dataSize = 0;
  while (offset + 8 <= length) {
    final chunk = await _readAudioRange(file, offset, 8);
    final type = ascii.decode(
      Uint8List.sublistView(chunk, 0, 4),
      allowInvalid: true,
    );
    final size =
        wav ? _readAudioUint32Le(chunk, 4) : _readAudioUint32Be(chunk, 4);
    final end = offset + 8 + size;
    if (end > length) break;
    final keep =
        wav
            ? type == 'LIST' || type == 'fmt '
            : type == 'COMM' || type.trim() == 'ID3';
    if (keep) {
      final payload = await _readAudioRange(file, offset + 8, size);
      output
        ..add(chunk)
        ..add(payload);
      if (size.isOdd) output.addByte(0);
      if (wav && type == 'fmt ' && size >= 16) {
        byteRate = _readAudioUint32Le(payload, 8);
      }
    } else if (wav && type == 'data') {
      dataSize += size;
    }
    offset = end + (size.isOdd ? 1 : 0);
  }
  final bytes = output.takeBytes();
  return (
    _id3TagService.readSongMetadataBytes(path, bytes),
    wav
        ? (byteRate > 0 ? (dataSize / byteRate).round() : 0)
        : _readAiffDurationSeconds(bytes),
  );
}

Future<Uint8List> _readAsfFile(RandomAccessFile file, int length) async {
  final header = await _readAudioRange(file, 0, min(30, length));
  if (header.length < 30 || !_matchesAudioGuid(header, 0, _asfHeaderGuid)) {
    return Uint8List(0);
  }
  return _readAudioRange(file, 0, min(_readAudioUint64Le(header, 16), length));
}

Future<Uint8List> _readApeFile(RandomAccessFile file, int length) async {
  if (length < 32) return Uint8List(0);
  final footer = await _readAudioRange(file, length - 32, 32);
  if (ascii.decode(Uint8List.sublistView(footer, 0, 8), allowInvalid: true) !=
      'APETAGEX') {
    return Uint8List(0);
  }
  final size = _readAudioUint32Le(footer, 12);
  if (size < 32 || size > length) return Uint8List(0);
  return _readAudioRange(file, length - size, size);
}

Future<Uint8List> _readOggFile(RandomAccessFile file, int length) async {
  final packet = BytesBuilder(copy: false);
  var completedPackets = 0;
  var offset = 0;
  while (offset + 27 <= length) {
    final header = await _readAudioRange(file, offset, 27);
    if (ascii.decode(Uint8List.sublistView(header, 0, 4), allowInvalid: true) !=
        'OggS') {
      break;
    }
    final segmentCount = header[26];
    if (offset + 27 + segmentCount > length) break;
    final segments = await _readAudioRange(file, offset + 27, segmentCount);
    var payloadOffset = offset + 27 + segmentCount;
    final pageSize = segments.fold<int>(0, (total, size) => total + size);
    if (payloadOffset + pageSize > length) return Uint8List(0);
    final payload = await _readAudioRange(file, payloadOffset, pageSize);
    var segmentOffset = 0;
    for (final size in segments) {
      packet.add(
        Uint8List.sublistView(payload, segmentOffset, segmentOffset + size),
      );
      segmentOffset += size;
      payloadOffset += size;
      if (size < 255) {
        final bytes = packet.takeBytes();
        completedPackets += 1;
        if (completedPackets == 2) return bytes;
      }
    }
    offset = payloadOffset;
  }
  return Uint8List(0);
}
