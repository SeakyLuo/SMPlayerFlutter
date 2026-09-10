part of 'library_audio_metadata_service.dart';

Future<int> _readApeDuration(RandomAccessFile file, int length) async {
  final first = await _readAudioRange(file, 0, min(10, length));
  final start = _readId3EndOffset(first);
  if (start > length) throw const FormatException('Truncated APE ID3 tag');
  final descriptor = await _readAudioRange(
    file,
    start,
    min(52, length - start),
  );
  if (descriptor.length < 32 ||
      ascii.decode(descriptor.sublist(0, 4), allowInvalid: true) != 'MAC ') {
    throw const FormatException('Invalid APE descriptor');
  }
  final version = descriptor[4] | descriptor[5] << 8;
  if (version < 3980) {
    // Older APE headers derive blocks per frame from version/compression level.
    final compression = descriptor[6] | descriptor[7] << 8;
    final blocks =
        version >= 3950
            ? 73728 * 4
            : version >= 3900 || (version >= 3800 && compression >= 4000)
            ? 73728
            : 9216;
    final rate = _readAudioUint32Le(descriptor, 12);
    final frames = _readAudioUint32Le(descriptor, 24);
    final finalBlocks = _readAudioUint32Le(descriptor, 28);
    if (rate == 0 || frames == 0) {
      throw const FormatException('Invalid APE audio parameters');
    }
    return (((frames - 1) * blocks + finalBlocks) / rate).round();
  }
  final offset = _readAudioUint32Le(descriptor, 8);
  if (offset < 52 || start + offset + 24 > length) {
    throw const FormatException('Invalid APE header size');
  }
  final header = await _readAudioRange(file, start + offset, 24);
  final blocks = _readAudioUint32Le(header, 4);
  final finalBlocks = _readAudioUint32Le(header, 8);
  final frames = _readAudioUint32Le(header, 12);
  final sampleRate = _readAudioUint32Le(header, 20);
  if (frames == 0 || sampleRate == 0) {
    throw const FormatException('Invalid APE audio parameters');
  }
  return (((frames - 1) * blocks + finalBlocks) / sampleRate).round();
}

Future<(Id3SongMetadata, int)> _readAacFile(
  RandomAccessFile file,
  int length,
  String path,
) async {
  final first = await _readAudioRange(file, 0, min(10, length));
  // AAC can be ADTS with optional ID3 tags, or an MPEG-4 container.
  if (first.length >= 8 &&
      ascii.decode(first.sublist(4, 8), allowInvalid: true) == 'ftyp') {
    final bytes = await _readMp4File(file, length);
    return (
      _id3TagService.readSongMetadataBytes(path, bytes),
      _readMp4DurationSeconds(bytes),
    );
  }
  final tagEnd = _readId3EndOffset(first);
  if (tagEnd > length) throw const FormatException('Truncated AAC ID3 tag');
  final tag = await _readAudioRange(file, 0, tagEnd);
  var offset = tagEnd;
  var seconds = 0.0;
  var bufferStart = -1;
  var buffer = Uint8List(0);
  const rates = [
    96000,
    88200,
    64000,
    48000,
    44100,
    32000,
    24000,
    22050,
    16000,
    12000,
    11025,
    8000,
    7350,
  ];
  while (offset < length) {
    if (offset + 7 > length) {
      throw const FormatException('Truncated ADTS header');
    }
    if (bufferStart < 0 || offset + 7 > bufferStart + buffer.length) {
      bufferStart = offset;
      buffer = await _readAudioRange(
        file,
        offset,
        min(64 * 1024, length - offset),
      );
    }
    final index = offset - bufferStart;
    if (buffer[index] != 0xff || (buffer[index + 1] & 0xf6) != 0xf0) {
      throw const FormatException('Invalid ADTS sync word');
    }
    final rateIndex = (buffer[index + 2] >> 2) & 15;
    final size =
        ((buffer[index + 3] & 3) << 11) |
        (buffer[index + 4] << 3) |
        (buffer[index + 5] >> 5);
    final headerSize = (buffer[index + 1] & 1) == 0 ? 9 : 7;
    if (rateIndex >= rates.length ||
        size < headerSize ||
        offset + size > length) {
      throw const FormatException('Invalid ADTS frame');
    }
    seconds += 1024 * ((buffer[index + 6] & 3) + 1) / rates[rateIndex];
    offset += size;
  }
  return (_id3TagService.readSongMetadataBytes(path, tag), seconds.round());
}

Future<(Id3SongMetadata, int)> _readOggMetadata(
  RandomAccessFile file,
  int length,
  String path,
) async {
  final packet = BytesBuilder(copy: false);
  var packetCount = 0;
  var offset = 0;
  var rate = 0;
  var preSkip = 0;
  var granule = 0;
  var serial = -1;
  var seconds = 0.0;
  var metadata = const Id3SongMetadata();
  while (offset < length) {
    final header = await _readAudioRange(file, offset, 27);
    if (ascii.decode(header.sublist(0, 4), allowInvalid: true) != 'OggS') {
      throw const FormatException('Invalid Ogg page');
    }
    final pageSerial = _readAudioUint32Le(header, 14);
    final segments = await _readAudioRange(file, offset + 27, header[26]);
    final payloadOffset = offset + 27 + segments.length;
    final size = segments.fold<int>(0, (total, item) => total + item);
    if (payloadOffset + size > length) {
      throw const FormatException('Truncated Ogg page');
    }
    if ((header[5] & 2) != 0 && serial == -1) serial = pageSerial;
    if (pageSerial == serial) {
      final position = _readAudioUint64Le(header, 6);
      if (position >= 0) granule = position;
      if (packetCount < 2) {
        final payload = await _readAudioRange(file, payloadOffset, size);
        var index = 0;
        for (final segment in segments) {
          packet.add(Uint8List.sublistView(payload, index, index + segment));
          index += segment;
          if (segment == 255) continue;
          final bytes = packet.takeBytes();
          packetCount++;
          if (packetCount == 1) {
            if (bytes.length >= 19 &&
                ascii.decode(bytes.sublist(0, 8), allowInvalid: true) ==
                    'OpusHead') {
              rate = 48000;
              preSkip = bytes[10] | bytes[11] << 8;
            } else if (bytes.length >= 30 &&
                bytes[0] == 1 &&
                ascii.decode(bytes.sublist(1, 7), allowInvalid: true) ==
                    'vorbis') {
              rate = _readAudioUint32Le(bytes, 12);
            } else {
              throw const FormatException('Unsupported Ogg audio codec');
            }
          } else if (packetCount == 2) {
            metadata = _id3TagService.readSongMetadataBytes(path, bytes);
            break;
          }
        }
      }
      if ((header[5] & 4) != 0) {
        if (rate <= 0 || granule < preSkip) {
          throw const FormatException('Invalid Ogg duration');
        }
        seconds += (granule - preSkip) / rate;
        serial = -1;
        packetCount = 0;
        preSkip = 0;
        granule = 0;
      }
    }
    // Audio page payloads are skipped; only headers and comment packets are read.
    offset = payloadOffset + size;
  }
  if (serial != -1 && rate > 0) seconds += max(0, granule - preSkip) / rate;
  return (metadata, seconds.round());
}
