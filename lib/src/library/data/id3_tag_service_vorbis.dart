part of 'id3_tag_service.dart';

extension _Id3TagServiceVorbis on Id3TagService {
  _FlacMetadata _readFlacMetadata(Uint8List fileBytes) {
    if (fileBytes.length < 4 ||
        ascii.decode(fileBytes.sublist(0, 4), allowInvalid: true) != 'fLaC') {
      return const _FlacMetadata(comments: {}, picture: null);
    }

    final comments = <String, List<String>>{};
    Id3Picture? picture;
    var offset = 4;
    var lastBlock = false;

    while (!lastBlock && offset + 4 <= fileBytes.length) {
      final header = fileBytes[offset];
      lastBlock = (header & 0x80) != 0;
      final blockType = header & 0x7f;
      final blockLength =
          (fileBytes[offset + 1] << 16) |
          (fileBytes[offset + 2] << 8) |
          fileBytes[offset + 3];
      offset += 4;
      if (offset + blockLength > fileBytes.length) {
        break;
      }
      final block = Uint8List.fromList(
        fileBytes.sublist(offset, offset + blockLength),
      );
      if (blockType == 4) {
        comments.addAll(_readVorbisCommentBlock(block));
      } else if (blockType == 6) {
        picture ??= _readFlacPictureBlock(block);
      }
      offset += blockLength;
    }

    return _FlacMetadata(
      comments: comments,
      picture: picture ?? _pictureFromVorbisComments(comments),
    );
  }

  Map<String, List<String>> _readOggComments(Uint8List fileBytes) {
    final vorbisOffset = _indexOfBytes(fileBytes, ascii.encode('\x03vorbis'));
    if (vorbisOffset != -1) {
      return _readVorbisCommentBlock(
        Uint8List.fromList(fileBytes.sublist(vorbisOffset + 7)),
      );
    }

    final opusOffset = _indexOfBytes(fileBytes, ascii.encode('OpusTags'));
    if (opusOffset != -1) {
      return _readVorbisCommentBlock(
        Uint8List.fromList(fileBytes.sublist(opusOffset + 8)),
      );
    }

    return const {};
  }

  Map<String, List<String>> _readVorbisCommentBlock(Uint8List block) {
    var offset = 0;
    if (offset + 4 > block.length) {
      return const {};
    }
    final vendorLength = _readUint32Le(block, offset);
    offset += 4 + vendorLength;
    if (offset + 4 > block.length) {
      return const {};
    }
    final commentCount = _readUint32Le(block, offset);
    offset += 4;
    final comments = <String, List<String>>{};
    for (var i = 0; i < commentCount && offset + 4 <= block.length; i += 1) {
      final commentLength = _readUint32Le(block, offset);
      offset += 4;
      if (offset + commentLength > block.length) {
        break;
      }
      final comment = utf8.decode(
        block.sublist(offset, offset + commentLength),
        allowMalformed: true,
      );
      offset += commentLength;
      final separator = comment.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = comment.substring(0, separator).toUpperCase();
      final value = comment.substring(separator + 1).trim();
      if (value.isNotEmpty) {
        comments.putIfAbsent(key, () => []).add(value);
      }
    }
    return comments;
  }

  Id3SongTagProperties _propertiesFromVorbisComments(
    Map<String, List<String>> comments,
  ) {
    return Id3SongTagProperties(
      title: _firstCommentValue(comments, ['TITLE']),
      subtitle: _firstCommentValue(comments, ['SUBTITLE', 'VERSION']),
      artist: _firstCommentValue(comments, ['ARTIST', 'PERFORMER']),
      artists: _commentValues(comments, ['ARTIST', 'PERFORMER']),
      album: _firstCommentValue(comments, ['ALBUM']),
      albumArtist: _firstCommentValue(comments, [
        'ALBUMARTIST',
        'ALBUM ARTIST',
      ]),
      publisher: _firstCommentValue(comments, [
        'PUBLISHER',
        'LABEL',
        'ORGANIZATION',
      ]),
      trackNumber: _readTrackNumber(
        _firstCommentValue(comments, ['TRACKNUMBER', 'TRACK']),
      ),
      year: _readYear(_firstCommentValue(comments, ['DATE', 'YEAR'])),
      genre: _firstCommentValue(comments, ['GENRE']),
      composers: _firstCommentValue(comments, ['COMPOSER']),
    );
  }

  String _firstCommentValue(
    Map<String, List<String>> comments,
    List<String> keys,
  ) {
    for (final key in keys) {
      final values = comments[key];
      if (values != null && values.isNotEmpty) {
        return values.first.trim();
      }
    }
    return '';
  }

  List<String> _commentValues(
    Map<String, List<String>> comments,
    List<String> keys,
  ) {
    return [
      for (final key in keys)
        ...?comments[key]
            ?.map((value) => value.trim())
            .where((value) => value.isNotEmpty),
    ];
  }

  Id3Picture? _readFlacPictureBlock(Uint8List block) {
    var offset = 0;
    if (block.length < 32) {
      return null;
    }
    offset += 4;
    final mimeLength = _readUint32Be(block, offset);
    offset += 4;
    if (offset + mimeLength > block.length) {
      return null;
    }
    final mime = ascii.decode(
      block.sublist(offset, offset + mimeLength),
      allowInvalid: true,
    );
    offset += mimeLength;
    if (offset + 4 > block.length) {
      return null;
    }
    final descriptionLength = _readUint32Be(block, offset);
    offset += 4 + descriptionLength + 16;
    if (offset + 4 > block.length) {
      return null;
    }
    final dataLength = _readUint32Be(block, offset);
    offset += 4;
    if (offset + dataLength > block.length) {
      return null;
    }
    return Id3Picture(
      data: Uint8List.fromList(block.sublist(offset, offset + dataLength)),
      format: mime,
    );
  }

  Id3Picture? _pictureFromVorbisComments(Map<String, List<String>> comments) {
    final pictureValue = _firstCommentValue(comments, [
      'METADATA_BLOCK_PICTURE',
    ]);
    if (pictureValue.isEmpty) {
      return null;
    }
    try {
      return _readFlacPictureBlock(base64.decode(pictureValue));
    } on FormatException {
      return null;
    }
  }
}
