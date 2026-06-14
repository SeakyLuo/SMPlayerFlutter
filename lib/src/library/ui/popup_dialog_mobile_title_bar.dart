part of 'popup_dialog.dart';

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
    final leadingInset =
        Platform.isMacOS ? SmPlayerShellMetrics.macOSTitlebarLeadingInset : 8.0;
    return Padding(
      key: const ValueKey('popup-dialog-mobile-titlebar'),
      padding: EdgeInsets.only(left: leadingInset),
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
