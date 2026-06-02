import 'package:flutter/material.dart';

import '../../app/workspace_app_bar_portal.dart';
import '../../app/text_icon_button.dart';
import 'default_album_artwork.dart';
import 'missing_library_root_content.dart';

const _localPageCompactBreakpoint = 720.0;

class LocalPageScaffold extends StatelessWidget {
  const LocalPageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < _localPageCompactBreakpoint;
    final underWorkspaceHeader = WorkspaceNavigationAppBarScope.of(context);
    return Padding(
      padding:
          compact
              ? const EdgeInsets.fromLTRB(12, 6, 12, 0)
              : underWorkspaceHeader
              ? const EdgeInsets.fromLTRB(24, 0, 24, 0)
              : const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: SizedBox.expand(child: child),
    );
  }
}

class LocalPageContentPanel extends StatelessWidget {
  const LocalPageContentPanel({
    super.key,
    required this.scrollController,
    required this.scrollable,
    required this.compact,
    required this.bottomPadding,
    required this.child,
  });

  final ScrollController scrollController;
  final bool scrollable;
  final bool compact;
  final double bottomPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      if (!scrollable) {
        return child;
      }
      return _LocalScrollableContent(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(0, 4, 0, bottomPadding),
        child: child,
      );
    }

    if (!scrollable) {
      return child;
    }
    return _LocalScrollableContent(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(6, 4, 6, bottomPadding),
      child: child,
    );
  }
}

class _LocalScrollableContent extends StatelessWidget {
  const _LocalScrollableContent({
    required this.controller,
    required this.padding,
    required this.child,
  });

  final ScrollController controller;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth - padding.horizontal;
        return SingleChildScrollView(
          controller: controller,
          child: Padding(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidth > 0 ? minWidth : 0,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class LocalPageEmptyState extends StatelessWidget {
  const LocalPageEmptyState({
    super.key,
    required this.title,
    this.message = '',
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = MissingLibraryRootThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: LocalPageEmptyArtwork(),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(650)],
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class LocalPageEmptyArtwork extends StatelessWidget {
  const LocalPageEmptyArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = MissingLibraryRootThemeColors.of(context);
    return SizedBox.square(
      dimension: 104,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors.artworkShadow,
              offset: const Offset(0, 8),
              blurRadius: 18,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.artworkBorder),
            ),
            child: DefaultAlbumArtwork(
              logoScale: 0.72,
              logoOpacity: colors.artworkLogoOpacity,
            ),
          ),
        ),
      ),
    );
  }
}

class LocalCommandButton extends StatelessWidget {
  const LocalCommandButton({
    super.key,
    this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SmPlayerTextIconButton(
      icon: icon,
      label: label,
      loading: loading,
      onPressed: onPressed,
    );
  }
}
