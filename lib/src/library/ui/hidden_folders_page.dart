import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/loading_state.dart';
import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'local_page_quick_jump.dart';

class HiddenFoldersPage extends ConsumerStatefulWidget {
  const HiddenFoldersPage({super.key});

  @override
  ConsumerState<HiddenFoldersPage> createState() => _HiddenFoldersPageState();
}

class _HiddenFoldersPageState extends ConsumerState<HiddenFoldersPage> {
  late Future<List<HiddenStorageItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  Future<List<HiddenStorageItem>> _loadItems() {
    return ref.read(libraryRepositoryProvider).getHiddenStorageItems();
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const SmPlayerLoadingState();
    }
    final colors = LocalPageColors.of(context);
    final pageLoading = ref.watch(libraryContentDataProvider).isLoading;

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              i18n.t('hiddenFolders.introduction'),
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
          ),
          if (pageLoading)
            _HiddenStorageRootBanner(text: i18n.t('library.refreshing')),
          Expanded(
            child: FutureBuilder<List<HiddenStorageItem>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _HiddenStorageLoadingState();
                }

                final items = snapshot.data ?? const <HiddenStorageItem>[];
                if (items.isEmpty) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _HiddenStorageStatusCard(
                        child: Text(
                          i18n.t('hiddenFolders.empty'),
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 18),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _HiddenStorageItemRow(
                      item: items[index],
                      even: index.isEven,
                      i18n: i18n,
                      onResume: _resumeItem,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resumeItem(HiddenStorageItem item) async {
    await ref.read(libraryRepositoryProvider).resumeHiddenStorageItem(item);
    ref.invalidate(libraryContentDataProvider);
    setState(() {
      _itemsFuture = _loadItems();
    });
  }
}

class _HiddenStorageRootBanner extends StatelessWidget {
  const _HiddenStorageRootBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _HiddenFoldersColors.emptyStateSurfaceFor(brightness),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _HiddenFoldersColors.emptyStateBorderFor(brightness),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Text(
            text,
            style: TextStyle(
              color: _HiddenFoldersColors.textStrongFor(brightness),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _HiddenStorageItemRow extends StatelessWidget {
  const _HiddenStorageItemRow({
    required this.item,
    required this.even,
    required this.i18n,
    required this.onResume,
  });

  final HiddenStorageItem item;
  final bool even;
  final SmPlayerI18n i18n;
  final ValueChanged<HiddenStorageItem> onResume;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    final brightness = Theme.of(context).brightness;
    return ColoredBox(
      color:
          even
              ? _HiddenFoldersColors.surfaceSubtleFor(brightness)
              : _HiddenFoldersColors.panelFor(brightness),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 42),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                child: Icon(
                  item.type == 'folder'
                      ? FluentIcons.folder_20_regular
                      : FluentIcons.music_note_2_20_regular,
                  size: 22,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.path,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: OutlinedButton(
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(const Size(0, 32)),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    side: WidgetStateProperty.all(
                      BorderSide(
                        color: _HiddenFoldersColors.borderSubtleFor(brightness),
                      ),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return _HiddenFoldersColors.surfaceControlHoverFor(
                          brightness,
                        );
                      }
                      return _HiddenFoldersColors.surfaceControlFor(brightness);
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return colors.accentStrong;
                      }
                      return colors.textStrong;
                    }),
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 13),
                    ),
                  ),
                  onPressed: () => onResume(item),
                  child: Text(i18n.t('hiddenFolders.resume')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HiddenStorageLoadingState extends StatelessWidget {
  const _HiddenStorageLoadingState();

  @override
  Widget build(BuildContext context) {
    final i18n =
        context.maybeSmPlayerI18n ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final label = i18n.t('nowPlaying.loading');
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: double.infinity,
        child: _HiddenStorageStatusCard(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: label,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _HiddenFoldersColors.accent,
                      backgroundColor: _HiddenFoldersColors.accent.withValues(
                        alpha: 0.18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: _HiddenFoldersColors.textStrongFor(
                        Theme.of(context).brightness,
                      ),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HiddenStorageStatusCard extends StatelessWidget {
  const _HiddenStorageStatusCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _HiddenFoldersColors.emptyStateSurfaceFor(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _HiddenFoldersColors.emptyStateBorderFor(brightness),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: child,
      ),
    );
  }
}

class _HiddenFoldersColors {
  const _HiddenFoldersColors._();

  static const accent = Color(0xff0078d7);

  static Color panelFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x0cffffff)
        : const Color(0xc7fcfdff);
  }

  static Color surfaceSubtleFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x09ffffff)
        : const Color(0x0cffffff);
  }

  static Color surfaceControlFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x0effffff)
        : const Color(0x94ffffff);
  }

  static Color surfaceControlHoverFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x290078d7)
        : const Color(0x1a0078d7);
  }

  static Color borderSubtleFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fd6e0ec)
        : const Color(0x2e768499);
  }

  static Color emptyStateSurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x0cffffff)
        : const Color(0x94ffffff);
  }

  static Color emptyStateBorderFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fd6e0ec)
        : const Color(0x94ffffff);
  }

  static Color textStrongFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xeff6f9fc)
        : const Color(0xff1f252b);
  }
}
