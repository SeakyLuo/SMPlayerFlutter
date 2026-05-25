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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t('hiddenFolders.introduction'),
            style: const TextStyle(
              color: LocalPageColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<HiddenStorageItem>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SmPlayerLoadingState(compact: true);
                }

                final items = snapshot.data ?? const <HiddenStorageItem>[];
                if (items.isEmpty) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: LocalPageColors.emptyStateSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: LocalPageColors.emptyStateBorder,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        child: Text(
                          i18n.t('hiddenFolders.empty'),
                          style: const TextStyle(
                            color: LocalPageColors.textStrong,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _HiddenStorageItemRow(
                      item: items[index],
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

class _HiddenStorageItemRow extends StatelessWidget {
  const _HiddenStorageItemRow({
    required this.item,
    required this.i18n,
    required this.onResume,
  });

  final HiddenStorageItem item;
  final SmPlayerI18n i18n;
  final ValueChanged<HiddenStorageItem> onResume;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LocalPageColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LocalPageColors.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              item.type == 'folder'
                  ? FluentIcons.folder_20_regular
                  : FluentIcons.music_note_2_20_regular,
              color: LocalPageColors.accentStrong,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LocalPageColors.textStrong,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => onResume(item),
              child: Text(i18n.t('hiddenFolders.resume')),
            ),
          ],
        ),
      ),
    );
  }
}
