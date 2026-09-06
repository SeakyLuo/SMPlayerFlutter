part of 'popup_dialog.dart';

class PopupDialog extends StatefulWidget {
  const PopupDialog({
    super.key,
    required this.navLabel,
    required this.onClose,
    required this.navChildren,
    required this.child,
    this.className = '',
    this.navClassName = '',
    this.ariaLabel,
    this.overlayClassName = '',
    this.afterNav,
    this.footer,
    this.closeOnBackdrop = false,
    this.fullScreenOnNarrow = true,
    this.width = 780,
    this.height = 760,
    this.horizontalInset = 48,
    this.verticalInset = 48,
    this.borderRadius = 12,
    this.onWindowDragStart,
    this.onWindowDragEnd,
  });

  final String className;
  final String navClassName;
  final String navLabel;
  final String? ariaLabel;
  final String overlayClassName;
  final List<Widget> navChildren;
  final Widget? afterNav;
  final Widget child;
  final Widget? footer;
  final VoidCallback onClose;
  final bool closeOnBackdrop;
  final bool fullScreenOnNarrow;
  final double width;
  final double height;
  final double horizontalInset;
  final double verticalInset;
  final double borderRadius;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;

  @override
  State<PopupDialog> createState() => _PopupDialogState();
}

class _PopupDialogState extends State<PopupDialog> {
  late final PopupDialogCloseHandler _closeHandler;
  final _overlayController = OverlayPortalController(debugLabel: 'PopupDialog');

  @override
  void initState() {
    super.initState();
    _closeHandler = () {
      widget.onClose();
    };
    _popupDialogCloseHandlers.add(_closeHandler);
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _overlayController.show();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _popupDialogCloseHandlers.remove(_closeHandler);
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    if (_popupDialogCloseHandlers.lastOrNull != _closeHandler) {
      return false;
    }
    widget.onClose();
    return true;
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
    final i18n =
        context.maybeSmPlayerI18n ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final colors = PopupDialogColors.resolve(context);
    final dialogClasses = _PopupDialogClassNames(
      className: widget.className,
      navClassName: widget.navClassName,
    );

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.escape) {
          return KeyEventResult.ignored;
        }
        if (_popupDialogCloseHandlers.lastOrNull != _closeHandler) {
          return KeyEventResult.ignored;
        }
        widget.onClose();
        return KeyEventResult.handled;
      },
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          label: widget.ariaLabel ?? widget.navLabel,
          namesRoute: true,
          scopesRoute: true,
          explicitChildNodes: true,
          child: _PopupDialogBackdrop(
            colors: colors,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.closeOnBackdrop ? widget.onClose : null,
                  child: const SizedBox.expand(),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final mobile =
                        widget.fullScreenOnNarrow &&
                        constraints.maxWidth <= popupDialogMobileBreakpoint;
                    final dialogWidth =
                        mobile
                            ? constraints.maxWidth
                            : (constraints.maxWidth - widget.horizontalInset)
                                .clamp(0.0, widget.width);
                    final dialogHeight =
                        mobile
                            ? constraints.maxHeight
                            : (constraints.maxHeight - widget.verticalInset)
                                .clamp(0.0, widget.height);
                    final navChildren = _navChildrenForMode(
                      widget.navChildren,
                      mobile: mobile,
                      dialogClasses: dialogClasses,
                    );
                    final useTrailingSpacer =
                        !mobile && !dialogClasses.usesFullWidthNavTitle;
                    final providerContainer = ProviderScope.containerOf(
                      context,
                    );
                    final windowDragCallbacks = providerContainer.read(
                      smPlayerWindowDragProvider,
                    );
                    final onWindowDragStart =
                        widget.onWindowDragStart ??
                        windowDragCallbacks?.onStart;
                    final onWindowDragEnd =
                        widget.onWindowDragEnd ?? windowDragCallbacks?.onEnd;
                    final windowControls =
                        Platform.isWindows
                            ? providerContainer.read(
                              smPlayerWindowControlsProvider,
                            )
                            : null;
                    final navBar = Semantics(
                      label: widget.navLabel,
                      child: GestureDetector(
                        key: const ValueKey('popup-dialog-nav'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart:
                            onWindowDragStart == null
                                ? null
                                : (_) => onWindowDragStart(),
                        onPanEnd:
                            onWindowDragEnd == null
                                ? null
                                : (_) => onWindowDragEnd(),
                        onPanCancel: onWindowDragEnd,
                        child: Padding(
                          padding:
                              mobile
                                  ? const EdgeInsets.fromLTRB(12, 44, 12, 10)
                                  : const EdgeInsets.fromLTRB(28, 22, 28, 18),
                          child: Row(
                            children: [
                              ...navChildren,
                              if (useTrailingSpacer) const Spacer(),
                              if (!mobile)
                                _PopupDialogCloseButton(
                                  label: i18n.t('common.close'),
                                  colors: colors,
                                  onClose: widget.onClose,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                    final dialog = GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: SizedBox(
                        key: const ValueKey('popup-dialog-shell'),
                        width: dialogWidth,
                        height: dialogHeight,
                        child: Container(
                          key: const ValueKey('popup-dialog-surface'),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(
                              mobile ? 0 : widget.borderRadius,
                            ),
                            border:
                                mobile
                                    ? null
                                    : Border.all(color: colors.border),
                            boxShadow:
                                mobile
                                    ? null
                                    : [
                                      BoxShadow(
                                        color: colors.shadow,
                                        blurRadius: 80,
                                        offset: const Offset(0, 26),
                                      ),
                                    ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              mobile
                                  ? Column(
                                    children: [
                                      navBar,
                                      if (widget.afterNav != null)
                                        widget.afterNav!,
                                      Expanded(child: widget.child),
                                      if (widget.footer != null) widget.footer!,
                                    ],
                                  )
                                  : Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Column(
                                        children: [
                                          const SizedBox(height: 80),
                                          if (widget.afterNav != null)
                                            widget.afterNav!,
                                          Expanded(child: widget.child),
                                          if (widget.footer != null)
                                            widget.footer!,
                                        ],
                                      ),
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: navBar,
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                    );

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment:
                              mobile ? Alignment.topCenter : Alignment.center,
                          child: dialog,
                        ),
                        if (!mobile)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 138,
                            height: 32,
                            child: GestureDetector(
                              key: const ValueKey(
                                'popup-dialog-window-drag-strip',
                              ),
                              behavior: HitTestBehavior.opaque,
                              onPanStart:
                                  onWindowDragStart == null
                                      ? null
                                      : (_) => onWindowDragStart(),
                              onPanEnd:
                                  onWindowDragEnd == null
                                      ? null
                                      : (_) => onWindowDragEnd(),
                              onPanCancel: onWindowDragEnd,
                            ),
                          ),
                        if (mobile)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 138,
                            height: 32,
                            child: _PopupDialogMobileTitleBar(
                              title: i18n.t('app.shell'),
                              colors: colors,
                              onClose: widget.onClose,
                              onWindowDragStart: onWindowDragStart,
                              onWindowDragEnd: onWindowDragEnd,
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
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _navChildrenForMode(
    List<Widget> children, {
    required bool mobile,
    required _PopupDialogClassNames dialogClasses,
  }) {
    if (!mobile || !dialogClasses.usesMobileTabGrid) {
      return children;
    }
    return [
      for (final child in children)
        if (child is PopupDialogTab) Expanded(child: child) else child,
    ];
  }
}
