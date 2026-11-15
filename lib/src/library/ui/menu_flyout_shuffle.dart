part of 'menu_flyout_helpers.dart';

// The playing queue belongs to this client, independently of library source.
List<MenuFlyoutItem> buildQueueShuffleMenuFlyoutItems({
  required SmPlayerI18n i18n,
  required List<LibrarySong> songs,
  required ValueChanged<List<int>> onPlaySongs,
}) => [
  if (songs.isNotEmpty)
    MenuFlyoutItem(
      key: 'now-playing',
      text: i18n.t('common.nowPlaying'),
      icon: FluentIcons.headphones_24_regular,
      onPressed:
          () => onPlaySongs(songs.map((song) => song.id).toList()..shuffle()),
    ),
];
