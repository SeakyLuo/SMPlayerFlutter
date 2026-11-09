import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../library/data/library_models.dart';
import '../library/ui/popup_dialog.dart';
import '../library/ui/song_artwork.dart';
import 'music_source_providers.dart';

class RemoteSongDetails extends ConsumerStatefulWidget {
  const RemoteSongDetails({
    super.key,
    required this.song,
    required this.onClose,
  });
  final LibrarySong song;
  final VoidCallback onClose;
  @override
  ConsumerState<RemoteSongDetails> createState() => _RemoteSongDetailsState();
}

class _RemoteSongDetailsState extends ConsumerState<RemoteSongDetails> {
  String? _lyrics;
  @override
  void initState() {
    super.initState();
    unawaited(_loadLyrics());
  }

  Future<void> _loadLyrics() async {
    try {
      final lyrics = await ref
          .read(musicShareProvider)
          .lyrics(widget.song.path);
      if (mounted) setState(() => _lyrics = lyrics.rawText);
    } catch (_) {
      if (mounted) {
        setState(() => _lyrics = '');
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t('share.connectionFailed'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final share = ref.watch(musicShareProvider);
    final device = Uri.parse(widget.song.path).host;
    final name =
        share.peers.where((peer) => peer.id == device).firstOrNull?.name ??
        i18n.t('share.disconnectedComputer');
    return PopupDialog(
      navLabel: widget.song.title,
      navChildren: [Text(i18n.t('share.remoteSong'))],
      onClose: widget.onClose,
      width: 620,
      height: 650,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: SongArtwork(artworkPath: widget.song.thumbnailPath),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.song.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(widget.song.artists.join(' / ')),
          Text(widget.song.album),
          const SizedBox(height: 8),
          Text('${i18n.t('share.source')}: $name'),
          if (!widget.song.remoteAvailable) Text(i18n.t('share.songRemoved')),
          const SizedBox(height: 24),
          if (_lyrics == null)
            const LinearProgressIndicator()
          else if (_lyrics!.isNotEmpty)
            SelectableText(_lyrics!),
        ],
      ),
    );
  }
}
