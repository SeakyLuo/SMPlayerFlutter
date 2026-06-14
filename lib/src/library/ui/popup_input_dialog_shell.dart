part of 'popup_dialog.dart';

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
