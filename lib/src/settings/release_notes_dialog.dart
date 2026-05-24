import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/settings/release_notes_model.dart';

class ReleaseNotesDialog extends StatelessWidget {
  const ReleaseNotesDialog({
    super.key,
    required this.version,
    required this.onClose,
  });

  final String? version;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final releaseNotes = getReleaseNotes(i18n);

    return PopupDialog(
      navLabel: i18n.t('settings.releaseNotes'),
      ariaLabel: i18n.t('settings.releaseNotes'),
      width: 640,
      height: 600,
      onClose: onClose,
      navChildren: [
        Expanded(child: PopupDialogTitle(i18n.t('settings.releaseNotes'))),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 44),
        child: Scrollbar(
          child: ListView.separated(
            primary: false,
            padding: const EdgeInsets.only(right: 14),
            itemCount: releaseNotes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 18),
            itemBuilder: (context, index) {
              return _ReleaseNoteVersion(entry: releaseNotes[index]);
            },
          ),
        ),
      ),
    );
  }
}

class _ReleaseNoteVersion extends StatelessWidget {
  const _ReleaseNoteVersion({required this.entry});

  final ReleaseNoteEntry entry;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final title =
        entry.version == 'History Updates'
            ? i18n.t('settings.releaseNotesIntro')
            : '${i18n.t('settings.releaseNotesVersion')} ${entry.version}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...entry.items.map((item) => _ReleaseNoteItem(text: item)),
      ],
    );
  }
}

class _ReleaseNoteItem extends StatelessWidget {
  const _ReleaseNoteItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 5,
              height: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.textStrong, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
