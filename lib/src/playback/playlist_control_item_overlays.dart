part of 'playlist_control_item.dart';

class _QueuePlayingOverlay extends StatelessWidget {
  const _QueuePlayingOverlay({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    return SmPlayerPlayingWaveGlass(
      playing: playing,
      dimension: 38,
      backgroundColor: _PlaylistControlItemColors.playingOverlay,
      shadowColor: _PlaylistControlItemColors.playingOverlayShadow,
      keyPrefix: 'PlaylistControlItem.Playing',
    );
  }
}

class _QueuePlayOverlayButton extends StatelessWidget {
  const _QueuePlayOverlayButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ArtworkFloatingActionButton(
      key: const ValueKey('PlaylistControlItem.PlayOverlayButton'),
      tooltip: tooltip,
      size: 38,
      iconSize: 17,
      icon: icon,
      onPressed: onPressed,
    );
  }
}
