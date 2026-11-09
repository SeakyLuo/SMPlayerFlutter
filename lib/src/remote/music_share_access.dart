import 'dart:io';

import '../library/data/library_models.dart';

abstract class MusicShareAccess {
  Future<Uri> audioUri(String path);
  Future<File?> artwork(String path);
  Future<LyricsSnapshot> lyrics(String path);
}

// Installed once by the application provider. Repositories used by pages and
// background lyric consumers resolve the same authorized device connections.
MusicShareAccess? activeMusicShareAccess;
