import 'dart:math';

class ArtistTextSortKey {
  ArtistTextSortKey({
    required int bucketIndex,
    required String pinyinKey,
    required String baseKey,
  }) : _bucketIndex = bucketIndex,
       _pinyinKey = _NaturalTextSortKey(pinyinKey),
       _baseKey = _NaturalTextSortKey(baseKey);

  final int _bucketIndex;
  final _NaturalTextSortKey _pinyinKey;
  final _NaturalTextSortKey _baseKey;

  int compareTo(ArtistTextSortKey other) {
    final bucketCompare = _bucketIndex.compareTo(other._bucketIndex);
    if (bucketCompare != 0) {
      return bucketCompare;
    }

    final pinyinCompare = _pinyinKey.compareTo(other._pinyinKey);
    return pinyinCompare != 0
        ? pinyinCompare
        : _baseKey.compareTo(other._baseKey);
  }
}

class _NaturalTextSortKey {
  _NaturalTextSortKey(String value)
    : _parts =
          _naturalTextPattern
              .allMatches(value)
              .map((match) => _NaturalTextPart(match.group(0)!))
              .toList();

  final List<_NaturalTextPart> _parts;

  int compareTo(_NaturalTextSortKey other) {
    final length = min(_parts.length, other._parts.length);
    for (var index = 0; index < length; index += 1) {
      final leftPart = _parts[index];
      final rightPart = other._parts[index];
      if (leftPart.number != null && rightPart.number != null) {
        final numberCompare = leftPart.number!.compareTo(rightPart.number!);
        if (numberCompare != 0) {
          return numberCompare;
        }
        final lengthCompare = leftPart.value.length.compareTo(
          rightPart.value.length,
        );
        if (lengthCompare != 0) {
          return lengthCompare;
        }
      } else {
        final textCompare = leftPart.value.compareTo(rightPart.value);
        if (textCompare != 0) {
          return textCompare;
        }
      }
    }
    return _parts.length.compareTo(other._parts.length);
  }
}

class _NaturalTextPart {
  _NaturalTextPart(this.value) : number = int.tryParse(value);

  final String value;
  final int? number;
}

final _naturalTextPattern = RegExp(r'\d+|\D+');
