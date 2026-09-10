import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:smplayer_flutter/src/library/data/library_audio_metadata_service.dart';

void main() {
  test('ADTS duration sums frames instead of treating AAC as MP4', () async {
    // 47 frames * 1024 / 48000 = 1.0027 seconds, with varying frame sizes.
    final output = BytesBuilder();
    for (var i = 0; i < 47; i++) {
      final size = 100 + i;
      final frame = Uint8List(size);
      frame.setRange(0, 7, [
        0xff,
        0xf1,
        0x4c,
        0x80 | (size >> 11),
        (size >> 3) & 255,
        ((size & 7) << 5) | 0x1f,
        0xfc,
      ]);
      output.add(frame);
    }
    final metadata = await _read('audio.aac', output.takeBytes());
    expect(metadata.duration, 1);
  });

  test('APE descriptor provides sample count and duration', () async {
    final bytes = Uint8List(76);
    bytes.setRange(0, 4, ascii.encode('MAC '));
    final data = ByteData.sublistView(bytes);
    data.setUint16(4, 3990, Endian.little);
    data.setUint32(8, 52, Endian.little);
    data.setUint32(12, 24, Endian.little);
    data.setUint32(56, 73728, Endian.little);
    data.setUint32(60, 14472, Endian.little);
    data.setUint32(64, 2, Endian.little);
    data.setUint16(68, 16, Endian.little);
    data.setUint16(70, 2, Endian.little);
    data.setUint32(72, 44100, Endian.little);
    expect((await _read('audio.ape', bytes)).duration, 2);
  });

  for (final opus in [false, true]) {
    test(
      '${opus ? 'Opus' : 'Vorbis'} retains comments and uses final granule',
      () async {
        final id = Uint8List(opus ? 19 : 30);
        if (opus) {
          id.setRange(0, 8, ascii.encode('OpusHead'));
          id[8] = 1;
          id[9] = 2;
          ByteData.sublistView(id).setUint16(10, 312, Endian.little);
          // Opus granules always use 48 kHz, regardless of input sample rate.
          ByteData.sublistView(id).setUint32(12, 24000, Endian.little);
        } else {
          id[0] = 1;
          id.setRange(1, 7, ascii.encode('vorbis'));
          id[11] = 2;
          ByteData.sublistView(id).setUint32(12, 44100, Endian.little);
        }
        final comment =
            BytesBuilder()..add(
              opus ? ascii.encode('OpusTags') : [3, ...ascii.encode('vorbis')],
            );
        comment.add(_uint32(0));
        comment.add(_uint32(2));
        for (final text in [
          'TITLE=Container title',
          'ARTIST=Container artist',
        ]) {
          final bytes = utf8.encode(text);
          comment
            ..add(_uint32(bytes.length))
            ..add(bytes);
        }
        final output =
            BytesBuilder()
              ..add(_page(id, 2, 0, 0))
              ..add(_page(comment.takeBytes(), 0, 0, 1))
              ..add(_page(Uint8List.fromList([0]), 4, opus ? 96312 : 88200, 2));
        final metadata = await _read(
          opus ? 'audio.opus' : 'audio.ogg',
          output.takeBytes(),
        );
        expect(metadata.duration, 2);
        expect(metadata.properties.title, 'Container title');
        expect(metadata.properties.artist, 'Container artist');
      },
    );
  }
}

Future<AudioFileMetadata> _read(String name, Uint8List bytes) async {
  final directory = await Directory.systemTemp.createTemp('audio-format-');
  addTearDown(() => directory.delete(recursive: true));
  final file = File(p.join(directory.path, name))..writeAsBytesSync(bytes);
  final result = await const LibraryAudioMetadataService()
      .readAudioFileMetadataBatch([
        file.path,
      ], cacheSongArtwork: (_, _) async => '');
  expect(result, contains(file.path));
  return result[file.path]!;
}

Uint8List _uint32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

Uint8List _page(Uint8List packet, int flags, int granule, int sequence) {
  final bytes = Uint8List(28 + packet.length);
  bytes.setRange(0, 4, ascii.encode('OggS'));
  bytes[5] = flags;
  final data = ByteData.sublistView(bytes);
  data.setUint64(6, granule, Endian.little);
  data.setUint32(14, 42, Endian.little);
  data.setUint32(18, sequence, Endian.little);
  bytes[26] = 1;
  bytes[27] = packet.length;
  bytes.setRange(28, bytes.length, packet);
  return bytes;
}
