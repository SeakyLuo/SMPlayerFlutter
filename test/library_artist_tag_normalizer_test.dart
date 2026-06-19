import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/data/library_artist_tag_normalizer.dart';

void main() {
  test('keeps tag text as normal trimmed text', () {
    expect(normalizeTagText('  ÃÜ  '), 'ÃÜ');
  });

  test('drops artist when it only joins artists with common separators', () {
    final artists = normalizeArtists(
      normalizeArtistTagValues(['周杰伦', '温岚'], '周杰伦, 温岚'),
    );

    expect(artists, ['周杰伦', '温岚']);
  });

  test('explodes composite artist value when artist is one contained part', () {
    final artists = normalizeArtists(
      normalizeArtistTagValues(['周杰伦, 温岚'], '温岚'),
    );

    expect(artists, ['周杰伦', '温岚']);
  });

  test(
    'preserves slash artist value covered by artists for smart splitting',
    () {
      final artists = normalizeArtists(
        normalizeArtistTagValues(['Alice', 'Bob'], 'Alice/Bob'),
      );

      expect(artists, ['Alice/Bob']);
    },
  );

  test('drops parenthetical alias when base artist is already present', () {
    final artists = normalizeArtists(
      normalizeArtistTagValues(['Jay Chou'], 'Jay Chou (周杰伦)'),
    );

    expect(artists, ['Jay Chou']);
  });

  test('normalizes shared artist values without comma or slash splitting', () {
    expect(normalizeArtists(['Alpha; Beta；Gamma、Delta|Epsilon']), [
      'Alpha',
      'Beta',
      'Gamma',
      'Delta',
      'Epsilon',
    ]);
    expect(normalizeArtists(['Earth, Wind & Fire', 'Alice/Bob']), [
      'Earth, Wind & Fire',
      'Alice/Bob',
    ]);
  });
}
