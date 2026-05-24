import 'dart:convert' show ascii;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'id3_tag_service.dart';
import 'library_models.dart';

const _id3TagService = Id3TagService();

class AudioFileMetadata {
  const AudioFileMetadata({
    required this.properties,
    required this.duration,
    required this.thumbnailPath,
  });

  final Id3SongTagProperties properties;
  final int duration;
  final String thumbnailPath;
}

typedef CacheSongArtwork = Future<String> Function(String filePath);

class LibraryAudioMetadataService {
  const LibraryAudioMetadataService();

  Future<Map<String, AudioFileMetadata>> readAudioFileMetadataBatch(
    List<String> filePaths, {
    required CacheSongArtwork cacheSongArtwork,
    LocalFolderScanCancellation? cancellation,
    void Function(String filePath, int completedCount)? onProgress,
  }) async {
    const concurrency = 6;
    final metadataByPath = <String, AudioFileMetadata>{};
    var nextIndex = 0;
    var completedCount = 0;

    Future<void> worker() async {
      while (nextIndex < filePaths.length) {
        cancellation?.throwIfCanceled();
        final filePath = filePaths[nextIndex];
        nextIndex += 1;
        metadataByPath[filePath] = await _readAudioFileMetadata(
          filePath,
          cacheSongArtwork: cacheSongArtwork,
        );
        completedCount += 1;
        onProgress?.call(filePath, completedCount);
        cancellation?.throwIfCanceled();
      }
    }

    await Future.wait([
      for (
        var workerIndex = 0;
        workerIndex < min(concurrency, filePaths.length);
        workerIndex += 1
      )
        worker(),
    ]);
    return metadataByPath;
  }

  Future<AudioFileMetadata> _readAudioFileMetadata(
    String filePath, {
    required CacheSongArtwork cacheSongArtwork,
  }) async {
    final properties = await _id3TagService.readSongTagProperties(filePath);
    final duration = await _readAudioDurationSeconds(filePath);
    final thumbnailPath = await cacheSongArtwork(filePath);
    return AudioFileMetadata(
      properties: properties,
      duration: duration,
      thumbnailPath: thumbnailPath,
    );
  }
}

Future<int> _readAudioDurationSeconds(String filePath) async {
  final extension = p.extension(filePath).toLowerCase();
  if (extension != '.flac' &&
      extension != '.m4a' &&
      extension != '.mp4' &&
      extension != '.aac' &&
      extension != '.alac' &&
      extension != '.wav' &&
      extension != '.aiff' &&
      extension != '.aif' &&
      extension != '.wma' &&
      extension != '.mp3') {
    return 0;
  }
  final bytes = await File(filePath).readAsBytes();
  return switch (extension) {
    '.flac' => _readFlacDurationSeconds(bytes),
    '.m4a' || '.mp4' || '.aac' || '.alac' => _readMp4DurationSeconds(bytes),
    '.wav' => _readWavDurationSeconds(bytes),
    '.aiff' || '.aif' => _readAiffDurationSeconds(bytes),
    '.wma' => _readAsfDurationSeconds(bytes),
    '.mp3' => _readMp3DurationSeconds(bytes),
    _ => 0,
  };
}

int _readFlacDurationSeconds(Uint8List bytes) {
  if (bytes.length < 4 ||
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'fLaC') {
    return 0;
  }
  var offset = 4;
  var lastBlock = false;
  while (!lastBlock && offset + 4 <= bytes.length) {
    final header = bytes[offset];
    lastBlock = (header & 0x80) != 0;
    final blockType = header & 0x7f;
    final blockLength =
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    offset += 4;
    if (offset + blockLength > bytes.length) {
      break;
    }
    if (blockType == 0 && blockLength >= 18) {
      final sampleRate =
          (bytes[offset + 10] << 12) |
          (bytes[offset + 11] << 4) |
          (bytes[offset + 12] >> 4);
      final totalSamples =
          ((bytes[offset + 13] & 0x0f) << 32) |
          (bytes[offset + 14] << 24) |
          (bytes[offset + 15] << 16) |
          (bytes[offset + 16] << 8) |
          bytes[offset + 17];
      return sampleRate > 0 && totalSamples > 0
          ? (totalSamples / sampleRate).round()
          : 0;
    }
    offset += blockLength;
  }
  return 0;
}

int _readMp4DurationSeconds(Uint8List bytes) {
  for (final atom in _readMp4DurationAtoms(bytes, 0, bytes.length)) {
    if (atom.path.endsWith('/mvhd')) {
      return _readMp4MovieDuration(atom.payload);
    }
  }
  return 0;
}

List<_AudioDurationMp4Atom> _readMp4DurationAtoms(
  Uint8List bytes,
  int start,
  int end, [
  String parentPath = '',
]) {
  final atoms = <_AudioDurationMp4Atom>[];
  var offset = start;
  while (offset + 8 <= end && offset + 8 <= bytes.length) {
    var atomSize = _readAudioUint32Be(bytes, offset);
    final type = ascii.decode(
      bytes.sublist(offset + 4, offset + 8),
      allowInvalid: true,
    );
    var headerSize = 8;
    if (atomSize == 1 && offset + 16 <= bytes.length) {
      atomSize = _readAudioUint64Be(bytes, offset + 8);
      headerSize = 16;
    } else if (atomSize == 0) {
      atomSize = end - offset;
    }
    final atomEnd = offset + atomSize;
    if (atomSize < headerSize || atomEnd > end || atomEnd > bytes.length) {
      break;
    }
    final payloadOffset = offset + headerSize;
    final atomPath = parentPath.isEmpty ? type : '$parentPath/$type';
    final payload = Uint8List.fromList(bytes.sublist(payloadOffset, atomEnd));
    atoms.add(_AudioDurationMp4Atom(path: atomPath, payload: payload));
    if (_audioDurationMp4ContainerAtomTypes.contains(type)) {
      atoms.addAll(
        _readMp4DurationAtoms(bytes, payloadOffset, atomEnd, atomPath),
      );
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
    final timescale = _readAudioUint32Be(payload, 20);
    final duration = _readAudioUint64Be(payload, 24);
    return timescale > 0 ? (duration / timescale).round() : 0;
  }
  final timescale = _readAudioUint32Be(payload, 12);
  final duration = _readAudioUint32Be(payload, 16);
  return timescale > 0 ? (duration / timescale).round() : 0;
}

int _readWavDurationSeconds(Uint8List bytes) {
  if (bytes.length < 12 ||
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
    return 0;
  }
  var byteRate = 0;
  var dataBytes = 0;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final type = ascii.decode(
      bytes.sublist(offset, offset + 4),
      allowInvalid: true,
    );
    final size = _readAudioUint32Le(bytes, offset + 4);
    final payloadStart = offset + 8;
    final payloadEnd = payloadStart + size;
    if (payloadEnd > bytes.length) {
      break;
    }
    if (type == 'fmt ' && size >= 16) {
      byteRate = _readAudioUint32Le(bytes, payloadStart + 8);
    } else if (type == 'data') {
      dataBytes += size;
    }
    offset = payloadEnd + (size.isOdd ? 1 : 0);
  }
  return byteRate > 0 && dataBytes > 0 ? (dataBytes / byteRate).round() : 0;
}

int _readAiffDurationSeconds(Uint8List bytes) {
  if (bytes.length < 12 ||
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'FORM' ||
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'AIFF') {
    return 0;
  }
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final type = ascii.decode(
      bytes.sublist(offset, offset + 4),
      allowInvalid: true,
    );
    final size = _readAudioUint32Be(bytes, offset + 4);
    final payloadStart = offset + 8;
    final payloadEnd = payloadStart + size;
    if (payloadEnd > bytes.length) {
      break;
    }
    if (type == 'COMM' && size >= 18) {
      final sampleFrames = _readAudioUint32Be(bytes, payloadStart + 2);
      final sampleRate = _readAiffExtendedSampleRate(bytes, payloadStart + 8);
      return sampleFrames > 0 && sampleRate > 0
          ? (sampleFrames / sampleRate).round()
          : 0;
    }
    offset = payloadEnd + (size.isOdd ? 1 : 0);
  }
  return 0;
}

int _readAiffExtendedSampleRate(Uint8List bytes, int offset) {
  if (offset + 10 > bytes.length) {
    return 0;
  }
  final exponent = ((bytes[offset] & 0x7f) << 8) | bytes[offset + 1];
  if (exponent == 0) {
    return 0;
  }
  final highMantissa = _readAudioUint32Be(bytes, offset + 2);
  final lowMantissa = _readAudioUint32Be(bytes, offset + 6);
  final mantissa = highMantissa * 4294967296.0 + lowMantissa;
  final value = mantissa * pow(2, exponent - 16383 - 63);
  return value.isFinite && value > 0 ? value.round() : 0;
}

int _readAsfDurationSeconds(Uint8List bytes) {
  if (bytes.length < 30 || !_matchesAudioGuid(bytes, 0, _asfHeaderGuid)) {
    return 0;
  }
  final headerSize = _readAudioUint64Le(bytes, 16);
  final objectCount = _readAudioUint32Le(bytes, 24);
  final headerEnd = min(bytes.length, headerSize);
  var offset = 30;
  for (
    var index = 0;
    index < objectCount && offset + 24 <= headerEnd;
    index += 1
  ) {
    final objectSize = _readAudioUint64Le(bytes, offset + 16);
    final objectEnd = offset + objectSize;
    if (objectSize < 24 || objectEnd > headerEnd) {
      break;
    }
    if (_matchesAudioGuid(bytes, offset, _asfFilePropertiesGuid)) {
      final payloadOffset = offset + 24;
      final payloadLength = objectSize - 24;
      if (payloadLength < 64) {
        return 0;
      }
      final playDuration = _readAudioUint64Le(bytes, payloadOffset + 40);
      final preroll = _readAudioUint64Le(bytes, payloadOffset + 56);
      return playDuration > 0
          ? max(0, (playDuration / 10000000 - preroll / 1000).round())
          : 0;
    }
    offset = objectEnd;
  }
  return 0;
}

int _readMp3DurationSeconds(Uint8List bytes) {
  final id3EndOffset = _readId3EndOffset(bytes);
  final headerOffset = _findFirstMpegFrameHeader(bytes, id3EndOffset);
  if (headerOffset == -1) {
    return 0;
  }
  final xingDuration = _readXingDurationSeconds(bytes, headerOffset);
  if (xingDuration > 0) {
    return xingDuration;
  }
  final bitrateKbps = _readMpegBitrateKbps(
    bytes[headerOffset + 1],
    bytes[headerOffset + 2],
  );
  if (bitrateKbps <= 0) {
    return 0;
  }
  final audioByteLength = bytes.length - headerOffset;
  return (audioByteLength * 8 / (bitrateKbps * 1000)).round();
}

int _readId3EndOffset(Uint8List bytes) {
  if (bytes.length < 10 ||
      ascii.decode(bytes.sublist(0, 3), allowInvalid: true) != 'ID3') {
    return 0;
  }
  return 10 + _readAudioSynchsafeSize(bytes, 6);
}

int _readXingDurationSeconds(Uint8List bytes, int headerOffset) {
  if (headerOffset + 48 > bytes.length) {
    return 0;
  }
  final secondHeaderByte = bytes[headerOffset + 1];
  final thirdHeaderByte = bytes[headerOffset + 2];
  final fourthHeaderByte = bytes[headerOffset + 3];
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
  if (xingStart + 12 > bytes.length) {
    return 0;
  }
  final marker = ascii.decode(
    bytes.sublist(xingStart, xingStart + 4),
    allowInvalid: true,
  );
  if (marker != 'Xing' && marker != 'Info') {
    return 0;
  }
  final flags = _readAudioUint32Be(bytes, xingStart + 4);
  if ((flags & 0x01) == 0) {
    return 0;
  }
  final frameCount = _readAudioUint32Be(bytes, xingStart + 8);
  if (frameCount <= 0) {
    return 0;
  }
  final samplesPerFrame = version == 3 ? 1152 : 576;
  return (frameCount * samplesPerFrame / sampleRate).round();
}

int _findFirstMpegFrameHeader(Uint8List bytes, int startOffset) {
  for (
    var index = startOffset.clamp(0, bytes.length);
    index + 3 < bytes.length;
    index += 1
  ) {
    if (bytes[index] != 0xff || (bytes[index + 1] & 0xe0) != 0xe0) {
      continue;
    }
    if (_readMpegBitrateKbps(bytes[index + 1], bytes[index + 2]) > 0) {
      return index;
    }
  }
  return -1;
}

int _readMpegBitrateKbps(int secondHeaderByte, int thirdHeaderByte) {
  final version = (secondHeaderByte >> 3) & 0x03;
  final layer = (secondHeaderByte >> 1) & 0x03;
  final bitrateIndex = (thirdHeaderByte >> 4) & 0x0f;
  if (version == 1 || layer != 1 || bitrateIndex == 0 || bitrateIndex == 0x0f) {
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

bool _matchesAudioGuid(Uint8List bytes, int offset, List<int> guid) {
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

int _readAudioSynchsafeSize(Uint8List buffer, int offset) {
  return ((buffer[offset] & 0x7f) << 21) |
      ((buffer[offset + 1] & 0x7f) << 14) |
      ((buffer[offset + 2] & 0x7f) << 7) |
      (buffer[offset + 3] & 0x7f);
}

int _readAudioUint32Be(Uint8List buffer, int offset) {
  return (buffer[offset] << 24) |
      (buffer[offset + 1] << 16) |
      (buffer[offset + 2] << 8) |
      buffer[offset + 3];
}

int _readAudioUint64Be(Uint8List buffer, int offset) {
  return (_readAudioUint32Be(buffer, offset) * 4294967296) +
      _readAudioUint32Be(buffer, offset + 4);
}

int _readAudioUint32Le(Uint8List buffer, int offset) {
  return buffer[offset] |
      (buffer[offset + 1] << 8) |
      (buffer[offset + 2] << 16) |
      (buffer[offset + 3] << 24);
}

int _readAudioUint64Le(Uint8List buffer, int offset) {
  return _readAudioUint32Le(buffer, offset) +
      (_readAudioUint32Le(buffer, offset + 4) * 4294967296);
}

const _audioDurationMp4ContainerAtomTypes = {
  'moov',
  'trak',
  'mdia',
  'minf',
  'stbl',
  'udta',
  'meta',
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

class _AudioDurationMp4Atom {
  const _AudioDurationMp4Atom({required this.path, required this.payload});

  final String path;
  final Uint8List payload;
}
