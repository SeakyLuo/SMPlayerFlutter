part of 'id3_tag_service.dart';

extension _Id3TagServiceProperties on Id3TagService {
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
}
