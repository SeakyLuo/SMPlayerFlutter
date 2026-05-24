import 'package:flutter/material.dart';

import '../../app/text_icon_button.dart';
import 'default_album_artwork.dart';
import 'missing_library_root_content.dart';
import 'local_page_quick_jump.dart';

class LocalPageScaffold extends StatelessWidget {
  const LocalPageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: SizedBox.expand(child: child),
    );
  }
}

class LocalPageContentPanel extends StatelessWidget {
  const LocalPageContentPanel({
    super.key,
    required this.scrollController,
    required this.scrollable,
    required this.child,
  });

  final ScrollController scrollController;
  final bool scrollable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LocalPageColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LocalPageColors.panelBorder),
        boxShadow: const [
          BoxShadow(
            color: LocalPageColors.panelShadow,
            offset: Offset(0, 22),
            blurRadius: 52,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child:
            scrollable
                ? SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
                  child: child,
                )
                : child,
      ),
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
