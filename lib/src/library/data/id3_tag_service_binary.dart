part of 'id3_tag_service.dart';

extension _Id3TagServiceBinary on Id3TagService {
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
