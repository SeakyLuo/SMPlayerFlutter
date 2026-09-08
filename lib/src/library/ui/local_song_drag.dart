import 'package:flutter/material.dart';
import 'local_folder_model.dart';
import 'local_song_location.dart';

class DraggableLocalSong extends StatelessWidget {
  const DraggableLocalSong({
    super.key,
    required this.payload,
    required this.feedbackWidth,
    required this.child,
    this.located = false,
  });

  final LocalItemsDragPayload payload;
  final double feedbackWidth;
  final Widget child;
  final bool located;

  @override
  Widget build(BuildContext context) {
    return Draggable<LocalItemsDragPayload>(
      data: payload,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(width: feedbackWidth, child: child),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.55, child: child),
      child: LocalSongLocationHighlight(active: located, child: child),
    );
  }
}
