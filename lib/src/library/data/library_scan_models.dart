part of 'library_models.dart';

class LocalFolderRefreshResult {
  const LocalFolderRefreshResult({
    required this.libraryChanged,
    required this.requiresFullReload,
    required this.filesAdded,
    required this.filesUpdated,
    required this.filesRemoved,
    required this.filesMoved,
    required this.artistSplitsApplied,
    required this.artistSplitSuggestions,
    required this.artistMergeSuggestions,
    this.songIdsByPath = const {},
  });

  final Map<String, int> songIdsByPath;
  final bool libraryChanged;
  final bool requiresFullReload;
  final List<String> filesAdded;
  final List<String> filesUpdated;
  final List<String> filesRemoved;
  final List<String> filesMoved;
  final List<ArtistSplitResultItem> artistSplitsApplied;
  final List<ArtistSplitResultItem> artistSplitSuggestions;
  final List<ArtistSplitResultItem> artistMergeSuggestions;

  bool get hasChanges =>
      filesAdded.isNotEmpty ||
      filesUpdated.isNotEmpty ||
      filesRemoved.isNotEmpty ||
      filesMoved.isNotEmpty ||
      artistSplitsApplied.isNotEmpty ||
      artistSplitSuggestions.isNotEmpty ||
      artistMergeSuggestions.isNotEmpty;
}

enum LocalFolderRefreshStage {
  checking,
  reading,
  updating,
  finalizing,
  completed,
}

class LocalFolderScanCanceledException implements Exception {
  const LocalFolderScanCanceledException();
}

class LocalFolderScanCancellation {
  var _canceled = false;
  final _cancellation = Completer<void>();
  Future<void> get whenCanceled => _cancellation.future;

  bool get isCanceled => _canceled;

  void cancel() {
    if (_canceled) return;
    _canceled = true;
    _cancellation.complete();
  }

  void throwIfCanceled() {
    if (_canceled) {
      throw const LocalFolderScanCanceledException();
    }
  }
}

class LocalFolderRefreshProgress {
  const LocalFolderRefreshProgress({
    required this.current,
    required this.total,
    required this.currentPath,
    this.stage = LocalFolderRefreshStage.updating,
    this.checkedFolderCount = 0,
    this.folderCount = 0,
    this.processedSongCount = 0,
    this.songCount = 0,
    this.addedCount = 0,
    this.updatedCount = 0,
    this.missingCount = 0,
    this.canCancel = false,
  });

  final int current;
  final int total;
  final String currentPath;
  final LocalFolderRefreshStage stage;
  final int checkedFolderCount;
  final int folderCount;
  final int processedSongCount;
  final int songCount;
  final int addedCount;
  final int updatedCount;
  final int missingCount;
  final bool canCancel;

  LocalFolderRefreshProgress completed() => LocalFolderRefreshProgress(
    stage: LocalFolderRefreshStage.completed,
    current: 1,
    total: 1,
    currentPath: '',
    checkedFolderCount: checkedFolderCount,
    folderCount: folderCount,
    processedSongCount: processedSongCount,
    songCount: songCount,
    addedCount: addedCount,
    updatedCount: updatedCount,
    missingCount: missingCount,
  );
}
