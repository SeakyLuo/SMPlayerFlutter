part of 'popup_dialog.dart';

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
