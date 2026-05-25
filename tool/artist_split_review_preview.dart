import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/settings/artist_split_review_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    SmPlayerI18nScope(
      i18n: _i18n,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          extensions: const [DefaultAlbumArtworkThemeColors.light],
        ),
        home: const ArtistSplitReviewDialog(
          result: _result,
          applying: false,
          onCancel: _noop,
          onApply: _noopApply,
        ),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    dismissNativeSplash();
  });
}

void _noop() {}

void _noopApply(List<ArtistSplitResultItem> splits) {}

const _result = ArtistSplitAnalysisResult(
  directSplits: [
    ArtistSplitResultItem(
      songId: 1,
      title: 'Glass City Lights',
      artist: 'Lena Park / Gray Line',
      artists: ['Lena Park', 'Gray Line'],
    ),
  ],
  possibleSplits: [
    ArtistSplitResultItem(
      songId: 2,
      title: 'Night Transfer',
      artist: 'Mira, Altair',
      artists: ['Mira', 'Altair'],
    ),
  ],
  mergeSuggestions: [
    ArtistSplitResultItem(
      songId: 3,
      title: 'After Rain',
      artist: 'Hana',
      artists: ['Hana', 'HANA'],
    ),
  ],
);

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.add': 'Add',
    'common.close': 'Close',
    'common.edit': 'Edit',
    'local.applyingArtistSplits': 'Applying...',
    'local.applySelectedArtistSplits': 'Apply selected ({count})',
    'local.artistMergeAfter': 'After',
    'local.artistMergeSuggestionsTitle': 'Ready to Merge Artists',
    'local.artistSplitAfter': 'After',
    'local.artistSplitOriginal': 'Original',
    'local.clearArtistSplitSelection': 'Clear',
    'local.directArtistSplitsTitle': 'Direct splits',
    'local.keepArtistSplits': 'Keep as is',
    'local.refreshArtistSplitSuggestionsTitle': 'Possible splits',
    'local.selectAllArtistSplits': 'Select all',
    'local.startupArtistSplitSuggestionsTitle': 'Artist update suggestions',
    'playlists.removeSelected': 'Remove',
    'settings.save': 'Save',
  },
);
