part of 'music_dialog.dart';

class MusicAlbumArtControl extends StatelessWidget {
  const MusicAlbumArtControl({
    super.key,
    required this.song,
    required this.loading,
    required this.operation,
    required this.artworkUrl,
    required this.artworkDirty,
    required this.recommendation,
    required this.onApplyRecommendation,
    required this.onChangeArtwork,
    required this.onChooseArtworkFromLibrary,
    required this.onSaveArtwork,
    required this.onResetArtwork,
    required this.onRequestDelete,
  });

  final LibrarySong song;
  final bool loading;
  final MusicDialogOperation? operation;
  final String artworkUrl;
  final bool artworkDirty;
  final AlbumArtRecommendation? recommendation;
  final ValueChanged<AlbumArtRecommendation> onApplyRecommendation;
  final VoidCallback onChangeArtwork;
  final VoidCallback onChooseArtworkFromLibrary;
  final VoidCallback onSaveArtwork;
  final VoidCallback onResetArtwork;
  final VoidCallback onRequestDelete;

  @override
  Widget build(BuildContext context) {
    final saving = operation == MusicDialogOperation.saveArtwork;
    final changingArtwork = operation == MusicDialogOperation.changeArtwork;
    return AlbumArtEditorControl(
      loading: loading,
      saving: saving,
      changingArtwork: changingArtwork,
      showBusy: false,
      artworkUrl: artworkUrl,
      artworkDirty: artworkDirty,
      recommendation: recommendation,
      songId: song.id,
      fallbackArtwork: true,
      onApplyRecommendation: operation == null ? onApplyRecommendation : null,
      onChangeArtwork: onChangeArtwork,
      onChooseArtworkFromLibrary: onChooseArtworkFromLibrary,
      onSaveArtwork: onSaveArtwork,
      onResetArtwork: artworkDirty ? onResetArtwork : null,
      onRequestDelete: onRequestDelete,
    );
  }
}

class AlbumArtEditorControl extends ConsumerStatefulWidget {
  const AlbumArtEditorControl({
    super.key,
    this.loading = false,
    required this.saving,
    this.changingArtwork = false,
    required this.showBusy,
    required this.artworkUrl,
    required this.artworkDirty,
    this.recommendation,
    this.songId,
    this.fallbackArtwork = false,
    this.onApplyRecommendation,
    required this.onChangeArtwork,
    this.onChooseArtworkFromLibrary,
    required this.onSaveArtwork,
    this.onResetArtwork,
    required this.onRequestDelete,
  });

  final bool loading;
  final bool saving;
  final bool changingArtwork;
  final bool showBusy;
  final String artworkUrl;
  final bool artworkDirty;
  final AlbumArtRecommendation? recommendation;
  final int? songId;
  final bool fallbackArtwork;
  final ValueChanged<AlbumArtRecommendation>? onApplyRecommendation;
  final VoidCallback onChangeArtwork;
  final VoidCallback? onChooseArtworkFromLibrary;
  final VoidCallback onSaveArtwork;
  final VoidCallback? onResetArtwork;
  final VoidCallback onRequestDelete;

  @override
  ConsumerState<AlbumArtEditorControl> createState() =>
      _AlbumArtEditorControlState();
}

class _AlbumArtEditorControlState extends ConsumerState<AlbumArtEditorControl> {
  String _resolvedArtworkUrl = '';
  String _artworkRequestKey = '';

  @override
  void initState() {
    super.initState();
    _resolvedArtworkUrl = widget.artworkUrl;
    _syncResolvedArtwork();
  }

  @override
  void didUpdateWidget(covariant AlbumArtEditorControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkUrl != widget.artworkUrl ||
        oldWidget.songId != widget.songId) {
      _resolvedArtworkUrl = widget.artworkUrl;
      _syncResolvedArtwork();
    }
  }

  void _syncResolvedArtwork() {
    if (widget.artworkDirty && widget.artworkUrl.isEmpty) {
      _artworkRequestKey = '';
      return;
    }
    final songId = widget.songId;
    final directArtworkFile =
        widget.artworkUrl.isEmpty ? null : File(widget.artworkUrl);
    if (songId == null ||
        (directArtworkFile != null && directArtworkFile.existsSync())) {
      _artworkRequestKey = '';
      return;
    }

    final requestKey = '$songId|${widget.artworkUrl}';
    if (_artworkRequestKey == requestKey) {
      return;
    }
    _artworkRequestKey = requestKey;
    final repository = ref.read(libraryRepositoryProvider);
    repository
        .getSongArtworkSnapshots([songId])
        .then((snapshots) {
          if (!mounted || _artworkRequestKey != requestKey) {
            return;
          }
          final artworkUrl = snapshots.single.artworkUrl;
          if (artworkUrl == _resolvedArtworkUrl) {
            return;
          }
          setState(() {
            _resolvedArtworkUrl = artworkUrl;
          });
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final artworkUrl = _resolvedArtworkUrl;
    final artworkFile = artworkUrl.isEmpty ? null : File(artworkUrl);
    final hasArtworkFile = artworkFile != null && artworkFile.existsSync();
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final bodyPadding =
        mobile
            ? const EdgeInsets.fromLTRB(12, 0, 12, 28)
            : const EdgeInsets.fromLTRB(28, 0, 28, 44);
    final artworkDimension = math.min(
      340.0,
      MediaQuery.sizeOf(context).width - 92,
    );
    final operationRunning = widget.saving || widget.changingArtwork;

    return Column(
      children: [
        _MusicDialogCommandBar(
          showBusy: widget.showBusy,
          children: [
            _MusicDialogCommandButton(
              iconWidget: const _ElectronIcon(
                _ElectronIconName.trash,
                size: 20,
              ),
              label: i18n.t('playlists.delete'),
              commandBar: true,
              disabled: widget.loading || operationRunning || !hasArtworkFile,
              onPressed: widget.onRequestDelete,
            ),
            _ArtworkSourceButton(
              loading: widget.changingArtwork,
              disabled: widget.loading || widget.saving,
              onChangeArtwork: widget.onChangeArtwork,
              onChooseArtworkFromLibrary: widget.onChooseArtworkFromLibrary,
            ),
            _MusicDialogCommandButton(
              iconWidget: const _ElectronIcon(_ElectronIconName.save, size: 20),
              label: i18n.t('settings.save'),
              primary: true,
              commandBar: true,
              loading: widget.saving,
              disabled: widget.loading || widget.changingArtwork,
              onPressed: widget.onSaveArtwork,
            ),
            if (widget.onResetArtwork != null)
              _MusicDialogCommandButton(
                iconWidget: const _ElectronIcon(
                  _ElectronIconName.undo,
                  size: 20,
                ),
                label: i18n.t('common.reset'),
                commandBar: true,
                disabled: widget.loading || operationRunning,
                onPressed: widget.onResetArtwork,
              ),
          ],
        ),
        Expanded(
          child:
              widget.loading && !hasArtworkFile
                  ? const _AlbumArtLoadingShell()
                  : LayoutBuilder(
                    builder: (context, constraints) {
                      return _SongDialogScrollableBody(
                        padding: bodyPadding,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - bodyPadding.vertical,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                hasArtworkFile
                                    ? _AlbumArtworkImageShell(
                                      artworkFile: artworkFile,
                                      dimension: artworkDimension,
                                      forceLoadingOverlay: widget.loading,
                                    )
                                    : ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 500,
                                        maxHeight: 500,
                                      ),
                                      child: SizedBox.square(
                                        key: const ValueKey(
                                          'MusicDialog.AlbumArtFallbackShell',
                                        ),
                                        dimension: math.min(
                                          500.0,
                                          MediaQuery.sizeOf(context).width - 92,
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Center(
                                              child: Text(
                                                i18n.t('song.noAlbumArt'),
                                                style: TextStyle(
                                                  color: colors.text,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ),
                                            if (widget.recommendation != null &&
                                                widget.onApplyRecommendation !=
                                                    null)
                                              Align(
                                                alignment: const Alignment(
                                                  0,
                                                  0.18,
                                                ),
                                                child: _AlbumArtRecommendationText(
                                                  recommendation:
                                                      widget.recommendation!,
                                                  onApply:
                                                      widget
                                                          .onApplyRecommendation!,
                                                  showFallbackLabel: false,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _AlbumArtworkImageShell extends StatefulWidget {
  const _AlbumArtworkImageShell({
    required this.artworkFile,
    required this.dimension,
    this.forceLoadingOverlay = false,
  });

  final File artworkFile;
  final double dimension;
  final bool forceLoadingOverlay;

  @override
  State<_AlbumArtworkImageShell> createState() =>
      _AlbumArtworkImageShellState();
}

class _AlbumArtworkImageShellState extends State<_AlbumArtworkImageShell> {
  var _loaded = false;

  @override
  void didUpdateWidget(covariant _AlbumArtworkImageShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkFile.path != widget.artworkFile.path) {
      _loaded = false;
    }
  }

  void _handleFrameLoaded() {
    if (_loaded) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340, maxHeight: 340),
      child: SizedBox.square(
        key: const ValueKey('MusicDialog.AlbumArtworkImageShell'),
        dimension: widget.dimension,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            _AlbumArtworkImageShadow(dimension: widget.dimension),
            DecoratedBox(
              decoration: _albumArtworkImageDecoration(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  widget.artworkFile,
                  fit: BoxFit.cover,
                  frameBuilder: (
                    context,
                    child,
                    frame,
                    wasSynchronouslyLoaded,
                  ) {
                    if (wasSynchronouslyLoaded || frame != null) {
                      _handleFrameLoaded();
                    }
                    return Opacity(
                      opacity: _loaded && !widget.forceLoadingOverlay ? 1 : 0,
                      child: child,
                    );
                  },
                ),
              ),
            ),
            if (widget.forceLoadingOverlay || !_loaded)
              const _AlbumArtworkLoadingOverlay(),
          ],
        ),
      ),
    );
  }
}

class _AlbumArtworkImageShadow extends StatelessWidget {
  const _AlbumArtworkImageShadow({required this.dimension});

  final double dimension;

  @override
  Widget build(BuildContext context) {
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      left: -80,
      top: -80,
      right: -80,
      bottom: -80,
      child: IgnorePointer(
        child: CustomPaint(
          key: const ValueKey('MusicDialog.AlbumArtworkImageShadow'),
          painter: _AlbumArtworkImageShadowPainter(
            dimension: dimension,
            nightMode: nightMode,
          ),
        ),
      ),
    );
  }
}

class _AlbumArtworkImageShadowPainter extends CustomPainter {
  const _AlbumArtworkImageShadowPainter({
    required this.dimension,
    required this.nightMode,
  });

  final double dimension;
  final bool nightMode;

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - dimension) / 2;
    final top = (size.height - dimension) / 2 + 18;
    final paint =
        Paint()
          ..color =
              nightMode ? const Color(0x29202a3a) : const Color(0x29202a3a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, dimension, dimension),
        const Radius.circular(10),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AlbumArtworkImageShadowPainter oldDelegate) {
    return oldDelegate.dimension != dimension ||
        oldDelegate.nightMode != nightMode;
  }
}

class _AlbumArtworkLoadingOverlay extends StatelessWidget {
  const _AlbumArtworkLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('MusicDialog.AlbumArtworkLoadingOverlay'),
      decoration: _albumArtworkLoadingDecoration(context),
      child: const Center(child: _SongDialogStaticLoadingIndicator()),
    );
  }
}

class _AlbumArtLoadingShell extends StatelessWidget {
  const _AlbumArtLoadingShell();

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final bodyPadding =
        mobile
            ? const EdgeInsets.fromLTRB(12, 0, 12, 28)
            : const EdgeInsets.fromLTRB(28, 0, 28, 44);
    final artworkDimension = math.min(
      340.0,
      MediaQuery.sizeOf(context).width - 92,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: bodyPadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(
                0,
                constraints.maxHeight - bodyPadding.vertical,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 340,
                  maxHeight: 340,
                ),
                child: SizedBox.square(
                  key: const ValueKey('MusicDialog.AlbumArtLoadingShell'),
                  dimension: artworkDimension,
                  child: DecoratedBox(
                    decoration: _albumArtworkLoadingDecoration(context),
                    child: const Center(child: _SongDialogLoadingIndicator()),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SongDialogStaticLoadingIndicator extends StatelessWidget {
  const _SongDialogStaticLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return SizedBox.square(
      dimension: 38,
      child: CircularProgressIndicator(
        value: 0.28,
        strokeWidth: 3,
        color: colors.accent,
        backgroundColor: colors.accent.withValues(alpha: 0.16),
      ),
    );
  }
}

BoxDecoration _albumArtworkImageDecoration(BuildContext context) {
  final nightMode = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(10),
    color: nightMode ? const Color(0x14ffffff) : const Color(0xb8ffffff),
  );
}

BoxDecoration _albumArtworkLoadingDecoration(BuildContext context) {
  final colors = PopupDialogColors.resolve(context);
  final nightMode = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(10),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors:
          nightMode
              ? [colors.accent.withValues(alpha: 0.14), const Color(0xe60f141c)]
              : [
                colors.accent.withValues(alpha: 0.08),
                const Color(0xc7ffffff),
              ],
    ),
    color: nightMode ? const Color(0x14ffffff) : const Color(0xb8ffffff),
    boxShadow: const [
      BoxShadow(
        color: Color(0x1f202a3a),
        blurRadius: 42,
        offset: Offset(0, 18),
      ),
    ],
  );
}
