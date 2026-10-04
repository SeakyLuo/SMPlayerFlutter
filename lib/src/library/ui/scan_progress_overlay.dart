import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/clipped_rounded_surface.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_widgets.dart';
import 'package:smplayer_flutter/src/app/window_drag_provider.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'local_folder_model.dart';
import 'local_page_quick_jump.dart';

class ScanProgressOverlay extends StatefulWidget {
  const ScanProgressOverlay({
    super.key,
    required this.title,
    required this.progress,
    required this.onCancel,
    this.onRunInBackground,
    this.collapsing = false,
    this.collapseAlignment = Alignment.topRight,
  });

  final String title;
  final LocalFolderRefreshProgress progress;
  final VoidCallback? onCancel;
  final VoidCallback? onRunInBackground;
  final bool collapsing;
  final Alignment collapseAlignment;

  @override
  State<ScanProgressOverlay> createState() => _ScanProgressOverlayState();
}

class _ScanProgressOverlayState extends State<ScanProgressOverlay> {
  final _overlayController = OverlayPortalController(
    debugLabel: 'ScanProgressOverlay',
  );

  String get title => widget.title;
  LocalFolderRefreshProgress get progress => widget.progress;
  VoidCallback? get onCancel => widget.onCancel;

  @override
  void initState() {
    super.initState();
    _overlayController.show();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: _buildOverlay,
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = LocalPageColors.of(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final value = localFolderRefreshOverallProgress(progress);
    final providerContainer = ProviderScope.containerOf(context);
    final windowDragCallbacks = providerContainer.read(
      smPlayerWindowDragProvider,
    );
    final windowControls =
        Platform.isWindows
            ? providerContainer.read(smPlayerWindowControlsProvider)
            : null;
    final stageText = switch (progress.stage) {
      LocalFolderRefreshStage.checking => i18n.t(
        'local.updateFolderProgressActionChecking',
      ),
      LocalFolderRefreshStage.reading => i18n.t(
        'local.updateFolderProgressActionReading',
      ),
      LocalFolderRefreshStage.updating => i18n.t(
        'local.updateFolderProgressActionUpdating',
      ),
      LocalFolderRefreshStage.finalizing => i18n.t(
        'local.updateFolderProgressActionFinalizing',
      ),
      LocalFolderRefreshStage.completed => i18n.t('local.scanLibraryDone'),
    };

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            tween: Tween(end: widget.collapsing ? 1 : 0),
            builder: (context, value, child) {
              return Opacity(
                opacity: 1 - value,
                child: Transform.scale(
                  scale: 1 - value * 0.9,
                  alignment: widget.collapseAlignment,
                  child: child,
                ),
              );
            },
            child: FocusScope(
              autofocus: true,
              child: Material(
                color: Colors.transparent,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: ColoredBox(
                      color:
                          nightMode
                              ? const Color(0x7004080d)
                              : const Color(0x47181e26),
                      child: Semantics(
                        label: title,
                        namesRoute: true,
                        scopesRoute: true,
                        explicitChildNodes: true,
                        child: SafeArea(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  34,
                                  28,
                                  34,
                                  26,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      nightMode
                                          ? const Color(0xf0161c24)
                                          : const Color(0xf0ffffff),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color:
                                        nightMode
                                            ? const Color(0x24d6e0ec)
                                            : const Color(0xb3ccd5e0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          nightMode
                                              ? const Color(0x7a000000)
                                              : const Color(0x3d1a2738),
                                      blurRadius: 80,
                                      offset: const Offset(0, 26),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colors.accentSoft,
                                          ),
                                          child: _LocalRefreshSpinner(
                                            color: colors.accentStrong,
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              color: colors.textStrong,
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 26),
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(
                                        22,
                                        20,
                                        22,
                                        20,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            nightMode
                                                ? const Color(0xb8121820)
                                                : const Color(0x94ffffff),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color:
                                              nightMode
                                                  ? const Color(0x24d6e0ec)
                                                  : const Color(0xb8ccd5e0),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              TweenAnimationBuilder<double>(
                                                tween: Tween(end: value),
                                                duration:
                                                    scanProgressTransitionDuration,
                                                builder:
                                                    (context, value, child) =>
                                                        _LocalRefreshPercent(
                                                          value: value,
                                                          percent:
                                                              (value * 100)
                                                                  .round(),
                                                        ),
                                              ),
                                              const SizedBox(width: 18),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      stageText,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color:
                                                            colors.textStrong,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 7),
                                                    for (final description
                                                        in _progressDescriptions(
                                                          i18n,
                                                        ))
                                                      Text(
                                                        description,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          color:
                                                              colors.textMuted,
                                                          fontSize: 14,
                                                          height: 1.5,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 18),
                                          _LocalRefreshStats(
                                            progress: progress,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (onCancel != null ||
                                        widget.onRunInBackground != null) ...[
                                      const SizedBox(height: 28),
                                      Center(
                                        child: Wrap(
                                          spacing: 12,
                                          runSpacing: 10,
                                          alignment: WrapAlignment.center,
                                          children: [
                                            if (widget.onRunInBackground !=
                                                null)
                                              SizedBox(
                                                height: 48,
                                                child: OutlinedButton(
                                                  onPressed:
                                                      widget.onRunInBackground,
                                                  style: OutlinedButton.styleFrom(
                                                    minimumSize: const Size(
                                                      160,
                                                      48,
                                                    ),
                                                    foregroundColor:
                                                        colors.accentStrong,
                                                    side: BorderSide(
                                                      color: colors.accentStrong
                                                          .withValues(
                                                            alpha: 0.28,
                                                          ),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    textStyle: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    i18n.t(
                                                      'local.updateFolderProgressBackground',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (onCancel != null)
                                              SizedBox(
                                                height: 48,
                                                child: OutlinedButton(
                                                  onPressed:
                                                      progress.canCancel
                                                          ? onCancel
                                                          : null,
                                                  style: OutlinedButton.styleFrom(
                                                    minimumSize: const Size(
                                                      160,
                                                      48,
                                                    ),
                                                    foregroundColor:
                                                        const Color(0xffdc2626),
                                                    disabledForegroundColor:
                                                        const Color(0x9e5b697a),
                                                    side: const BorderSide(
                                                      color: Color(0x3ddc2626),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    textStyle: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    i18n.t(
                                                      'local.updateFolderProgressStop',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (windowDragCallbacks != null)
            Positioned(
              top: 0,
              left: 0,
              right:
                  windowControls == null ? 0 : WindowsAppTitleBar.controlsWidth,
              height: SmPlayerShellMetrics.minimalTitlebarHeight,
              child: ShellWindowDragRegion(
                onWindowDragStart: windowDragCallbacks.onStart,
                onWindowDragEnd: windowDragCallbacks.onEnd,
                child: const SizedBox.expand(),
              ),
            ),
          if (windowControls != null)
            Positioned(
              top: 0,
              right: 0,
              width: WindowsAppTitleBar.controlsWidth,
              height: SmPlayerShellMetrics.minimalTitlebarHeight,
              child: WindowsAppTitleBar(
                isMaximized: windowControls.isMaximized,
                light: windowControls.light,
                showDragRegion: false,
                onWindowDragStart: null,
                onWindowDragEnd: null,
                onTitlebarTap: () {},
                onMinimize: windowControls.onMinimize,
                onToggleMaximize: windowControls.onToggleMaximize,
                onClose: windowControls.onClose,
              ),
            ),
        ],
      ),
    );
  }

  List<String> _progressDescriptions(SmPlayerI18n i18n) {
    if (progress.stage == LocalFolderRefreshStage.finalizing ||
        progress.stage == LocalFolderRefreshStage.completed) {
      return [];
    }
    if (progress.stage == LocalFolderRefreshStage.checking) {
      final folderName =
          progress.currentPath.isEmpty
              ? i18n.t('local.updateFolderProgressPreparing')
              : getUpdateResultCurrentPathName(progress.currentPath);
      return [
        i18n.t('local.updateFolderProgressCurrentFolder', {'name': folderName}),
        i18n.t('local.updateFolderProgressChecked', {
          'count': progress.checkedFolderCount,
          'total': progress.folderCount,
        }),
      ];
    }
    if (progress.stage == LocalFolderRefreshStage.updating) {
      return [];
    }
    return [
      i18n.t('local.updateFolderProgressProcessedSongs', {
        'count': progress.processedSongCount,
        'total': progress.songCount,
      }),
    ];
  }
}

double localFolderRefreshOverallProgress(LocalFolderRefreshProgress progress) {
  final stageValue = (progress.current / progress.total).clamp(0, 1).toDouble();
  return switch (progress.stage) {
    LocalFolderRefreshStage.checking => stageValue * 0.80,
    LocalFolderRefreshStage.reading => 0.80 + stageValue * 0.16,
    LocalFolderRefreshStage.updating => 0.96 + stageValue * 0.03,
    LocalFolderRefreshStage.finalizing => 0.99 + stageValue * 0.01,
    LocalFolderRefreshStage.completed => 1,
  };
}

const scanProgressTransitionDuration = Duration(milliseconds: 240);

Future<void> finishLocalFolderRefreshProgress({
  required LocalFolderRefreshProgress progress,
  required void Function(LocalFolderRefreshProgress) onProgress,
}) async {
  onProgress(progress.completed());
  // Start the completion transition on a submitted frame, not while the
  // successful scan callback and overlay removal share the same frame.
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(scanProgressTransitionDuration);
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 150));
}

class _LocalRefreshSpinner extends StatefulWidget {
  const _LocalRefreshSpinner({required this.color});

  final Color color;

  @override
  State<_LocalRefreshSpinner> createState() => _LocalRefreshSpinnerState();
}

class _LocalRefreshSpinnerState extends State<_LocalRefreshSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: RotationTransition(
        turns: _controller,
        child: Icon(
          FluentIcons.arrow_sync_24_regular,
          color: widget.color,
          size: 30,
        ),
      ),
    );
  }
}

String getUpdateResultCurrentPathName(String filePath) {
  final name = normalizePath(filePath).split('/').last;
  final extensionIndex = name.lastIndexOf('.');
  return extensionIndex > 0 ? name.substring(0, extensionIndex) : name;
}

class _LocalRefreshPercent extends StatelessWidget {
  const _LocalRefreshPercent({required this.value, required this.percent});

  final double value;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 16,
              strokeCap: StrokeCap.butt,
              backgroundColor:
                  nightMode ? const Color(0x24d6e0ec) : const Color(0x297e8b9a),
              color: colors.accentStrong,
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  nightMode ? const Color(0xff19212c) : const Color(0xffeef4fc),
            ),
          ),
          Text(
            '$percent%',
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalRefreshStats extends StatelessWidget {
  const _LocalRefreshStats({required this.progress});

  final LocalFolderRefreshProgress progress;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = LocalPageColors.of(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return SmPlayerClippedRoundedSurface(
      color: nightMode ? const Color(0x12ffffff) : const Color(0x94ffffff),
      radius: 8,
      borderSide: BorderSide(
        color: nightMode ? const Color(0x24d6e0ec) : const Color(0xb3ccd5e0),
      ),
      child: Row(
        children: [
          _LocalRefreshStat(
            label: i18n.t('local.updateFolderProgressAdded'),
            value: progress.addedCount,
            valueColor: const Color(0xff059669),
          ),
          const _LocalRefreshDivider(),
          _LocalRefreshStat(
            label: i18n.t('local.updateFolderProgressUpdated'),
            value: progress.updatedCount,
            valueColor: colors.accentStrong,
          ),
          const _LocalRefreshDivider(),
          _LocalRefreshStat(
            label: i18n.t('local.updateFolderProgressMissing'),
            value: progress.missingCount,
            valueColor: const Color(0xffdc2626),
          ),
        ],
      ),
    );
  }
}

class _LocalRefreshDivider extends StatelessWidget {
  const _LocalRefreshDivider();

  @override
  Widget build(BuildContext context) {
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 42,
      color: nightMode ? const Color(0x24d6e0ec) : const Color(0xb3ccd5e0),
    );
  }
}

class _LocalRefreshStat extends StatelessWidget {
  const _LocalRefreshStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final int value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final unit = context.smPlayerI18n.t('local.updateFolderProgressSongUnit');
    final colors = LocalPageColors.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$label '),
              TextSpan(
                text: '$value',
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(text: ' $unit'),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
