import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/svg_icon.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

const popupDialogMobileBreakpoint = 720.0;
const popupConfirmDialogDismissDelay = Duration(milliseconds: 170);

typedef PopupDialogCloseHandler = VoidCallback;

final List<PopupDialogCloseHandler> _popupDialogCloseHandlers = [];

bool closeTopPopupDialog() {
  final closeHandler = _popupDialogCloseHandlers.lastOrNull;
  if (closeHandler == null) {
    return false;
  }
  closeHandler();
  return true;
}

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
    this.width = 780,
    this.height = 760,
    this.horizontalInset = 48,
    this.verticalInset = 48,
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
  final double width;
  final double height;
  final double horizontalInset;
  final double verticalInset;
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
          child: _PopupDialogLiquidGlassBackdrop(
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
                              mobile ? 0 : 12,
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
                          child: Column(
                            children: [
                              Semantics(
                                label: widget.navLabel,
                                child: GestureDetector(
                                  key: const ValueKey('popup-dialog-nav'),
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart:
                                      widget.onWindowDragStart == null
                                          ? null
                                          : (_) => widget.onWindowDragStart!(),
                                  onPanEnd:
                                      widget.onWindowDragEnd == null
                                          ? null
                                          : (_) => widget.onWindowDragEnd!(),
                                  onPanCancel: widget.onWindowDragEnd,
                                  child: Padding(
                                    padding:
                                        mobile
                                            ? const EdgeInsets.fromLTRB(
                                              12,
                                              44,
                                              12,
                                              10,
                                            )
                                            : const EdgeInsets.fromLTRB(
                                              28,
                                              22,
                                              28,
                                              18,
                                            ),
                                    child: Row(
                                      children: [
                                        ...navChildren,
                                        if (useTrailingSpacer) const Spacer(),
                                        if (!mobile)
                                          Tooltip(
                                            message: i18n.t('common.close'),
                                            child: _PopupDialogCloseButton(
                                              colors: colors,
                                              onClose: widget.onClose,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.afterNav != null) widget.afterNav!,
                              Expanded(child: widget.child),
                              if (widget.footer != null) widget.footer!,
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
                                  widget.onWindowDragStart == null
                                      ? null
                                      : (_) => widget.onWindowDragStart!(),
                              onPanEnd:
                                  widget.onWindowDragEnd == null
                                      ? null
                                      : (_) => widget.onWindowDragEnd!(),
                              onPanCancel: widget.onWindowDragEnd,
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
                              onWindowDragStart: widget.onWindowDragStart,
                              onWindowDragEnd: widget.onWindowDragEnd,
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

class _PopupDialogLiquidGlassBackdrop extends StatelessWidget {
  const _PopupDialogLiquidGlassBackdrop({
    required this.colors,
    required this.child,
  });

  final PopupDialogResolvedColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const ValueKey('popup-dialog-overlay'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GlassContainer(
            key: const ValueKey('popup-dialog-overlay-glass'),
            useOwnLayer: true,
            quality: GlassQuality.minimal,
            clipBehavior: Clip.hardEdge,
            allowElevation: false,
            shape: const LiquidRoundedRectangle(borderRadius: 0),
            settings: LiquidGlassSettings(
              blur: 46,
              thickness: 20,
              refractiveIndex: 1.06,
              saturation: 1.65,
              chromaticAberration: 0,
              lightIntensity: 0.1,
              ambientStrength: 0.08,
              glowIntensity: 0.04,
              glassColor: colors.overlay,
              standardOpacityMultiplier: 0.24,
            ),
            child: const SizedBox.expand(),
          ),
          DecoratedBox(decoration: BoxDecoration(color: colors.overlay)),
          child,
        ],
      ),
    );
  }
}

class _PopupDialogClassNames {
  const _PopupDialogClassNames({
    required this.className,
    required this.navClassName,
  });

  final String className;
  final String navClassName;

  bool get usesMobileTabGrid {
    if (_contains(className, 'release-notes-dialog') ||
        _contains(className, 'artist-split-review-dialog') ||
        _contains(className, 'album-art-library-picker-dialog') ||
        _contains(className, 'remote-share-dialog') ||
        _contains(className, 'voice-assistant-help-dialog') ||
        _contains(className, 'preference-modal')) {
      return false;
    }
    return _contains(navClassName, 'music-dialog-pivot') ||
        _contains(className, 'music-dialog') ||
        _contains(className, 'album-artwork-dialog');
  }

  bool get usesFullWidthNavTitle {
    return _contains(className, 'album-art-library-picker-dialog');
  }

  bool _contains(String source, String token) {
    return source.split(' ').contains(token);
  }
}

class _PopupDialogCloseButton extends StatefulWidget {
  const _PopupDialogCloseButton({required this.colors, required this.onClose});

  final PopupDialogResolvedColors colors;
  final VoidCallback onClose;

  @override
  State<_PopupDialogCloseButton> createState() =>
      _PopupDialogCloseButtonState();
}

class _PopupDialogCloseButtonState extends State<_PopupDialogCloseButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final hoverSurface =
        nightMode
            ? GlobalUI.buttonHoverBgColorNight
            : GlobalUI.buttonHoverBgColorDay;
    final background = _hovered ? hoverSurface : colors.buttonSurface;
    final foreground = colors.buttonText;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        key: const ValueKey('popup-dialog-close-button'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: Semantics(
          button: true,
          child: DecoratedBox(
            key: const ValueKey('popup-dialog-close-button-surface'),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.buttonBorder),
              boxShadow: colors.buttonShadow,
            ),
            child: SizedBox(
              width: 42,
              height: 40,
              child: SvgIcon(
                key: const ValueKey('popup-dialog-close-icon'),
                svg: _popupDialogCloseIconSvg,
                size: 18,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _popupDialogCloseIconSvg =
    '<svg viewBox="0 0 20 20" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="m4.09 4.22.06-.07a.5.5 0 0 1 .63-.06l.07.06L10 9.29l5.15-5.14a.5.5 0 0 1 .63-.06l.07.06c.18.17.2.44.06.63l-.06.07L10.71 10l5.14 5.15c.18.17.2.44.06.63l-.06.07a.5.5 0 0 1-.63.06l-.07-.06L10 10.71l-5.15 5.14a.5.5 0 0 1-.63.06l-.07-.06a.5.5 0 0 1-.06-.63l.06-.07L9.29 10 4.15 4.85a.5.5 0 0 1-.06-.63l.06-.07-.06.07Z"/></svg>';

const _popupDialogArrowLeftIconSvg =
    '<svg viewBox="0 0 20 20" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M9.16 16.87a.5.5 0 1 0 .67-.74L3.67 10.5H17.5a.5.5 0 0 0 0-1H3.67l6.16-5.63a.5.5 0 0 0-.67-.74L2.24 9.44a.75.75 0 0 0 0 1.11l6.92 6.32Z"/></svg>';

class _PopupDialogMobileTitleBar extends StatelessWidget {
  const _PopupDialogMobileTitleBar({
    required this.title,
    required this.colors,
    required this.onClose,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
  });

  final String title;
  final PopupDialogResolvedColors colors;
  final VoidCallback onClose;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('popup-dialog-mobile-titlebar'),
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          _PopupDialogMobileBackButton(colors: colors, onClose: onClose),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart:
                  onWindowDragStart == null
                      ? null
                      : (_) => onWindowDragStart!(),
              onPanEnd:
                  onWindowDragEnd == null ? null : (_) => onWindowDragEnd!(),
              onPanCancel: onWindowDragEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopupDialogMobileBackButton extends StatefulWidget {
  const _PopupDialogMobileBackButton({
    required this.colors,
    required this.onClose,
  });

  final PopupDialogResolvedColors colors;
  final VoidCallback onClose;

  @override
  State<_PopupDialogMobileBackButton> createState() =>
      _PopupDialogMobileBackButtonState();
}

class _PopupDialogMobileBackButtonState
    extends State<_PopupDialogMobileBackButton> {
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final background =
        _pressed
            ? colors.mobileBackActiveSurface
            : _hovered
            ? colors.mobileBackHoverSurface
            : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: GestureDetector(
        key: const ValueKey('popup-dialog-mobile-back-button'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            _pressed = false;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        child: DecoratedBox(
          key: const ValueKey('popup-dialog-mobile-back-button-surface'),
          decoration: BoxDecoration(color: background),
          child: SizedBox(
            width: 40,
            height: 32,
            child: Center(
              child: SvgIcon(
                key: const ValueKey('popup-dialog-mobile-back-icon'),
                svg: _popupDialogArrowLeftIconSvg,
                size: 18,
                color: colors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PopupDialogTab extends StatelessWidget {
  const PopupDialogTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.first = false,
    this.last = false,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onPressed;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final button = TextButton(
      style: TextButton.styleFrom(
        fixedSize: mobile ? null : const Size(138, 40),
        minimumSize: mobile ? const Size(0, 40) : const Size(138, 40),
        maximumSize:
            mobile ? const Size(double.infinity, 40) : const Size(138, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: selected ? colors.activeButtonText : colors.text,
        backgroundColor:
            selected ? colors.activeButtonSurface : colors.buttonSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            left: first ? const Radius.circular(8) : Radius.zero,
            right: last ? const Radius.circular(8) : Radius.zero,
          ),
          side: BorderSide(
            color: selected ? colors.activeButtonBorder : colors.buttonBorder,
          ),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget ?? Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontVariations: [FontVariation.weight(650)],
              ),
            ),
          ),
        ],
      ),
    );
    if (!mobile) {
      if (first) {
        return SizedBox(width: 138, height: 40, child: button);
      }
      return SizedBox(
        width: 137,
        height: 40,
        child: OverflowBox(
          minWidth: 138,
          maxWidth: 138,
          minHeight: 40,
          maxHeight: 40,
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: const Offset(-1, 0),
            child: button,
          ),
        ),
      );
    }
    return SizedBox(width: double.infinity, height: 40, child: button);
  }
}

Future<String?> showPopupTextDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required String confirmLabel,
  SmPlayerI18n? i18n,
  String? placeholder,
  String Function(String value)? validate,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    builder: (dialogContext) {
      final dialogI18n =
          dialogContext.maybeSmPlayerI18n ??
          i18n ??
          const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
      return _PopupTextDialog(
        i18n: dialogI18n,
        title: title,
        initialValue: initialValue,
        confirmLabel: confirmLabel,
        placeholder: placeholder,
        validate: validate,
      );
    },
  );
}

class _PopupTextDialog extends StatefulWidget {
  const _PopupTextDialog({
    required this.i18n,
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
    this.placeholder,
    this.validate,
  });

  final SmPlayerI18n i18n;
  final String title;
  final String initialValue;
  final String confirmLabel;
  final String? placeholder;
  final String Function(String value)? validate;

  @override
  State<_PopupTextDialog> createState() => _PopupTextDialogState();
}

class _PopupTextDialogState extends State<_PopupTextDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _errorText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InputDialogShell(
      ariaLabel: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InputDialogTitle(widget.title),
          const SizedBox(height: 18),
          PopupDialogTextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            placeholder: widget.placeholder,
            errorText: _errorText,
            onChanged: (_) {
              if (_errorText.isNotEmpty) {
                setState(() {
                  _errorText = '';
                });
              }
            },
            onSubmitted: (_) {
              _submit();
            },
          ),
          PopupDialogActions(
            compact: true,
            children: [
              PopupDialogActionButton(
                label: widget.confirmLabel,
                primary: true,
                onPressed: _submit,
              ),
              PopupDialogActionButton(
                label: widget.i18n.t('common.cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    final validation = widget.validate?.call(value) ?? '';
    if (validation.isNotEmpty) {
      setState(() {
        _errorText = validation;
      });
      return;
    }
    Navigator.of(context).pop(value);
  }
}

Future<bool> showPopupConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  SmPlayerI18n? i18n,
  bool destructive = true,
  Future<void> Function()? onConfirm,
}) async {
  final confirmed =
      await showDialog<bool>(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        builder: (dialogContext) {
          final dialogI18n =
              dialogContext.maybeSmPlayerI18n ??
              i18n ??
              const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
          var submitting = false;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> submit() async {
                if (submitting) {
                  return;
                }
                final callback = onConfirm;
                if (callback == null) {
                  Navigator.of(dialogContext).pop(true);
                  return;
                }
                setDialogState(() {
                  submitting = true;
                });
                await SchedulerBinding.instance.endOfFrame;
                await callback();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              }

              return _InputDialogShell(
                ariaLabel: title,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InputDialogTitle(title),
                    const SizedBox(height: 18),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PopupDialogColors.resolve(context).text,
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                    PopupDialogActions(
                      compact: true,
                      children: [
                        PopupDialogActionButton(
                          label: confirmLabel,
                          primary: true,
                          destructive: destructive,
                          loading: submitting,
                          onPressed:
                              submitting ? null : () => unawaited(submit()),
                        ),
                        PopupDialogActionButton(
                          label: dialogI18n.t('common.cancel'),
                          onPressed:
                              submitting
                                  ? null
                                  : () {
                                    Navigator.of(dialogContext).pop(false);
                                  },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ) ??
      false;
  if (confirmed) {
    await Future<void>.delayed(popupConfirmDialogDismissDelay);
  }
  return confirmed;
}

class _InputDialogShell extends StatelessWidget {
  const _InputDialogShell({required this.ariaLabel, required this.child});

  final String ariaLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        dark ? PopupDialogColors.nightBorder : const Color(0x2e768499);
    final shadow =
        dark
            ? const BoxShadow(
              color: Color(0x6b000000),
              blurRadius: 60,
              offset: Offset(0, 24),
            )
            : const BoxShadow(
              color: Color(0x2435495f),
              blurRadius: 70,
              offset: Offset(0, 26),
            );
    return Material(
      color: Colors.transparent,
      child: Semantics(
        label: ariaLabel,
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        child: _InputDialogBackdrop(
          colors: colors,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: DecoratedBox(
                      key: const ValueKey('popup-input-dialog-surface'),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                        boxShadow: [shadow],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputDialogBackdrop extends StatelessWidget {
  const _InputDialogBackdrop({required this.colors, required this.child});

  final PopupDialogResolvedColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const ValueKey('popup-dialog-overlay'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.overlay),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class PopupDialogTitle extends StatelessWidget {
  const PopupDialogTitle(this.text, {super.key, this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: mobile ? 18 : 22,
        fontWeight: FontWeight.w500,
        height: 1.25,
      ),
    );
  }
}

class _InputDialogTitle extends StatelessWidget {
  const _InputDialogTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
    );
  }
}

class PopupDialogTextField extends StatelessWidget {
  const PopupDialogTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.placeholder,
    this.errorText = '',
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final String? placeholder;
  final String errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      style: TextStyle(color: colors.textStrong, fontSize: 15, height: 1.2),
      decoration: InputDecoration(
        hintText: placeholder,
        errorText: errorText.isEmpty ? null : errorText,
        filled: true,
        fillColor: enabled ? colors.fieldSurface : colors.fieldDisabledSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(minHeight: 42),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.focusRing, width: 3),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class PopupDialogActions extends StatelessWidget {
  const PopupDialogActions({
    super.key,
    required this.children,
    this.compact = false,
  });

  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          compact
              ? const EdgeInsets.only(top: 20)
              : const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 10,
        children: children,
      ),
    );
  }
}

class PopupDialogActionButton extends StatelessWidget {
  const PopupDialogActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final primaryDestructive = primary && destructive;
    final background =
        primary
            ? primaryDestructive
                ? colors.destructive
                : colors.accent
            : Colors.transparent;
    final foreground = primary ? Colors.white : colors.accentStrong;
    final resolvedForeground =
        onPressed == null
            ? primary
                ? foreground.withValues(alpha: 0.72)
                : colors.textMuted.withValues(alpha: 0.54)
            : foreground;
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return TextButton(
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: const Size(88, 36),
        maximumSize: const Size(double.infinity, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: foreground,
        disabledForegroundColor: foreground.withValues(alpha: 0.72),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ).copyWith(fontFamily: fontFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return primary
                ? background.withValues(alpha: 0.72)
                : Colors.transparent;
          }
          if (primaryDestructive &&
              (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed))) {
            return PopupDialogColors.destructiveHover;
          }
          return background;
        }),
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (primaryDestructive) {
            return Colors.transparent;
          }
          if (primary) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return colors.accent.withValues(alpha: 0.10);
        }),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.42),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: resolvedForeground,
              fontFamily: fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class PopupDialogColors {
  const PopupDialogColors._();

  static const overlay = Color(0x3d181e26);
  static const surface = Color(0xfafbfcff);
  static const border = Color(0x80b9c3d2);
  static const inputBorder = Color(0x94c0cad8);
  static const shadow = Color(0x47232d3c);
  static const buttonSurface = Color(0xebffffff);
  static const activeButtonSurface = Color(0xf5eff6ff);
  static const buttonBorder = Color(0x9ebec8d6);
  static const activeButtonBorder = Color(0x610078d7);
  static const accent = Color(0xff0078d7);
  static const accentSoft = Color(0x290078d7);
  static const text = Color(0xff5f625f);
  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const fieldSurface = Color(0xe6ffffff);
  static const fieldDisabledSurface = Color(0xade6ebf3);
  static const focusRing = Color(0x290078d7);
  static const destructive = Color(0xffd13438);
  static const destructiveHover = Color(0xffa4262c);
  static const nightOverlay = Color(0x9e04080d);
  static const nightSurface = Color(0xfa161c24);
  static const nightBorder = Color(0x1fd6e0ec);
  static const nightInputBorder = Color(0x1fd6e0ec);
  static const nightShadow = Color(0x7a000000);
  static const nightButtonSurface = Color(0x11ffffff);
  static const nightActiveButtonSurface = Color(0x2e0078d7);
  static const nightButtonBorder = Color(0x1fd6e0ec);
  static const nightActiveButtonBorder = Color(0x610078d7);
  static const nightActiveText = Color(0xff459de2);
  static const nightText = Color(0xebffffff);
  static const nightTextStrong = Color(0xfff8fafc);
  static const nightTextMuted = Color(0xadcbd5e1);
  static const nightFieldSurface = Color(0x11ffffff);
  static const nightFieldDisabledSurface = Color(0x0affffff);

  static PopupDialogResolvedColors resolve(BuildContext context) {
    return Theme.of(context).extension<PopupDialogResolvedColors>() ??
        PopupDialogResolvedColors.light;
  }
}

class PopupDialogResolvedColors
    extends ThemeExtension<PopupDialogResolvedColors> {
  const PopupDialogResolvedColors({
    required this.overlay,
    required this.surface,
    required this.border,
    required this.inputBorder,
    required this.shadow,
    required this.buttonSurface,
    required this.activeButtonSurface,
    required this.buttonHoverSurface,
    required this.mobileBackHoverSurface,
    required this.mobileBackActiveSurface,
    required this.buttonText,
    required this.buttonHoverText,
    required this.activeButtonText,
    required this.buttonBorder,
    required this.activeButtonBorder,
    required this.buttonShadow,
    required this.accent,
    required this.accentStrong,
    required this.text,
    required this.textStrong,
    required this.textMuted,
    required this.fieldDisabledText,
    required this.fieldSurface,
    required this.fieldDisabledSurface,
    required this.focusRing,
    required this.destructive,
  });

  final Color overlay;
  final Color surface;
  final Color border;
  final Color inputBorder;
  final Color shadow;
  final Color buttonSurface;
  final Color activeButtonSurface;
  final Color buttonHoverSurface;
  final Color mobileBackHoverSurface;
  final Color mobileBackActiveSurface;
  final Color buttonText;
  final Color buttonHoverText;
  final Color activeButtonText;
  final Color buttonBorder;
  final Color activeButtonBorder;
  final List<BoxShadow> buttonShadow;
  final Color accent;
  final Color accentStrong;
  final Color text;
  final Color textStrong;
  final Color textMuted;
  final Color fieldDisabledText;
  final Color fieldSurface;
  final Color fieldDisabledSurface;
  final Color focusRing;
  final Color destructive;

  static const light = PopupDialogResolvedColors(
    overlay: PopupDialogColors.overlay,
    surface: PopupDialogColors.surface,
    border: PopupDialogColors.border,
    inputBorder: PopupDialogColors.inputBorder,
    shadow: PopupDialogColors.shadow,
    buttonSurface: PopupDialogColors.buttonSurface,
    activeButtonSurface: PopupDialogColors.activeButtonSurface,
    buttonHoverSurface: Color(0xfaf7fafe),
    mobileBackHoverSurface: Color(0x12111827),
    mobileBackActiveSurface: Color(0x1f0078d7),
    buttonText: PopupDialogColors.text,
    buttonHoverText: PopupDialogColors.text,
    activeButtonText: PopupDialogColors.accent,
    buttonBorder: PopupDialogColors.buttonBorder,
    activeButtonBorder: PopupDialogColors.activeButtonBorder,
    buttonShadow: [
      BoxShadow(color: Color(0x0f28374c), offset: Offset(0, 8), blurRadius: 18),
    ],
    accent: PopupDialogColors.accent,
    accentStrong: PopupDialogColors.accent,
    text: PopupDialogColors.text,
    textStrong: PopupDialogColors.textStrong,
    textMuted: PopupDialogColors.textMuted,
    fieldDisabledText: Color(0xd1535d6c),
    fieldSurface: PopupDialogColors.fieldSurface,
    fieldDisabledSurface: PopupDialogColors.fieldDisabledSurface,
    focusRing: PopupDialogColors.focusRing,
    destructive: PopupDialogColors.destructive,
  );

  static const dark = PopupDialogResolvedColors(
    overlay: PopupDialogColors.nightOverlay,
    surface: PopupDialogColors.nightSurface,
    border: PopupDialogColors.nightBorder,
    inputBorder: PopupDialogColors.nightInputBorder,
    shadow: PopupDialogColors.nightShadow,
    buttonSurface: PopupDialogColors.nightButtonSurface,
    activeButtonSurface: PopupDialogColors.nightActiveButtonSurface,
    buttonHoverSurface: Color(0x290078d7),
    mobileBackHoverSurface: Color(0x14ffffff),
    mobileBackActiveSurface: Color(0x1f0078d7),
    buttonText: PopupDialogColors.nightText,
    buttonHoverText: PopupDialogColors.nightActiveText,
    activeButtonText: PopupDialogColors.nightActiveText,
    buttonBorder: PopupDialogColors.nightButtonBorder,
    activeButtonBorder: PopupDialogColors.nightActiveButtonBorder,
    buttonShadow: [],
    accent: PopupDialogColors.accent,
    accentStrong: Color(0xff66b7ff),
    text: PopupDialogColors.nightText,
    textStrong: PopupDialogColors.nightTextStrong,
    textMuted: PopupDialogColors.nightTextMuted,
    fieldDisabledText: PopupDialogColors.nightTextMuted,
    fieldSurface: PopupDialogColors.nightFieldSurface,
    fieldDisabledSurface: PopupDialogColors.nightFieldDisabledSurface,
    focusRing: Color(0x330078d7),
    destructive: PopupDialogColors.destructive,
  );

  @override
  PopupDialogResolvedColors copyWith() {
    return this;
  }

  @override
  PopupDialogResolvedColors lerp(
    ThemeExtension<PopupDialogResolvedColors>? other,
    double t,
  ) {
    return t < 0.5 || other is! PopupDialogResolvedColors ? this : other;
  }
}
