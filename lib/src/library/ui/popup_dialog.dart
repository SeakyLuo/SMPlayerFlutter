import 'dart:async';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

class PopupDialog extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final i18n =
        context.maybeSmPlayerI18n ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final colors = PopupDialogColors.resolve(context);

    return Material(
      color: Colors.transparent,
      child: Semantics(
        label: ariaLabel ?? navLabel,
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: closeOnBackdrop ? onClose : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colors.overlay),
                ),
              ),
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dialogWidth = (constraints.maxWidth - 48).clamp(
                      0.0,
                      width,
                    );
                    final dialogHeight = (constraints.maxHeight - 48).clamp(
                      0.0,
                      height,
                    );
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: SizedBox(
                        width: dialogWidth,
                        height: dialogHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                            boxShadow: [
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
                                label: navLabel,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    28,
                                    22,
                                    28,
                                    18,
                                  ),
                                  child: Row(
                                    children: [
                                      ...navChildren,
                                      const Spacer(),
                                      Tooltip(
                                        message: i18n.t('common.close'),
                                        child: IconButton(
                                          style: IconButton.styleFrom(
                                            fixedSize: const Size.square(42),
                                            foregroundColor: colors.text,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              side: BorderSide(
                                                color: colors.buttonBorder,
                                              ),
                                            ),
                                            backgroundColor:
                                                colors.buttonSurface,
                                          ),
                                          icon: const Icon(
                                            FluentIcons.dismiss_20_regular,
                                            size: 18,
                                          ),
                                          onPressed: onClose,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (afterNav != null) afterNav!,
                              Expanded(child: child),
                              if (footer != null) footer!,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.first = false,
    this.last = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return TextButton(
      style: TextButton.styleFrom(
        fixedSize: const Size(138, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: selected ? colors.accent : colors.text,
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
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
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
          PopupDialogTitle(widget.title, centered: true),
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
  String? pendingLabel,
  bool destructive = true,
  Future<void> Function()? onConfirm,
}) async {
  return await showDialog<bool>(
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
                    PopupDialogTitle(title, centered: true),
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
                          label:
                              submitting
                                  ? pendingLabel ?? confirmLabel
                                  : confirmLabel,
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
}

class _InputDialogShell extends StatelessWidget {
  const _InputDialogShell({required this.ariaLabel, required this.child});

  final String ariaLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Material(
      color: Colors.transparent,
      child: Semantics(
        label: ariaLabel,
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(decoration: BoxDecoration(color: colors.overlay)),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.inputBorder),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: 60,
                            offset: const Offset(0, 24),
                          ),
                        ],
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

class PopupDialogTitle extends StatelessWidget {
  const PopupDialogTitle(this.text, {super.key, this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: 22,
        fontWeight: FontWeight.w500,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < children.length; index += 1) ...[
            if (index > 0) const SizedBox(width: 18),
            children[index],
          ],
        ],
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
    final background =
        primary
            ? destructive
                ? colors.destructive
                : colors.accent
            : Colors.transparent;
    final foreground = primary ? Colors.white : colors.accentStrong;

    return TextButton(
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: const Size(88, 36),
        maximumSize: const Size(double.infinity, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: foreground,
        disabledForegroundColor: foreground.withValues(alpha: 0.72),
        backgroundColor: background,
        disabledBackgroundColor: background.withValues(alpha: 0.72),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ).copyWith(
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
  static const inputBorder = Color(0x33b9c3d2);
  static const shadow = Color(0x47232d3c);
  static const buttonSurface = Color(0xebffffff);
  static const activeButtonSurface = Color(0xf5eff6ff);
  static const buttonBorder = Color(0x9ebec8d6);
  static const activeButtonBorder = Color(0x610078d7);
  static const accent = Color(0xff0063b1);
  static const accentSoft = Color(0x290078d7);
  static const text = Color(0xff273142);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const fieldSurface = Color(0xe6ffffff);
  static const fieldDisabledSurface = Color(0xade6ebf3);
  static const focusRing = Color(0x240078d7);
  static const destructive = Color(0xffd13438);
  static const nightOverlay = Color(0x9e04080d);
  static const nightSurface = Color(0xf00f1722);
  static const nightBorder = Color(0x4dffffff);
  static const nightInputBorder = Color(0x33ffffff);
  static const nightShadow = Color(0x6b000000);
  static const nightButtonSurface = Color(0x12ffffff);
  static const nightActiveButtonSurface = Color(0x2e0078d7);
  static const nightButtonBorder = Color(0x33ffffff);
  static const nightActiveButtonBorder = Color(0x610078d7);
  static const nightText = Color(0xffdbeafe);
  static const nightTextStrong = Color(0xfff8fafc);
  static const nightTextMuted = Color(0xffcbd5e1);
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
    required this.buttonBorder,
    required this.activeButtonBorder,
    required this.accent,
    required this.accentStrong,
    required this.text,
    required this.textStrong,
    required this.textMuted,
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
  final Color buttonBorder;
  final Color activeButtonBorder;
  final Color accent;
  final Color accentStrong;
  final Color text;
  final Color textStrong;
  final Color textMuted;
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
    buttonBorder: PopupDialogColors.buttonBorder,
    activeButtonBorder: PopupDialogColors.activeButtonBorder,
    accent: PopupDialogColors.accent,
    accentStrong: PopupDialogColors.accent,
    text: PopupDialogColors.text,
    textStrong: PopupDialogColors.textStrong,
    textMuted: PopupDialogColors.textMuted,
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
    buttonBorder: PopupDialogColors.nightButtonBorder,
    activeButtonBorder: PopupDialogColors.nightActiveButtonBorder,
    accent: PopupDialogColors.accent,
    accentStrong: Color(0xff66b7ff),
    text: PopupDialogColors.nightText,
    textStrong: PopupDialogColors.nightTextStrong,
    textMuted: PopupDialogColors.nightTextMuted,
    fieldSurface: PopupDialogColors.nightFieldSurface,
    fieldDisabledSurface: PopupDialogColors.nightFieldDisabledSurface,
    focusRing: Color(0x2e0078d7),
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
