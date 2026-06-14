part of 'page_search_history_panel.dart';

class PageSearchField extends StatefulWidget {
  const PageSearchField({
    super.key,
    required this.value,
    required this.hintText,
    required this.focused,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onSubmitted,
    required this.onClear,
    this.autofocus = false,
    this.height = 40,
    this.appBar = false,
    this.leadingGap = 0,
    this.searchSurface,
    this.insetHighlight,
    this.searchTooltip,
    this.clearTooltip,
    this.searchIcon,
  });

  final String value;
  final String hintText;
  final bool focused;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;
  final bool autofocus;
  final double height;
  final bool appBar;
  final double leadingGap;
  final Color? searchSurface;
  final Color? insetHighlight;
  final String? searchTooltip;
  final String? clearTooltip;
  final Widget? searchIcon;

  @override
  State<PageSearchField> createState() => _PageSearchFieldState();
}

class _PageSearchFieldState extends State<PageSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode(debugLabel: 'PageSearchField');
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant PageSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (_focused != focused) {
      setState(() {
        _focused = focused;
      });
    }
    widget.onFocusChanged(focused);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PageSearchColors.resolve(context, appBar: widget.appBar);
    final focused = _focused || _focusNode.hasFocus || widget.focused;
    final searchSurface = widget.searchSurface ?? colors.searchSurface;
    final insetHighlight = widget.insetHighlight ?? colors.insetHighlight;
    final textLineHeight =
        widget.appBar
            ? SearchTextInputMetrics.appBarLineHeightForHeight(widget.height)
            : SearchTextInputMetrics.lineHeight;
    final strutStyle =
        widget.appBar
            ? SearchTextInputMetrics.appBarStrutStyleForHeight(widget.height)
            : SearchTextInputMetrics.strutStyle;
    const borderRadius = 10.0;
    return SizedBox(
      height: widget.height,
      child: TextFieldTapRegion(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: focused ? colors.focusedSurface : searchSurface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: focused ? colors.focusedBorder : colors.border,
            ),
            boxShadow:
                focused
                    ? [
                      BoxShadow(
                        color: colors.focusRing,
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: insetHighlight,
                        offset: Offset(0, 1),
                        blurRadius: 0,
                        spreadRadius: 0,
                        blurStyle: BlurStyle.inner,
                      ),
                    ],
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: widget.height,
                child: SearchCommitIconButton(
                  tooltip: widget.searchTooltip ?? widget.hintText,
                  foreground: colors.textMuted,
                  hoverForeground: colors.accent,
                  hoverBackground:
                      SearchCommitIconButton.transparentHoverBackground,
                  icon: widget.searchIcon,
                  onPressed: widget.onSubmitted,
                ),
              ),
              if (widget.leadingGap > 0) SizedBox(width: widget.leadingGap),
              Expanded(
                child: SizedBox(
                  height: widget.height,
                  child:
                      widget.appBar
                          ? Transform.translate(
                            key: const ValueKey(
                              'PageSearchField.AppBarTextOffset',
                            ),
                            offset: const Offset(
                              0,
                              SearchTextInputMetrics.appBarTextVisualOffset,
                            ),
                            transformHitTests: false,
                            child: _buildTextField(
                              textLineHeight,
                              strutStyle,
                              colors,
                            ),
                          )
                          : _buildTextField(textLineHeight, strutStyle, colors),
                ),
              ),
              if (_controller.text.isNotEmpty)
                SizedBox(
                  width: 30,
                  height: widget.height,
                  child: _PageSearchIconButton(
                    tooltip: widget.clearTooltip,
                    icon: FluentIcons.dismiss_16_regular,
                    iconSize: 14,
                    borderRadius: 8,
                    hoverBackground: colors.iconButtonHover,
                    foreground: colors.textMuted,
                    hoverForeground: colors.accent,
                    onPressed: () {
                      _controller.clear();
                      widget.onClear();
                    },
                  ),
                ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  TextField _buildTextField(
    double textLineHeight,
    StrutStyle strutStyle,
    _PageSearchColors colors,
  ) {
    final contentPadding =
        widget.appBar
            ? SearchTextInputMetrics.appBarContentPaddingForHeight(
              widget.height,
            )
            : SearchTextInputMetrics.contentPaddingForHeight(widget.height);
    return TextField(
      autofocus: widget.autofocus,
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      onTapOutside: (_) {
        _focusNode.unfocus();
      },
      onSubmitted: (_) {
        widget.onSubmitted();
      },
      textInputAction: TextInputAction.search,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(
        fontSize: SearchTextInputMetrics.fontSize,
        height: textLineHeight,
        color: colors.textStrong,
      ),
      strutStyle: strutStyle,
      cursorColor: colors.textStrong,
      cursorHeight:
          widget.appBar ? SearchTextInputMetrics.appBarCursorHeight : null,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hintText,
        hintStyle: TextStyle(
          fontSize: SearchTextInputMetrics.fontSize,
          height: textLineHeight,
          color: colors.placeholder,
        ),
        border: InputBorder.none,
        contentPadding: contentPadding,
      ),
    );
  }
}
