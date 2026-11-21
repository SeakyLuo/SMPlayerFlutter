part of 'library_lyrics_service.dart';

class LyricsBatchBackup {
  LyricsBatchBackup._({
    required this.songPath,
    required List<({File file, File backup, bool existed})> sidecars,
    required File? embedded,
    required this.bytes,
  }) : _sidecars = sidecars,
       _embedded = embedded;

  final String songPath;
  final List<({File file, File backup, bool existed})> _sidecars;
  final File? _embedded;
  final int bytes;
  var _restored = false;

  bool get restored => _restored;
}

extension LibraryLyricsBatchBackup on LibraryLyricsService {
  Future<LyricsBatchBackup?> _backUpBatchLyrics(
    String songPath,
    String originalLyrics,
  ) async {
    final lrc = File(p.setExtension(songPath, '.lrc'));
    final txt = File(p.setExtension(songPath, '.txt'));
    final hasLrc = await lrc.exists();
    final hasTxt = await txt.exists();
    final writesEmbedded = p.extension(songPath).toLowerCase() == '.mp3';
    final sidecars = <({File file, bool exists})>[
      if (writesEmbedded) ...[
        if (hasLrc) (file: lrc, exists: true),
        if (hasTxt) (file: txt, exists: true),
      ] else if (hasTxt && !hasLrc)
        (file: txt, exists: true)
      else
        (file: lrc, exists: hasLrc),
    ];

    final embedded =
        writesEmbedded
            ? await _id3TagService.readEmbeddedLyricsBackup(songPath)
            : null;
    if (!hasLrc &&
        !hasTxt &&
        (embedded == null || embedded.isEmpty) &&
        originalLyrics.trim().isEmpty) {
      return null;
    }

    final directory = await Directory(
      p.dirname(songPath),
    ).createTemp('${p.basename(songPath)}.lyrics-backup-');
    try {
      var bytes = 0;
      final backups = <({File file, File backup, bool existed})>[];
      for (final sidecar in sidecars) {
        final backup = File(
          p.join(directory.path, 'sidecar${p.extension(sidecar.file.path)}'),
        );
        if (sidecar.exists) {
          final original = await sidecar.file.readAsBytes();
          await backup.writeAsBytes(original, flush: true);
          bytes += original.length;
        }
        backups.add((
          file: sidecar.file,
          backup: backup,
          existed: sidecar.exists,
        ));
      }

      File? embeddedFile;
      if (embedded != null) {
        embeddedFile = File(p.join(directory.path, 'embedded.id3'));
        await embeddedFile.writeAsBytes(embedded, flush: true);
        bytes += embedded.length;
      }
      if (originalLyrics.trim().isNotEmpty) {
        final original = utf8.encode(originalLyrics);
        await File(
          p.join(directory.path, 'original.lrc'),
        ).writeAsBytes(original, flush: true);
        bytes += original.length;
      }
      return LyricsBatchBackup._(
        songPath: songPath,
        sidecars: backups,
        embedded: embeddedFile,
        bytes: bytes,
      );
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> _applyBatchLyrics(
    LyricsBatchBackup backup,
    String rawLyrics,
  ) async {
    if (backup._embedded != null) {
      await _id3TagService.writeEmbeddedLyrics(backup.songPath, rawLyrics);
    }
    for (final entry in backup._sidecars) {
      await entry.file.writeAsString(rawLyrics, flush: true);
    }
  }

  Future<bool> changeBatchLyricsOverwrite(
    File databaseFile,
    LyricsBatchDetail detail,
  ) async {
    final backup = detail.backup!;
    final songPath = _getSongPath(databaseFile, detail.songId);
    if (songPath != backup.songPath) return false;

    final target = utf8.encode(detail.targetRawLyrics);
    final originals = <File, List<int>?>{};
    for (final entry in backup._sidecars) {
      final original = entry.existed ? await entry.backup.readAsBytes() : null;
      final current =
          await entry.file.exists() ? await entry.file.readAsBytes() : null;
      if (!_sameLyricsBytes(current, original) &&
          !_sameLyricsBytes(current, target)) {
        return false;
      }
      originals[entry.file] = original;
    }
    final embedded = await backup._embedded?.readAsBytes();
    if (embedded != null &&
        !await _id3TagService.matchesBatchEmbeddedLyrics(
          songPath,
          embedded,
          detail.targetRawLyrics,
        )) {
      return false;
    }

    if (backup.restored) {
      await _applyBatchLyrics(backup, detail.targetRawLyrics);
    } else {
      if (embedded != null) {
        await _id3TagService.restoreEmbeddedLyrics(songPath, embedded);
      }
      for (final entry in originals.entries) {
        final original = entry.value;
        if (original != null) {
          await entry.key.writeAsBytes(original, flush: true);
        } else if (await entry.key.exists()) {
          await entry.key.delete();
        }
      }
    }
    backup._restored = !backup.restored;
    return true;
  }
}

bool _sameLyricsBytes(List<int>? first, List<int>? second) {
  if (first == null || second == null) return first == second;
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}
