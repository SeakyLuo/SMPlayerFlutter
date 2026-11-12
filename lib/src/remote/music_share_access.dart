import 'dart:io';

import '../library/data/library_models.dart';

abstract class MusicShareAccess {
  bool canWrite(String path);
  Future<Map<String, dynamic>> songRequest(
    String path,
    String resource, {
    String method = 'GET',
    Object? body,
  });
  Future<Uri> audioUri(String path);
  File? cachedArtwork(String path);
  Future<File?> artwork(String path);
  Future<LyricsSnapshot> lyrics(String path);
}

// Installed once by the application provider. Repositories used by pages and
// background lyric consumers resolve the same authorized device connections.
MusicShareAccess? activeMusicShareAccess;
