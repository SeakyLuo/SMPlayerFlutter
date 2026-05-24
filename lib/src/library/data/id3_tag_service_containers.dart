part of 'id3_tag_service.dart';

extension _Id3TagServiceContainers on Id3TagService {
  _Mp4Metadata _readMp4Metadata(Uint8List fileBytes) {
    final atoms = _readMp4Atoms(fileBytes, 0, fileBytes.length);
    final textValues = <String, String>{};
    Id3Picture? picture;

    for (final atom in atoms) {
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

    return _Mp4Metadata(values: textValues, picture: picture);
  }

  _WavMetadata _readWavMetadata(Uint8List fileBytes) {
    if (fileBytes.length < 12 ||
        ascii.decode(fileBytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(fileBytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      return const _WavMetadata(info: {});
    }

    final info = <String, String>{};
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
      if (type == 'LIST' &&
          payload.length >= 4 &&
          ascii.decode(payload.sublist(0, 4), allowInvalid: true) == 'INFO') {
        info.addAll(_readWavInfoList(payload));
      }
      offset = payloadEnd + (size.isOdd ? 1 : 0);
    }

    return _WavMetadata(info: info);
  }

  _AiffMetadata _readAiffMetadata(Uint8List fileBytes) {
    if (fileBytes.length < 12 ||
        ascii.decode(fileBytes.sublist(0, 4), allowInvalid: true) != 'FORM' ||
        ascii.decode(fileBytes.sublist(8, 12), allowInvalid: true) != 'AIFF') {
      return const _AiffMetadata(tag: null);
    }

    _Id3Tag? tag;
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
      if (type.trim() == 'ID3') {
        final id3Tag = _readId3Tag(payload);
        if (id3Tag.frames.isNotEmpty) {
          tag ??= id3Tag;
        }
      }
      offset = payloadEnd + (size.isOdd ? 1 : 0);
    }

    return _AiffMetadata(tag: tag);
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
      return const _AsfMetadata(values: {}, picture: null);
    }

    final headerSize = _readUint64Le(fileBytes, 16);
    final objectCount = _readUint32Le(fileBytes, 24);
    final headerEnd = math.min(fileBytes.length, headerSize);
    final values = <String, List<String>>{};
    Id3Picture? picture;
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
      if (_matchesGuid(fileBytes, offset, _asfContentDescriptionGuid)) {
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

    return _AsfMetadata(values: values, picture: picture);
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
}
