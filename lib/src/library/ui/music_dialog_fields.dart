part of 'music_dialog.dart';

class _DialogField extends StatelessWidget {
  const _DialogField({
    super.key,
    required this.controller,
    this.readOnly = false,
    this.contentPadding,
  });

  final TextEditingController controller;
  final bool readOnly;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return _DialogTextFieldFrame(
      readOnly: readOnly,
      emphasizeReadOnly: true,
      childBuilder: (context, focusNode) {
        return TextField(
          focusNode: focusNode,
          controller: controller,
          readOnly: readOnly,
          showCursor: !readOnly,
          enableInteractiveSelection: true,
          minLines: 1,
          maxLines: 1,
          cursorColor: colors.accentStrong,
          style: TextStyle(
            color: readOnly ? colors.fieldDisabledText : colors.text,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          decoration: _dialogFieldDecoration(
            context,
            readOnly: readOnly,
            contentPadding: contentPadding,
          ),
        );
      },
    );
  }
}

class _DialogTextFieldFrame extends StatefulWidget {
  const _DialogTextFieldFrame({
    required this.readOnly,
    required this.childBuilder,
    this.emphasizeReadOnly = true,
  });

  final bool readOnly;
  final bool emphasizeReadOnly;
  final Widget Function(BuildContext context, FocusNode focusNode) childBuilder;

  @override
  State<_DialogTextFieldFrame> createState() => _DialogTextFieldFrameState();
}

class _DialogTextFieldFrameState extends State<_DialogTextFieldFrame> {
  late final FocusNode _focusNode;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focused == _focusNode.hasFocus) {
      return;
    }
    setState(() {
      _focused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final brightness = Theme.of(context).brightness;
    final insetTopHighlight = _fieldInsetTopHighlight(
      brightness,
      readOnly: widget.readOnly,
      emphasizeReadOnly: widget.emphasizeReadOnly,
    );
    return AnimatedContainer(
      key: const ValueKey('MusicDialog.DialogTextFieldFrame'),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow:
            widget.readOnly
                ? _readOnlyFieldBoxShadow(
                  brightness,
                  emphasizeReadOnly: widget.emphasizeReadOnly,
                )
                : _fieldBoxShadow(colors),
      ),
      child: Stack(
        children: [
          TextSelectionTheme(
            key: const ValueKey('MusicDialog.TextSelectionTheme'),
            data: TextSelectionThemeData(
              selectionColor: colors.accent.withValues(alpha: 0.22),
            ),
            child: widget.childBuilder(context, _focusNode),
          ),
          if (insetTopHighlight != null)
            Positioned(
              left: 1,
              right: 1,
              top: 1,
              height: 1,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('MusicDialog.FieldInsetTopHighlight'),
                  decoration: BoxDecoration(
                    color: insetTopHighlight,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<BoxShadow> _fieldBoxShadow(PopupDialogResolvedColors colors) {
    return [
      if (_focused) BoxShadow(color: colors.focusRing, spreadRadius: 3),
      const BoxShadow(
        color: Color(0x0a253143),
        offset: Offset(0, 8),
        blurRadius: 18,
      ),
    ];
  }

  List<BoxShadow> _readOnlyFieldBoxShadow(
    Brightness brightness, {
    required bool emphasizeReadOnly,
  }) {
    if (!emphasizeReadOnly) {
      if (brightness == Brightness.dark) {
        return const [
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 1),
            blurRadius: 0,
          ),
        ];
      }
      return const [];
    }
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x18000000),
          offset: Offset(0, 0),
          blurRadius: 0,
        ),
      ];
    }
    return const [];
  }
}

Color? _fieldInsetTopHighlight(
  Brightness brightness, {
  required bool readOnly,
  required bool emphasizeReadOnly,
}) {
  if (readOnly && emphasizeReadOnly) {
    return brightness == Brightness.dark
        ? GlobalUI.readOnlyFieldInsetHighlightNight
        : GlobalUI.readOnlyFieldInsetHighlightDay;
  }
  if (readOnly) {
    if (brightness == Brightness.light) {
      return null;
    }
    return const Color(0x0effffff);
  }
  return brightness == Brightness.dark
      ? const Color(0x0effffff)
      : const Color(0xa6ffffff);
}

class _ArtistFieldGrid extends StatelessWidget {
  const _ArtistFieldGrid({
    required this.controllers,
    required this.saving,
    required this.onAddArtistCell,
    required this.onRemoveArtistCell,
  });

  final List<TextEditingController> controllers;
  final bool saving;
  final VoidCallback onAddArtistCell;
  final ValueChanged<int> onRemoveArtistCell;

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final grid = LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            !mobile && controllers.length > 1 && constraints.maxWidth >= 420
                ? 2
                : 1;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in controllers.indexed)
              SizedBox(
                width:
                    columns == 2
                        ? (constraints.maxWidth - 8) / 2
                        : constraints.maxWidth,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    _DialogField(
                      controller: entry.$2,
                      contentPadding: const EdgeInsets.fromLTRB(12, 0, 34, 0),
                    ),
                    if (controllers.length > 1)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: _ArtistRemoveButton(
                          disabled: saving,
                          onPressed:
                              saving
                                  ? null
                                  : () {
                                    onRemoveArtistCell(entry.$1);
                                  },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
    final addButton =
        controllers.length >= _MusicDialogState.maxArtistCells
            ? null
            : _MusicDialogIconButton(
              iconWidget: const _ElectronIcon(_ElectronIconName.plus, size: 18),
              tooltip: context.smPlayerI18n.t('common.add'),
              size: 42,
              iconSize: 16,
              disabled: saving,
              onPressed: onAddArtistCell,
            );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          grid,
          if (addButton != null) ...[const SizedBox(height: 8), addButton],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: grid),
        if (addButton != null) ...[const SizedBox(width: 8), addButton],
      ],
    );
  }
}

class _ArtistRemoveButton extends StatelessWidget {
  const _ArtistRemoveButton({required this.disabled, required this.onPressed});

  final bool disabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      style: IconButton.styleFrom(
        fixedSize: const Size(28, 28),
        minimumSize: const Size(28, 28),
        padding: EdgeInsets.zero,
        disabledForegroundColor: colors.textMuted.withValues(alpha: 0.48),
        disabledBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return nightMode
                ? GlobalUI.buttonHoverBgColorNight
                : GlobalUI.buttonHoverBgColorDay;
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textMuted.withValues(alpha: 0.48);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colors.text;
          }
          return colors.textMuted;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      icon: const _ElectronIcon(_ElectronIconName.close, size: 14),
      onPressed: disabled ? null : onPressed,
    );
  }
}

InputDecoration _dialogFieldDecoration(
  BuildContext context, {
  required bool readOnly,
  bool emphasizeReadOnly = true,
  bool multiline = false,
  String hintText = '',
  EdgeInsetsGeometry? contentPadding,
}) {
  final colors = PopupDialogColors.resolve(context);
  final nightMode = Theme.of(context).brightness == Brightness.dark;
  final readOnlyBorderColor =
      emphasizeReadOnly
          ? nightMode
              ? GlobalUI.readOnlyFieldBorderColorNight
              : GlobalUI.readOnlyFieldBorderColorDay
          : nightMode
          ? const Color(0x1fd6e0ec)
          : const Color(0x6bbec8d6);
  final readOnlyFillColor =
      emphasizeReadOnly
          ? nightMode
              ? GlobalUI.readOnlyFieldBgColorNight
              : GlobalUI.readOnlyFieldBgColorDay
          : colors.fieldDisabledSurface;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: colors.inputBorder),
  );
  final readOnlyBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: readOnlyBorderColor),
  );
  return InputDecoration(
    isDense: false,
    constraints:
        multiline ? null : const BoxConstraints(minHeight: 42, maxHeight: 42),
    contentPadding:
        contentPadding ??
        (multiline
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(horizontal: 12)),
    hintText: hintText,
    hintStyle: TextStyle(color: colors.textMuted),
    border: border,
    enabledBorder: readOnly ? readOnlyBorder : border,
    disabledBorder: readOnlyBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color:
            readOnly
                ? readOnlyBorderColor
                : colors.accent.withValues(alpha: 0.72),
      ),
    ),
    filled: true,
    fillColor: readOnly ? readOnlyFillColor : colors.fieldSurface,
  );
}
