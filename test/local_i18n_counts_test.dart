import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/local_i18n_counts.dart';

void main() {
  const i18n = SmPlayerI18n(locale: 'en-US', messages: {});

  test('formatFolderCardStats mirrors Electron English plurals', () {
    expect(formatFolderCardStats(i18n, 1, 1), '1 folder · 1 song');
    expect(formatFolderCardStats(i18n, 1, 3), '1 folder · 3 songs');
    expect(formatFolderCardStats(i18n, 2, 1), '2 folders · 1 song');
    expect(formatFolderCardStats(i18n, 2, 3), '2 folders · 3 songs');
  });

  test('formatLocalFolderSongCount mirrors Electron English plurals', () {
    expect(formatLocalFolderSongCount(i18n, 0), '0 songs');
    expect(formatLocalFolderSongCount(i18n, 1), '1 song');
    expect(formatLocalFolderSongCount(i18n, 2), '2 songs');
  });
}
