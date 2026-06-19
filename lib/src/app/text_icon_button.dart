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

enum SmPlayerTextIconButtonTooltipMode { overlay, local }

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
    this.disabled = false,
    this.showLabel = true,
    this.tooltipEnabled = true,
    this.tooltipMode = SmPlayerTextIconButtonTooltipMode.overlay,
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
  final bool disabled;
  final bool showLabel;
  final bool tooltipEnabled;
  final SmPlayerTextIconButtonTooltipMode tooltipMode;
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
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors =
        SmPlayerTextIconButtonTheme.maybeOf(context) ??
        Theme.of(context).extension<SmPlayerTextIconButtonColors>() ??
        SmPlayerTextIconButtonColors.day;
    final brightness = Theme.of(context).brightness;
    final enabled =
        widget.onPressed != null && !widget.disabled && !widget.loading;
    final hovered = enabled && (_hovered || _focused);
    final foreground =
        widget.active
            ? colors.accentStrong
            : hovered
            ? colors.commandTextHover
            : colors.commandText;
    final surfaceColor =
        widget.active && widget.activeSurface
            ? colors.controlActive
            : hovered
            ? colors.controlHover
            : colors.control;
    final borderColor =
        hovered ? colors.controlHoverBorder : colors.controlBorder;
    final usesGlass =
        widget.glassEnabled &&
        (widget.glassSettings != null ||
            colors.control.a > 0 ||
            colors.controlBorder.a > 0);
    final iconOnlyWidth =
        widget.minWidth > widget.height ? widget.minWidth : widget.height;
    final control = DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.showLabel ? widget.minWidth : iconOnlyWidth,
          minHeight: widget.height,
          maxHeight: widget.height,
          maxWidth:
              widget.showLabel
                  ? widget.maxWidth ?? double.infinity
                  : iconOnlyWidth,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.showLabel ? widget.horizontalPadding : 0,
            vertical: widget.verticalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else if (widget.iconWidget case final iconWidget?)
                IconTheme(
                  data: IconThemeData(size: widget.iconSize, color: foreground),
                  child: iconWidget,
                )
              else if (widget.icon case final icon?)
                isMultiSelectIcon(icon)
                    ? UniformMultiSelectIcon(
                      size: widget.iconSize,
                      color: foreground,
                    )
                    : icon == FluentIcons.play_20_regular
                    ? SmPlayerPlayIcon(size: widget.iconSize, color: foreground)
                    : Icon(icon, size: widget.iconSize, color: foreground),
              if (widget.showLabel) ...[
                if (widget.loading ||
                    widget.icon != null ||
                    widget.iconWidget != null)
                  SizedBox(width: widget.iconGap),
                Flexible(
                  child: DefaultTextStyle.merge(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontSize: widget.fontSize,
                      fontWeight: widget.fontWeight,
                      fontVariations: widget.fontVariations,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                    child: widget.child ?? Text(widget.label),
                  ),
                ),
                if (widget.trailingIconWidget != null ||
                    widget.trailingIcon != null) ...[
                  SizedBox(width: widget.iconGap),
                  if (widget.trailingIconWidget case final trailingIconWidget?)
                    IconTheme(
                      data: IconThemeData(
                        size: widget.iconSize,
                        color: foreground,
                      ),
                      child: trailingIconWidget,
                    )
                  else if (widget.trailingIcon case final trailingIcon?)
                    Icon(
                      trailingIcon,
                      size: widget.iconSize,
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
              useOwnLayer: widget.glassUseOwnLayer,
              quality: widget.glassQuality,
              shape: LiquidRoundedRectangle(borderRadius: widget.borderRadius),
              settings:
                  widget.glassSettings ??
                  (brightness == Brightness.dark
                      ? _textIconButtonNightGlassSettings
                      : _textIconButtonGlassSettings),
              clipBehavior: widget.glassClipBehavior,
              allowElevation: widget.glassAllowElevation,
              child: control,
            )
            : control;
    final button = Opacity(
      opacity: enabled ? 1 : widget.opacityWhenDisabled,
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
                widget.onPressed?.call();
              }
              return null;
            },
          ),
        },
        onShowHoverHighlight: (value) {
          if (_hovered != value) {
            setState(() {
              _hovered = value;
            });
          }
        },
        onShowFocusHighlight: (value) {
          if (_focused != value) {
            setState(() {
              _focused = value;
            });
          }
        },
        child: MouseRegion(
          onEnter: (_) {
            if (!_hovered) {
              setState(() {
                _hovered = true;
              });
            }
          },
          onExit: (_) {
            if (_hovered) {
              setState(() {
                _hovered = false;
              });
            }
          },
          child: Semantics(
            button: true,
            enabled: enabled,
            label: widget.showLabel ? null : widget.label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: enabled ? (_) => widget.onPressed?.call() : null,
              child: visualControl,
            ),
          ),
        ),
      ),
    );
    if (!widget.tooltipEnabled) {
      return button;
    }
    final tooltip = widget.tooltip ?? (widget.showLabel ? null : widget.label);
    if (tooltip == null) {
      return button;
    }
    if (widget.tooltipMode == SmPlayerTextIconButtonTooltipMode.local) {
      return _SmPlayerTextIconButtonLocalTooltip(
        message: tooltip,
        visible: hovered,
        buttonHeight: widget.height,
        child: button,
      );
    }
    return Tooltip(message: tooltip, child: button);
  }
}

class _SmPlayerTextIconButtonLocalTooltip extends StatelessWidget {
  const _SmPlayerTextIconButtonLocalTooltip({
    required this.message,
    required this.visible,
    required this.buttonHeight,
    required this.child,
  });

  final String message;
  final bool visible;
  final double buttonHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xf5222222) : const Color(0xfafdfdfd);
    final border = dark ? const Color(0x5cffffff) : const Color(0x3d1f2a36);
    final foreground = dark ? const Color(0xffffffff) : const Color(0xff1f252b);
    return Semantics(
      tooltip: message,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (visible)
            Positioned(
              top: buttonHeight + 8,
              left: -120,
              right: -120,
              child: IgnorePointer(
                child: Center(
                  child: DecoratedBox(
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
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
            ),
        ],
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
