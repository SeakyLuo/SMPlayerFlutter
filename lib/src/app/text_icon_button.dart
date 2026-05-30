import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/uniform_multi_select_icon.dart';

class SmPlayerTextIconButton extends StatefulWidget {
  const SmPlayerTextIconButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.child,
    this.icon,
    this.iconWidget,
    this.loading = false,
    this.active = false,
    this.disabled = false,
    this.showLabel = true,
    this.tooltip,
    this.minWidth = 0,
    this.maxWidth,
    this.height = 40,
    this.horizontalPadding = 14,
    this.iconSize = 18,
    this.iconGap = 8,
    this.opacityWhenDisabled = 0.52,
    this.borderRadius = 8,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.fontVariations = const [FontVariation.weight(650)],
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? child;
  final IconData? icon;
  final Widget? iconWidget;
  final bool loading;
  final bool active;
  final bool disabled;
  final bool showLabel;
  final String? tooltip;
  final double minWidth;
  final double? maxWidth;
  final double height;
  final double horizontalPadding;
  final double iconSize;
  final double iconGap;
  final double opacityWhenDisabled;
  final double borderRadius;
  final double fontSize;
  final FontWeight fontWeight;
  final List<FontVariation> fontVariations;

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
    final enabled =
        widget.onPressed != null && !widget.disabled && !widget.loading;
    final hovered = enabled && (_hovered || _focused);
    final foreground = widget.active ? colors.accentStrong : colors.commandText;
    final iconOnlyWidth =
        widget.minWidth > widget.height ? widget.minWidth : widget.height;
    final control = DecoratedBox(
      decoration: BoxDecoration(
        color:
            widget.active
                ? colors.controlActive
                : hovered
                ? colors.controlHover
                : colors.control,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: colors.controlBorder),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.showLabel ? widget.minWidth : iconOnlyWidth,
          minHeight: widget.height,
          maxWidth:
              widget.showLabel
                  ? widget.maxWidth ?? double.infinity
                  : iconOnlyWidth,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.showLabel ? widget.horizontalPadding : 0,
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
                    ),
                    child: widget.child ?? Text(widget.label),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
        child: Semantics(
          button: true,
          enabled: enabled,
          label: widget.showLabel ? null : widget.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: enabled ? (_) => widget.onPressed?.call() : null,
            child: control,
          ),
        ),
      ),
    );
    final tooltip = widget.tooltip ?? widget.label;
    return Tooltip(message: tooltip, child: button);
  }
}

class SmPlayerTextIconButtonColors
    extends ThemeExtension<SmPlayerTextIconButtonColors> {
  const SmPlayerTextIconButtonColors({
    required this.commandText,
    required this.control,
    required this.controlHover,
    required this.controlActive,
    required this.controlBorder,
    required this.accentStrong,
  });

  final Color commandText;
  final Color control;
  final Color controlHover;
  final Color controlActive;
  final Color controlBorder;
  final Color accentStrong;

  static const day = SmPlayerTextIconButtonColors(
    commandText: Color(0xff1f252b),
    control: Color(0x94ffffff),
    controlHover: Color(0xbdffffff),
    controlActive: Color(0x1a0078d7),
    controlBorder: Color(0x2e768499),
    accentStrong: Color(0xff0063b1),
  );

  static const night = SmPlayerTextIconButtonColors(
    commandText: Color(0xf0f6f9fc),
    control: Color(0x0effffff),
    controlHover: Color(0x17ffffff),
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
    Color? control,
    Color? controlHover,
    Color? controlActive,
    Color? controlBorder,
    Color? accentStrong,
  }) {
    return SmPlayerTextIconButtonColors(
      commandText: commandText ?? this.commandText,
      control: control ?? this.control,
      controlHover: controlHover ?? this.controlHover,
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
      control: Color.lerp(control, other.control, t)!,
      controlHover: Color.lerp(controlHover, other.controlHover, t)!,
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
