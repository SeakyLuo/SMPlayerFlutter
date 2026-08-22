part of 'shell_workspace.dart';

class _WorkspaceNavigationAppBarTitle extends StatelessWidget {
  const _WorkspaceNavigationAppBarTitle({
    required this.title,
    required this.tooltip,
    required this.color,
  });

  final String title;
  final String? tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) {
      return const SizedBox.expand();
    }
    final style = TextStyle(
      color: color,
      fontSize: 16,
      height: 1.1,
      fontWeight: FontWeight.w700,
    );
    final label = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textScaler: TextScaler.noScaling,
      style: style,
    );
    if (tooltip == null) {
      return label;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: title, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: TextScaler.noScaling,
          locale: Localizations.maybeLocaleOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        return painter.didExceedMaxLines
            ? Tooltip(message: tooltip!, child: label)
            : label;
      },
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.title,
    required this.tooltip,
    required this.height,
  });

  final String title;
  final String? tooltip;
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: ShellThemeColors.of(context).headerText,
      fontSize: 40,
      height: 1.1,
      fontWeight: FontWeight.w500,
    );
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 142, 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final label = Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              );
              if (tooltip == null) {
                return label;
              }
              final painter = TextPainter(
                text: TextSpan(text: title, style: style),
                maxLines: 1,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                locale: Localizations.maybeLocaleOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              return painter.didExceedMaxLines
                  ? Tooltip(message: tooltip!, child: label)
                  : label;
            },
          ),
        ),
      ),
    );
  }
}
