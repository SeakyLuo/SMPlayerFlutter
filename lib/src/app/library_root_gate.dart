part of 'app_router.dart';

Future<LocalFolderRefreshResult> _scanLibraryRootAndReload(
  WidgetRef ref,
  String rootPath,
  SettingsController? settingsController, {
  LocalFolderScanCancellation? cancellation,
  void Function(LocalFolderRefreshProgress)? onProgress,
}) async {
  final result = await ref
      .read(libraryRepositoryProvider)
      .scanAllMusicLibrary(
        rootPath,
        cancellation: cancellation,
        onProgress: onProgress,
      );
  await settingsController?.updateSettings(
    AppSettingsUpdate(rootPath: rootPath),
  );
  _invalidateLibraryData(ref);
  await Future.wait([
    ref.read(libraryContentDataProvider.future),
    ref.read(librarySongCountProvider.future),
    ref.read(recentPageDataProvider.future),
    ref.read(shellNavigationDataProvider.future),
  ]);
  return result;
}

class _LibraryRootGate extends ConsumerStatefulWidget {
  const _LibraryRootGate({
    required this.path,
    required this.child,
    this.settingsController,
  });

  final String path;
  final Widget child;
  final SettingsController? settingsController;

  @override
  ConsumerState<_LibraryRootGate> createState() => _LibraryRootGateState();
}

class _LibraryRootGateState extends ConsumerState<_LibraryRootGate> {
  var _scanning = false;
  LocalFolderRefreshProgress? _progress;
  LocalFolderScanCancellation? _cancellation;
  ({String rootPath, LocalFolderRefreshResult result})? _result;

  @override
  Widget build(BuildContext context) {
    if (!_isLibraryRootGatedRoute(widget.path)) {
      return widget.child;
    }

    final libraryValue = ref.watch(shellNavigationDataProvider);
    final content = libraryValue.when(
      data:
          (library) =>
              library.rootPath.isEmpty
                  ? _MissingLibraryRootPage(
                    loading: false,
                    buttonLoading: _scanning,
                    onPickLibraryRoot:
                        _scanning
                            ? null
                            : () {
                              unawaited(_pickLibraryRootAndScan());
                            },
                  )
                  : widget.child,
      loading: () => const _MissingLibraryRootPage(loading: true),
      error:
          (_, _) => _MissingLibraryRootPage(
            loading: false,
            buttonLoading: _scanning,
            onPickLibraryRoot:
                _scanning
                    ? null
                    : () {
                      unawaited(_pickLibraryRootAndScan());
                    },
          ),
    );
    final result = _result;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (_progress case final progress?)
          ScanProgressOverlay(
            title: context.smPlayerI18n.t('local.updateFolderProgressTitle'),
            progress: progress,
            onCancel: progress.canCancel ? _cancelScan : null,
          ),
        if (result != null)
          FolderUpdateResultDialog(
            folder: createFolderNode('', result.rootPath),
            result: result.result,
            songs:
                ref.watch(libraryContentDataProvider).valueOrNull?.songs ??
                const [],
            selectedTrackId: null,
            isPlaying: false,
            onApplyArtistSplits: (splits) async {
              await ref
                  .read(libraryRepositoryProvider)
                  .applyArtistSplits(splits);
              _invalidateLibraryData(ref);
              if (!mounted) return;
              _removeArtistSuggestions(
                splits.map((item) => item.songId).toSet(),
              );
              showAppNotification(
                context: this.context,
                message: this.context.smPlayerI18n.t('common.saved'),
              );
            },
            onDismissArtistSplitSuggestions:
                () => _removeArtistSuggestions({
                  ...result.result.artistSplitsApplied.map(
                    (item) => item.songId,
                  ),
                  ...result.result.artistSplitSuggestions.map(
                    (item) => item.songId,
                  ),
                  ...result.result.artistMergeSuggestions.map(
                    (item) => item.songId,
                  ),
                }),
            onClose: () => setState(() => _result = null),
          ),
      ],
    );
  }

  void _removeArtistSuggestions(Set<int> ids) {
    final current = _result!;
    final result = current.result;
    setState(() {
      _result = (
        rootPath: current.rootPath,
        result: LocalFolderRefreshResult(
          libraryChanged: result.libraryChanged,
          requiresFullReload: result.requiresFullReload,
          filesAdded: result.filesAdded,
          filesUpdated: result.filesUpdated,
          filesRemoved: result.filesRemoved,
          filesMoved: result.filesMoved,
          artistSplitsApplied:
              result.artistSplitsApplied
                  .where((item) => !ids.contains(item.songId))
                  .toList(),
          artistSplitSuggestions:
              result.artistSplitSuggestions
                  .where((item) => !ids.contains(item.songId))
                  .toList(),
          artistMergeSuggestions:
              result.artistMergeSuggestions
                  .where((item) => !ids.contains(item.songId))
                  .toList(),
        ),
      );
    });
  }

  Future<void> _cancelScan() async {
    final cancellation = _cancellation!;
    final i18n = context.smPlayerI18n;
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('local.updateFolderProgressStopConfirmTitle'),
      message: i18n.t('local.updateFolderProgressStopConfirmMessage'),
      confirmText: i18n.t('local.updateFolderProgressStopConfirm'),
    );
    if (confirmed) cancellation.cancel();
  }

  void _setProgress(LocalFolderRefreshProgress progress) {
    if (mounted) setState(() => _progress = progress);
  }

  Future<void> _pickLibraryRootAndScan() async {
    final i18n = context.smPlayerI18n;
    setState(() {
      _scanning = true;
    });
    try {
      final rootPath = await pickMusicLibraryRoot(i18n);
      if (rootPath == null || rootPath.isEmpty) {
        return;
      }

      final cancellation = LocalFolderScanCancellation();
      _cancellation = cancellation;
      _setProgress(
        const LocalFolderRefreshProgress(
          current: 0,
          total: 1,
          currentPath: '',
          stage: LocalFolderRefreshStage.checking,
          canCancel: true,
        ),
      );
      final result = await _scanLibraryRootAndReload(
        ref,
        rootPath,
        widget.settingsController,
        cancellation: cancellation,
        onProgress: _setProgress,
      );
      if (!mounted) return;
      await finishLocalFolderRefreshProgress(
        progress: _progress!,
        onProgress: _setProgress,
      );
      if (mounted) {
        setState(() => _result = (rootPath: rootPath, result: result));
      }
    } on LocalFolderScanCanceledException {
      // The scan transaction is rolled back when cancellation is accepted.
    } on PlatformException {
      if (mounted) {
        showAppNotification(
          context: context,
          message: i18n.t('library.folderPickerUnavailable'),
        );
      }
    } catch (error) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: getRefreshFolderErrorMessage(
            error is StateError ? error.message : error.toString(),
            i18n,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _progress = null;
          _cancellation = null;
        });
      }
    }
  }
}

class _MissingLibraryRootPage extends StatelessWidget {
  const _MissingLibraryRootPage({
    required this.loading,
    this.buttonLoading = false,
    this.onPickLibraryRoot,
  });

  final bool loading;
  final bool buttonLoading;
  final VoidCallback? onPickLibraryRoot;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SmPlayerLoadingState();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: MissingLibraryRootContent(
        buttonLoading: buttonLoading,
        onPickLibraryRoot: onPickLibraryRoot,
      ),
    );
  }
}
