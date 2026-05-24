part of 'id3_tag_service.dart';

class _Id3Tag {
  const _Id3Tag({
    required this.version,
    required this.endOffset,
    required this.frames,
  });

  final int version;
  final int endOffset;
  final List<_Id3Frame> frames;
}

class _Id3Frame {
  const _Id3Frame({required this.id, required this.raw, required this.payload});

  final String id;
  final Uint8List raw;
  final Uint8List payload;
}

class _FlacMetadata {
  const _FlacMetadata({required this.comments, required this.picture});

  final Map<String, List<String>> comments;
  final Id3Picture? picture;
}

class _Mp4Metadata {
  const _Mp4Metadata({required this.values, required this.picture});

  final Map<String, String> values;
  final Id3Picture? picture;
}

class _WavMetadata {
  const _WavMetadata({required this.info});

  final Map<String, String> info;
}

class _AiffMetadata {
  const _AiffMetadata({required this.tag});

  final _Id3Tag? tag;
}

class _ApeMetadata {
  const _ApeMetadata({required this.values, required this.picture});

  final Map<String, List<String>> values;
  final Id3Picture? picture;
}

class _AsfMetadata {
  const _AsfMetadata({required this.values, required this.picture});

  final Map<String, List<String>> values;
  final Id3Picture? picture;
}

class _AsfExtendedMetadata {
  const _AsfExtendedMetadata({required this.values, required this.picture});

  final Map<String, List<String>> values;
  final Id3Picture? picture;
}

class _Mp4Atom {
  const _Mp4Atom({
    required this.type,
    required this.path,
    required this.payload,
  });

  final String type;
  final String path;
  final Uint8List payload;
}

const _mp4ContainerAtomTypes = {
  'moov',
  'trak',
  'mdia',
  'minf',
  'stbl',
  'udta',
  'meta',
  'ilst',
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
