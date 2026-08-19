import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/uniform_multi_select_icon.dart';

const _textIconButtonGlassSettings = LiquidGlassSettings(
  blur: 30,
  thickness: 12,
  refractiveIndex: 1.03,
  saturation: 1.2,
  chromaticAberration: 0,
  lightIntensity: 0.04,
  ambientStrength: 0.04,
  glowIntensity: 0,
  glassColor: Color(0x08ffffff),
  standardOpacityMultiplier: 0.12,
);

const _textIconButtonNightGlassSettings = LiquidGlassSettings(
  blur: 24,
  thickness: 8,
  refractiveIndex: 1.02,
  saturation: 1.12,
  chromaticAberration: 0,
  lightIntensity: 0.025,
  ambientStrength: 0.03,
  glowIntensity: 0,
  glassColor: Color(0x05ffffff),
  standardOpacityMultiplier: 0.08,
);

class SmPlayerTextIconButton extends StatefulWidget {
  const SmPlayerTextIconButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.child,
    this.icon,
    this.iconWidget,
    this.trailingIcon,
    this.trailingIconWidget,
    this.loading = false,
    this.active = false,
    this.activeSurface = true,
    this.activeMatchesHover = false,
    this.activeHoverSurface,
    this.disabled = false,
    this.showLabel = true,
    this.tooltipEnabled = true,
    this.tooltip,
    this.minWidth = 0,
    this.maxWidth,
    this.height = 40,
    this.horizontalPadding = 14,
    this.verticalPadding = 0,
    this.iconSize = 18,
    this.iconGap = 8,
    this.opacityWhenDisabled = 0.52,
    this.borderRadius = 8,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.fontVariations = const [FontVariation.weight(650)],
    this.glassSettings,
    this.glassQuality = GlassQuality.minimal,
    this.glassUseOwnLayer = true,
    this.glassAllowElevation = false,
    this.glassClipBehavior = Clip.hardEdge,
    this.glassEnabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? child;
  final IconData? icon;
  final Widget? iconWidget;
  final IconData? trailingIcon;
  final Widget? trailingIconWidget;
  final bool loading;
  final bool active;
  final bool activeSurface;
  final bool activeMatchesHover;
  final Color? activeHoverSurface;
  final bool disabled;
  final bool showLabel;
  final bool tooltipEnabled;
  final String? tooltip;
  final double minWidth;
  final double? maxWidth;
  final double height;
  final double horizontalPadding;
  final double verticalPadding;
  final double iconSize;
  final double iconGap;
  final double opacityWhenDisabled;
  final double borderRadius;
  final double fontSize;
  final FontWeight fontWeight;
  final List<FontVariation> fontVariations;
  final LiquidGlassSettings? glassSettings;
  final GlassQuality glassQuality;
  final bool glassUseOwnLayer;
  final bool glassAllowElevation;
  final Clip glassClipBehavior;
  final bool glassEnabled;

  @override
  State<SmPlayerTextIconButton> createState() => _SmPlayerTextIconButtonState();
}

class _SmPlayerTextIconButtonState extends State<SmPlayerTextIconButton> {
  @override
  Widget build(BuildContext context) {
    if (!widget.tooltipEnabled) {
      return _SmPlayerTextIconButtonInteraction(configuration: widget);
    }
    final tooltip = widget.tooltip ?? (widget.showLabel ? null : widget.label);
    if (tooltip == null) {
      return _SmPlayerTextIconButtonInteraction(configuration: widget);
    }
    return _SmPlayerTextIconButtonInteraction(
      configuration: widget,
      tooltip: tooltip,
    );
  }
}

class _SmPlayerTextIconButtonInteraction extends StatefulWidget {
  const _SmPlayerTextIconButtonInteraction({
    required this.configuration,
    this.tooltip,
  });

  final SmPlayerTextIconButton configuration;
  final String? tooltip;

  @override
  State<_SmPlayerTextIconButtonInteraction> createState() =>
      _SmPlayerTextIconButtonInteractionState();
}

class _SmPlayerTextIconButtonInteractionState
    extends State<_SmPlayerTextIconButtonInteraction> {
  final _tooltipAnchorKey = GlobalKey();
  var _hovered = false;
  var _focused = false;
  OverlayEntry? _tooltipOverlayEntry;

  @override
  void dispose() {
    _removeTooltipOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SmPlayerTextIconButtonInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tooltip == widget.tooltip) {
      return;
    }
    _removeTooltipOverlay();
    if (widget.tooltip != null && (_hovered || _focused)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTooltipOverlay();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.configuration;
    final colors =
        SmPlayerTextIconButtonTheme.maybeOf(context) ??
        Theme.of(context).extension<SmPlayerTextIconButtonColors>() ??
        SmPlayerTextIconButtonColors.day;
    final brightness = Theme.of(context).brightness;
    final enabled =
        config.onPressed != null && !config.disabled && !config.loading;
    final hovered = enabled && (_hovered || _focused);
    final activeMatchesHover = config.active && config.activeMatchesHover;
    final usesHoverStyle = hovered || activeMatchesHover;
    final foreground =
        activeMatchesHover || hovered
            ? colors.commandTextHover
            : config.active
            ? colors.accentStrong
            : colors.commandText;
    final surfaceColor =
        activeMatchesHover
            ? colors.controlHover
            : config.active && config.activeSurface && !hovered
            ? colors.controlActive
            : config.active && config.activeSurface && hovered
            ? config.activeHoverSurface ??
                Color.alphaBlend(colors.controlHover, colors.controlActive)
            : hovered
            ? colors.controlHover
            : colors.control;
    final borderColor =
        usesHoverStyle ? colors.controlHoverBorder : colors.controlBorder;
    final usesGlass =
        config.glassEnabled &&
        (config.glassSettings != null ||
            colors.control.a > 0 ||
            colors.controlBorder.a > 0);
    final iconOnlyWidth =
        config.minWidth > config.height ? config.minWidth : config.height;
    final control = DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(config.borderRadius),
        border: Border.all(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: config.showLabel ? config.minWidth : iconOnlyWidth,
          minHeight: config.height,
          maxHeight: config.height,
          maxWidth:
              config.showLabel
                  ? config.maxWidth ?? double.infinity
                  : iconOnlyWidth,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: config.showLabel ? config.horizontalPadding : 0,
            vertical: config.verticalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (config.loading)
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else if (config.iconWidget case final iconWidget?)
                IconTheme(
                  data: IconThemeData(size: config.iconSize, color: foreground),
                  child: iconWidget,
                )
              else if (config.icon case final icon?)
                isMultiSelectIcon(icon)
                    ? UniformMultiSelectIcon(
                      size: config.iconSize,
                      color: foreground,
                    )
                    : icon == FluentIcons.play_20_regular
                    ? SmPlayerPlayIcon(size: config.iconSize, color: foreground)
                    : Icon(icon, size: config.iconSize, color: foreground),
              if (config.showLabel) ...[
                if (config.loading ||
                    config.icon != null ||
                    config.iconWidget != null)
                  SizedBox(width: config.iconGap),
                Flexible(
                  child: DefaultTextStyle.merge(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontSize: config.fontSize,
                      fontWeight: config.fontWeight,
                      fontVariations: config.fontVariations,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                    child: config.child ?? Text(config.label),
                  ),
                ),
                if (config.trailingIconWidget != null ||
                    config.trailingIcon != null) ...[
                  SizedBox(width: config.iconGap),
                  if (config.trailingIconWidget case final trailingIconWidget?)
                    IconTheme(
                      data: IconThemeData(
                        size: config.iconSize,
                        color: foreground,
                      ),
                      child: trailingIconWidget,
                    )
                  else if (config.trailingIcon case final trailingIcon?)
                    Icon(
                      trailingIcon,
                      size: config.iconSize,
                      color: foreground,
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
    final visualControl =
        usesGlass
            ? GlassContainer(
              useOwnLayer: config.glassUseOwnLayer,
              quality: config.glassQuality,
              shape: LiquidRoundedRectangle(borderRadius: config.borderRadius),
              settings:
                  config.glassSettings ??
                  (brightness == Brightness.dark
                      ? _textIconButtonNightGlassSettings
                      : _textIconButtonGlassSettings),
              clipBehavior: config.glassClipBehavior,
              allowElevation: config.glassAllowElevation,
              child: control,
            )
            : control;
    final button = Opacity(
      opacity: enabled ? 1 : config.opacityWhenDisabled,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (enabled) {
                config.onPressed?.call();
              }
              return null;
            },
          ),
        },
        onShowHoverHighlight: _setHovered,
        onShowFocusHighlight: _setFocused,
        child: MouseRegion(
          onEnter: (_) {
            _setHovered(true);
          },
          onExit: (_) {
            _setHovered(false);
          },
          child: Semantics(
            button: true,
            enabled: enabled,
            label: config.showLabel ? null : config.label,
            tooltip: widget.tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: enabled ? (_) => config.onPressed?.call() : null,
              child: visualControl,
            ),
          ),
        ),
      ),
    );
    return KeyedSubtree(key: _tooltipAnchorKey, child: button);
  }

  void _setHovered(bool hovered) {
    if (_hovered == hovered) {
      return;
    }
    setState(() {
      _hovered = hovered;
    });
    _updateTooltipOverlay();
  }

  void _setFocused(bool focused) {
    if (_focused == focused) {
      return;
    }
    setState(() {
      _focused = focused;
    });
    _updateTooltipOverlay();
  }

  void _updateTooltipOverlay() {
    if (widget.tooltip == null) {
      _removeTooltipOverlay();
      return;
    }
    if (_hovered || _focused) {
      _showTooltipOverlay();
    } else {
      _removeTooltipOverlay();
    }
  }

  void _showTooltipOverlay() {
    if (_tooltipOverlayEntry != null) {
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    final anchorBox =
        _tooltipAnchorKey.currentContext!.findRenderObject()! as RenderBox;
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final anchorOrigin = overlayBox.globalToLocal(
      anchorBox.localToGlobal(Offset.zero),
    );
    final message = widget.tooltip!;
    _tooltipOverlayEntry = OverlayEntry(
      builder:
          (overlayContext) => _SmPlayerTextIconButtonTooltipOverlay(
            message: message,
            anchor: anchorOrigin & anchorBox.size,
          ),
    );
    overlay.insert(_tooltipOverlayEntry!);
  }

  void _removeTooltipOverlay() {
    _tooltipOverlayEntry?.remove();
    _tooltipOverlayEntry = null;
  }
}

class _SmPlayerTextIconButtonTooltipOverlay extends StatelessWidget {
  const _SmPlayerTextIconButtonTooltipOverlay({
    required this.message,
    required this.anchor,
  });

  final String message;
  final Rect anchor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xf5222222) : const Color(0xfafdfdfd);
    final border = dark ? const Color(0x5cffffff) : const Color(0x3d1f2a36);
    final foreground = dark ? const Color(0xffffffff) : const Color(0xff1f252b);
    return Positioned(
      top: anchor.bottom + 8,
      left: anchor.center.dx - 120,
      width: 240,
      child: IgnorePointer(
        child: Center(
          child: DecoratedBox(
            key: const ValueKey('SmPlayerTextIconButton.Tooltip'),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SmPlayerTextIconButtonColors
    extends ThemeExtension<SmPlayerTextIconButtonColors> {
  const SmPlayerTextIconButtonColors({
    required this.commandText,
    required this.commandTextHover,
    required this.control,
    required this.controlHover,
    required this.controlHoverBorder,
    required this.controlActive,
    required this.controlBorder,
    required this.accentStrong,
  });

  final Color commandText;
  final Color commandTextHover;
  final Color control;
  final Color controlHover;
  final Color controlHoverBorder;
  final Color controlActive;
  final Color controlBorder;
  final Color accentStrong;

  static const day = SmPlayerTextIconButtonColors(
    commandText: Color(0xff1f252b),
    commandTextHover: Color(0xff0063b1),
    control: Color(0x94ffffff),
    controlHover: Color(0x1a0078d7),
    controlHoverBorder: Color(0x2e768499),
    controlActive: Color(0x1a0078d7),
    controlBorder: Color(0x2e768499),
    accentStrong: Color(0xff0063b1),
  );

  static const night = SmPlayerTextIconButtonColors(
    commandText: Color(0xf0f6f9fc),
    commandTextHover: Color(0xff459de2),
    control: Color(0x0effffff),
    controlHover: Color(0x290078d7),
    controlHoverBorder: Color(0x570078d7),
    controlActive: Color(0x290078d7),
    controlBorder: Color(0x1fd6e0ec),
    accentStrong: Color(0xff0063b1),
  );

  static SmPlayerTextIconButtonColors of(BuildContext context) {
    return Theme.of(context).extension<SmPlayerTextIconButtonColors>() ?? day;
  }

  @override
  SmPlayerTextIconButtonColors copyWith({
    Color? commandText,
    Color? commandTextHover,
    Color? control,
    Color? controlHover,
    Color? controlHoverBorder,
    Color? controlActive,
    Color? controlBorder,
    Color? accentStrong,
  }) {
    return SmPlayerTextIconButtonColors(
      commandText: commandText ?? this.commandText,
      commandTextHover: commandTextHover ?? this.commandTextHover,
      control: control ?? this.control,
      controlHover: controlHover ?? this.controlHover,
      controlHoverBorder: controlHoverBorder ?? this.controlHoverBorder,
      controlActive: controlActive ?? this.controlActive,
      controlBorder: controlBorder ?? this.controlBorder,
      accentStrong: accentStrong ?? this.accentStrong,
    );
  }

  @override
  SmPlayerTextIconButtonColors lerp(
    ThemeExtension<SmPlayerTextIconButtonColors>? other,
    double t,
  ) {
    if (other is! SmPlayerTextIconButtonColors) {
      return this;
    }
    return SmPlayerTextIconButtonColors(
      commandText: Color.lerp(commandText, other.commandText, t)!,
      commandTextHover:
          Color.lerp(commandTextHover, other.commandTextHover, t)!,
      control: Color.lerp(control, other.control, t)!,
      controlHover: Color.lerp(controlHover, other.controlHover, t)!,
      controlHoverBorder:
          Color.lerp(controlHoverBorder, other.controlHoverBorder, t)!,
      controlActive: Color.lerp(controlActive, other.controlActive, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
    );
  }
}

class SmPlayerTextIconButtonTheme extends InheritedWidget {
  const SmPlayerTextIconButtonTheme({
    super.key,
    required this.colors,
    required super.child,
  });

  final SmPlayerTextIconButtonColors colors;

  static SmPlayerTextIconButtonColors? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SmPlayerTextIconButtonTheme>()
        ?.colors;
  }

  @override
  bool updateShouldNotify(SmPlayerTextIconButtonTheme oldWidget) {
    return colors != oldWidget.colors;
  }
}
