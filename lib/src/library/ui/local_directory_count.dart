import 'package:flutter/material.dart';
import '../../app/loading_state.dart';
import '../../i18n/app_i18n.dart';
import 'local_i18n_counts.dart';
import 'local_page_quick_jump.dart';

class LocalDirectoryCount extends StatelessWidget {
  const LocalDirectoryCount({
    super.key,
    this.loading = false,
    this.folders = 0,
    this.songs = 0,
  });
  final bool loading;
  final int folders;
  final int songs;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      formatFolderCardStats(context.smPlayerI18n, folders, songs),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: LocalPageColors.of(context).textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontVariations: const [FontVariation.weight(650)],
      ),
    );
    if (!loading) return text;
    return ExcludeSemantics(
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          SizedBox(width: 144, child: Opacity(opacity: 0, child: text)),
          const SmPlayerSkeletonBlock(width: 144, height: 14),
        ],
      ),
    );
  }
}
