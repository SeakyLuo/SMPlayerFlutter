import 'dart:convert';
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

  test('Id3TagService reads FLAC tags, lyrics, and artwork', () async {
    final directory = await Directory.systemTemp.createTemp('smplayer_flac_');
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File(
      '${directory.path}${Platform.pathSeparator}song.flac',
    );
    await songFile.writeAsBytes(
      _flacFile(
        comments: const [
          'TITLE=Flac Title',
          'ARTIST=Flac Artist',
          'ALBUM=Flac Album',
          'ALBUMARTIST=Flac Album Artist',
          'TRACKNUMBER=3/10',
          'DATE=2025-04-02',
          'GENRE=Jazz',
          'COMPOSER=Flac Composer',
          'UNSYNCEDLYRICS=[00:02.00]Flac line',
        ],
        picture: _pictureBlock('image/png', [0x89, 0x50]),
      ),
    );

    const service = Id3TagService();
    final properties = await service.readSongTagProperties(songFile.path);
    final picture = await service.readFirstPicture(songFile.path);

    expect(properties.title, 'Flac Title');
    expect(properties.artist, 'Flac Artist');
    expect(properties.album, 'Flac Album');
    expect(properties.albumArtist, 'Flac Album Artist');
    expect(properties.trackNumber, 3);
    expect(properties.year, 2025);
    expect(properties.genre, 'Jazz');
    expect(properties.composers, 'Flac Composer');
    expect(
      await service.readEmbeddedLyrics(songFile.path),
      '[00:02.00]Flac line',
    );
    expect(picture?.format, 'image/png');
    expect(picture?.data, [0x89, 0x50]);
  });

  test('Id3TagService reads Ogg Vorbis comments', () async {
    final directory = await Directory.systemTemp.createTemp('smplayer_ogg_');
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}${Platform.pathSeparator}song.ogg');
    await songFile.writeAsBytes([
      ...ascii.encode('OggS'),
      ...List.filled(22, 0),
      ...ascii.encode('\x03vorbis'),
      ..._vorbisCommentBlock(const [
        'TITLE=Ogg Title',
        'ARTIST=Ogg Artist',
        'ALBUM=Ogg Album',
        'DATE=2024',
      ]),
    ]);

    final properties = await const Id3TagService().readSongTagProperties(
      songFile.path,
    );

    expect(properties.title, 'Ogg Title');
    expect(properties.artist, 'Ogg Artist');
    expect(properties.album, 'Ogg Album');
    expect(properties.year, 2024);
  });

  test('Id3TagService reads M4A atoms and artwork', () async {
    final directory = await Directory.systemTemp.createTemp('smplayer_m4a_');
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}${Platform.pathSeparator}song.m4a');
    await songFile.writeAsBytes(
      _mp4File(
        items: {
          '©nam': _mp4TextItem('M4A Title'),
          '©ART': _mp4TextItem('M4A Artist'),
          '©alb': _mp4TextItem('M4A Album'),
          'aART': _mp4TextItem('M4A Album Artist'),
          '©day': _mp4TextItem('2023-01-01'),
          'trkn': _mp4TrackItem(5),
          'covr': _mp4CoverItem([0xff, 0xd8]),
        },
      ),
    );

    const service = Id3TagService();
    final properties = await service.readSongTagProperties(songFile.path);
    final picture = await service.readFirstPicture(songFile.path);

    expect(properties.title, 'M4A Title');
    expect(properties.artist, 'M4A Artist');
    expect(properties.album, 'M4A Album');
    expect(properties.albumArtist, 'M4A Album Artist');
    expect(properties.trackNumber, 5);
    expect(properties.year, 2023);
    expect(picture?.format, 'image/jpeg');
    expect(picture?.data, [0xff, 0xd8]);
  });

  test('Id3TagService reads WAV INFO tags', () async {
    final directory = await Directory.systemTemp.createTemp('smplayer_wav_');
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}${Platform.pathSeparator}song.wav');
    await songFile.writeAsBytes(
      _wavFile(
        sampleRate: 8000,
        channels: 1,
        bitsPerSample: 16,
        dataBytes: 32000,
        info: const {
          'INAM': 'WAV Title',
          'IART': 'WAV Artist',
          'IPRD': 'WAV Album',
          'ICRD': '2026-05-21',
          'IGNR': 'Wave',
          'ICMT': 'WAV Composer',
        },
      ),
    );

    const service = Id3TagService();
    final properties = await service.readSongTagProperties(songFile.path);

    expect(properties.title, 'WAV Title');
    expect(properties.artist, 'WAV Artist');
    expect(properties.album, 'WAV Album');
    expect(properties.year, 2026);
    expect(properties.genre, 'Wave');
    expect(properties.composers, 'WAV Composer');
  });

  test('Id3TagService reads AIFF ID3 tags, lyrics, and artwork', () async {
    final directory = await Directory.systemTemp.createTemp('smplayer_aiff_');
    addTearDown(() async {
      await directory.delete(recursive: true);
    });

    final taggedMp3 = File(
      '${directory.path}${Platform.pathSeparator}tagged.mp3',
    );
    await taggedMp3.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);

    const service = Id3TagService();
    await service.writeSongTagProperties(
      taggedMp3.path,
      const Id3SongTagProperties(
        title: 'AIFF Title',
        subtitle: 'AIFF Subtitle',
        artist: 'AIFF Artist',
        album: 'AIFF Album',
        albumArtist: 'AIFF Album Artist',
        publisher: 'AIFF Publisher',
        trackNumber: 4,
        year: 2026,
        genre: 'AIFF Genre',
        composers: 'AIFF Composer',
      ),
    );
    await service.writeEmbeddedLyrics(taggedMp3.path, '[00:03.00]AIFF line');
    await service.writeSongArtwork(
      taggedMp3.path,
      Id3Picture(
        data: Uint8List.fromList([0xff, 0xd8, 0xff]),
        format: 'image/jpeg',
      ),
    );

    final id3Tag = _id3TagFromTaggedMp3(await taggedMp3.readAsBytes());
    final songFile = File(
      '${directory.path}${Platform.pathSeparator}song.aiff',
    );
    await songFile.writeAsBytes(_aiffFile(sampleFrames: 88200, id3Tag: id3Tag));

    final properties = await service.readSongTagProperties(songFile.path);
    final picture = await service.readFirstPicture(songFile.path);

    expect(properties.title, 'AIFF Title');
    expect(properties.subtitle, 'AIFF Subtitle');
    expect(properties.artist, 'AIFF Artist');
    expect(properties.album, 'AIFF Album');
    expect(properties.albumArtist, 'AIFF Album Artist');
    expect(properties.publisher, 'AIFF Publisher');
    expect(properties.trackNumber, 4);
    expect(properties.year, 2026);
    expect(properties.genre, 'AIFF Genre');
    expect(properties.composers, 'AIFF Composer');
    expect(
      await service.readEmbeddedLyrics(songFile.path),
      '[00:03.00]AIFF line',
    );
    expect(picture?.format, 'image/jpeg');
    expect(picture?.data, [0xff, 0xd8, 0xff]);
  });

  test('Id3TagService reads APEv2 tags, lyrics, and artwork', () async {
    final directory = await Directory.systemTemp.createTemp('smplayer_ape_');
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}${Platform.pathSeparator}song.ape');
    await songFile.writeAsBytes(
      _apeFile(
        textItems: const {
          'Title': 'APE Title',
          'Subtitle': 'APE Subtitle',
          'Artist': 'APE Artist',
          'Album': 'APE Album',
          'Album Artist': 'APE Album Artist',
          'Publisher': 'APE Publisher',
          'Track': '6/12',
          'Date': '2026-05-21',
          'Genre': 'APE Genre',
          'Composer': 'APE Composer',
          'Lyrics': '[00:04.00]APE line',
        },
        coverBytes: const [0x89, 0x50, 0x4e, 0x47],
      ),
    );

    const service = Id3TagService();
    final properties = await service.readSongTagProperties(songFile.path);
    final picture = await service.readFirstPicture(songFile.path);

    expect(properties.title, 'APE Title');
    expect(properties.subtitle, 'APE Subtitle');
    expect(properties.artist, 'APE Artist');
    expect(properties.album, 'APE Album');
    expect(properties.albumArtist, 'APE Album Artist');
    expect(properties.publisher, 'APE Publisher');
    expect(properties.trackNumber, 6);
    expect(properties.year, 2026);
    expect(properties.genre, 'APE Genre');
    expect(properties.composers, 'APE Composer');
    expect(
      await service.readEmbeddedLyrics(songFile.path),
      '[00:04.00]APE line',
    );
    expect(picture?.format, 'image/png');
    expect(picture?.data, [0x89, 0x50, 0x4e, 0x47]);
  });

  test('Id3TagService reads WMA ASF tags, artwork, and lyrics', () async {
    final directory = await Directory.systemTemp.createTemp('smplayer_wma_');
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}${Platform.pathSeparator}song.wma');
    await songFile.writeAsBytes(
      _asfFile(
        title: 'WMA Title',
        artist: 'WMA Artist',
        extendedTextItems: const {
          'WM/SubTitle': 'WMA Subtitle',
          'WM/AlbumTitle': 'WMA Album',
          'WM/AlbumArtist': 'WMA Album Artist',
          'WM/Publisher': 'WMA Publisher',
          'WM/TrackNumber': '8/14',
          'WM/Year': '2026',
          'WM/Genre': 'WMA Genre',
          'WM/Composer': 'WMA Composer',
          'WM/Lyrics': '[00:05.00]WMA line',
        },
        pictureBytes: const [0xff, 0xd8, 0xff],
      ),
    );

    const service = Id3TagService();
    final properties = await service.readSongTagProperties(songFile.path);
    final picture = await service.readFirstPicture(songFile.path);

    expect(properties.title, 'WMA Title');
    expect(properties.subtitle, 'WMA Subtitle');
    expect(properties.artist, 'WMA Artist');
    expect(properties.album, 'WMA Album');
    expect(properties.albumArtist, 'WMA Album Artist');
    expect(properties.publisher, 'WMA Publisher');
    expect(properties.trackNumber, 8);
    expect(properties.year, 2026);
    expect(properties.genre, 'WMA Genre');
    expect(properties.composers, 'WMA Composer');
    expect(
      await service.readEmbeddedLyrics(songFile.path),
      '[00:05.00]WMA line',
    );
    expect(picture?.format, 'image/jpeg');
    expect(picture?.data, [0xff, 0xd8, 0xff]);
  });
}

List<int> _flacFile({
  required List<String> comments,
  required List<int> picture,
}) {
  final streamInfo = List.filled(34, 0);
  const sampleRate = 44100;
  const totalSamples = 88200;
  streamInfo[10] = sampleRate >> 12;
  streamInfo[11] = (sampleRate >> 4) & 0xff;
  streamInfo[12] = ((sampleRate & 0x0f) << 4) | 0x06;
  streamInfo[13] = totalSamples >> 32;
  streamInfo[14] = (totalSamples >> 24) & 0xff;
  streamInfo[15] = (totalSamples >> 16) & 0xff;
  streamInfo[16] = (totalSamples >> 8) & 0xff;
  streamInfo[17] = totalSamples & 0xff;
  final commentBlock = _vorbisCommentBlock(comments);
  return [
    ...ascii.encode('fLaC'),
    ..._flacBlockHeader(type: 0, length: streamInfo.length),
    ...streamInfo,
    ..._flacBlockHeader(type: 4, length: commentBlock.length),
    ...commentBlock,
    ..._flacBlockHeader(type: 6, length: picture.length, last: true),
    ...picture,
  ];
}

List<int> _flacBlockHeader({
  required int type,
  required int length,
  bool last = false,
}) {
  return [
    (last ? 0x80 : 0) | type,
    (length >> 16) & 0xff,
    (length >> 8) & 0xff,
    length & 0xff,
  ];
}

List<int> _vorbisCommentBlock(List<String> comments) {
  final vendor = utf8.encode('SMPlayerFlutter');
  return [
    ..._uint32Le(vendor.length),
    ...vendor,
    ..._uint32Le(comments.length),
    for (final comment in comments) ...[
      ..._uint32Le(utf8.encode(comment).length),
      ...utf8.encode(comment),
    ],
  ];
}

List<int> _pictureBlock(String mime, List<int> data) {
  final mimeBytes = ascii.encode(mime);
  return [
    ..._uint32Be(3),
    ..._uint32Be(mimeBytes.length),
    ...mimeBytes,
    ..._uint32Be(0),
    ..._uint32Be(1),
    ..._uint32Be(1),
    ..._uint32Be(24),
    ..._uint32Be(0),
    ..._uint32Be(data.length),
    ...data,
  ];
}

List<int> _mp4File({required Map<String, List<int>> items}) {
  final ilst = _atom('ilst', [
    for (final entry in items.entries) ..._atom(entry.key, entry.value),
  ]);
  final meta = _atom('meta', [0, 0, 0, 0, ...ilst]);
  final udta = _atom('udta', meta);
  final mvhd = _atom('mvhd', [
    0,
    0,
    0,
    0,
    ..._uint32Be(0),
    ..._uint32Be(0),
    ..._uint32Be(1000),
    ..._uint32Be(2000),
  ]);
  return [
    ..._atom('ftyp', ascii.encode('M4A ')),
    ..._atom('moov', [...mvhd, ...udta]),
  ];
}

List<int> _mp4TextItem(String value) {
  return _atom('data', [0, 0, 0, 1, 0, 0, 0, 0, ...utf8.encode(value)]);
}

List<int> _mp4TrackItem(int trackNumber) {
  return _atom('data', [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    (trackNumber >> 8) & 0xff,
    trackNumber & 0xff,
    0,
    0,
  ]);
}

List<int> _mp4CoverItem(List<int> data) {
  return _atom('data', [0, 0, 0, 13, 0, 0, 0, 0, ...data]);
}

List<int> _wavFile({
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
  required int dataBytes,
  required Map<String, String> info,
}) {
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final fmtChunk = _riffChunk('fmt ', [
    1,
    0,
    channels & 0xff,
    (channels >> 8) & 0xff,
    ..._uint32Le(sampleRate),
    ..._uint32Le(byteRate),
    blockAlign & 0xff,
    (blockAlign >> 8) & 0xff,
    bitsPerSample & 0xff,
    (bitsPerSample >> 8) & 0xff,
  ]);
  final infoChunk = _riffChunk('LIST', [
    ...ascii.encode('INFO'),
    for (final entry in info.entries)
      ..._riffChunk(entry.key, [...utf8.encode(entry.value), 0]),
  ]);
  final dataChunk = _riffChunk('data', List.filled(dataBytes, 0));
  final payload = [...fmtChunk, ...infoChunk, ...dataChunk];
  return [
    ...ascii.encode('RIFF'),
    ..._uint32Le(payload.length + 4),
    ...ascii.encode('WAVE'),
    ...payload,
  ];
}

List<int> _aiffFile({required int sampleFrames, required List<int> id3Tag}) {
  final commChunk = _aiffChunk('COMM', [
    0,
    2,
    ..._uint32Be(sampleFrames),
    0,
    16,
    0x40,
    0x0e,
    0xac,
    0x44,
    0,
    0,
    0,
    0,
    0,
    0,
  ]);
  final id3Chunk = _aiffChunk('ID3 ', id3Tag);
  final payload = [...commChunk, ...id3Chunk];
  return [
    ...ascii.encode('FORM'),
    ..._uint32Be(payload.length + 4),
    ...ascii.encode('AIFF'),
    ...payload,
  ];
}

List<int> _id3TagFromTaggedMp3(List<int> bytes) {
  final tagSize =
      (bytes[6] << 21) | (bytes[7] << 14) | (bytes[8] << 7) | bytes[9];
  return bytes.sublist(0, tagSize + 10);
}

List<int> _apeFile({
  required Map<String, String> textItems,
  required List<int> coverBytes,
}) {
  final items = [
    for (final entry in textItems.entries)
      ..._apeTextItem(entry.key, entry.value),
    ..._apeBinaryItem('Cover Art (Front)', [
      ...ascii.encode('front.png'),
      0,
      ...coverBytes,
    ]),
  ];
  return [
    ...List.filled(64, 0),
    ...items,
    ..._apeFooter(size: items.length + 32, itemCount: textItems.length + 1),
  ];
}

List<int> _apeTextItem(String key, String value) {
  final valueBytes = utf8.encode(value);
  return [
    ..._uint32Le(valueBytes.length),
    ..._uint32Le(0),
    ...latin1.encode(key),
    0,
    ...valueBytes,
  ];
}

List<int> _apeBinaryItem(String key, List<int> value) {
  return [
    ..._uint32Le(value.length),
    ..._uint32Le(0x02),
    ...latin1.encode(key),
    0,
    ...value,
  ];
}

List<int> _apeFooter({required int size, required int itemCount}) {
  return [
    ...ascii.encode('APETAGEX'),
    ..._uint32Le(2000),
    ..._uint32Le(size),
    ..._uint32Le(itemCount),
    ..._uint32Le(0),
    ...List.filled(8, 0),
  ];
}

List<int> _asfFile({
  required String title,
  required String artist,
  required Map<String, String> extendedTextItems,
  required List<int> pictureBytes,
}) {
  final objects = [
    _asfObject(
      _asfContentDescriptionGuid,
      _asfContentDescriptionPayload(title: title, artist: artist),
    ),
    _asfObject(
      _asfExtendedContentDescriptionGuid,
      _asfExtendedContentDescriptionPayload(
        textItems: extendedTextItems,
        pictureBytes: pictureBytes,
      ),
    ),
  ];
  final headerPayload = [
    ..._uint32Le(objects.length),
    1,
    2,
    for (final object in objects) ...object,
  ];
  return [
    ..._asfHeaderGuid,
    ..._uint64Le(headerPayload.length + 24),
    ...headerPayload,
  ];
}

List<int> _asfContentDescriptionPayload({
  required String title,
  required String artist,
}) {
  final values = [
    _utf16LeNullTerminated(title),
    _utf16LeNullTerminated(artist),
    <int>[],
    <int>[],
    <int>[],
  ];
  return [
    for (final value in values) ..._uint16Le(value.length),
    for (final value in values) ...value,
  ];
}

List<int> _asfExtendedContentDescriptionPayload({
  required Map<String, String> textItems,
  required List<int> pictureBytes,
}) {
  final descriptors = [
    for (final entry in textItems.entries)
      _asfDescriptor(entry.key, 0, _utf16LeNullTerminated(entry.value)),
    _asfDescriptor('WM/Picture', 1, [
      3,
      ..._uint32Le(pictureBytes.length),
      ..._utf16LeNullTerminated('image/jpeg'),
      ..._utf16LeNullTerminated('front'),
      ...pictureBytes,
    ]),
  ];
  return [
    ..._uint16Le(descriptors.length),
    for (final descriptor in descriptors) ...descriptor,
  ];
}

List<int> _asfDescriptor(String name, int valueType, List<int> value) {
  final nameBytes = _utf16LeNullTerminated(name);
  return [
    ..._uint16Le(nameBytes.length),
    ...nameBytes,
    ..._uint16Le(valueType),
    ..._uint16Le(value.length),
    ...value,
  ];
}

List<int> _asfObject(List<int> guid, List<int> payload) {
  return [...guid, ..._uint64Le(payload.length + 24), ...payload];
}

List<int> _riffChunk(String type, List<int> payload) {
  return [
    ...ascii.encode(type),
    ..._uint32Le(payload.length),
    ...payload,
    if (payload.length.isOdd) 0,
  ];
}

List<int> _aiffChunk(String type, List<int> payload) {
  return [
    ...ascii.encode(type),
    ..._uint32Be(payload.length),
    ...payload,
    if (payload.length.isOdd) 0,
  ];
}

List<int> _atom(String type, List<int> payload) {
  return [..._uint32Be(payload.length + 8), ...latin1.encode(type), ...payload];
}

List<int> _uint32Be(int value) {
  return [
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}

List<int> _uint32Le(int value) {
  return [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];
}

List<int> _uint16Le(int value) {
  return [value & 0xff, (value >> 8) & 0xff];
}

List<int> _uint64Le(int value) {
  return [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
    (value >> 32) & 0xff,
    (value >> 40) & 0xff,
    (value >> 48) & 0xff,
    (value >> 56) & 0xff,
  ];
}

List<int> _utf16LeNullTerminated(String value) {
  final bytes = <int>[];
  for (final codeUnit in value.codeUnits) {
    bytes.add(codeUnit & 0xff);
    bytes.add((codeUnit >> 8) & 0xff);
  }
  bytes.addAll([0, 0]);
  return bytes;
}

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
