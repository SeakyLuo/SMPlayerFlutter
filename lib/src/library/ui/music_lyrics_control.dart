part of 'music_dialog.dart';

class MusicLyricsControl extends StatelessWidget {
  const MusicLyricsControl({
    super.key,
    required this.loading,
    required this.saving,
    required this.lyrics,
    required this.lyricsController,
    required this.lyricsDirty,
    required this.showLyricsTimestamps,
    required this.lyricsCanToggleTimestamps,
    required this.onSearch,
    required this.onImport,
    required this.onSave,
    required this.onReset,
    required this.onToggleTimestamps,
  });

  final bool loading;
  final bool saving;
  final LyricsSnapshot? lyrics;
  final TextEditingController lyricsController;
  final bool lyricsDirty;
  final bool showLyricsTimestamps;
  final bool lyricsCanToggleTimestamps;
  final VoidCallback onSearch;
  final VoidCallback onImport;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final ValueChanged<bool> onToggleTimestamps;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Column(
      children: [
        _MusicDialogCommandBar(
          children: [
            _MusicDialogCommandButton(
              icon: FluentIcons.search_20_regular,
              label: i18n.t('common.search'),
              disabled: loading || saving,
              onPressed: onSearch,
            ),
            _MusicDialogCommandButton(
              icon: FluentIcons.arrow_import_20_regular,
              label: i18n.t('common.import'),
              disabled: loading || saving,
              onPressed: onImport,
            ),
            _MusicDialogCommandButton(
              icon: FluentIcons.save_20_regular,
              label: i18n.t('settings.save'),
              primary: true,
              disabled: loading || saving,
              onPressed: onSave,
            ),
            if (lyricsDirty)
              _MusicDialogCommandButton(
                icon: FluentIcons.arrow_reset_20_regular,
                label: i18n.t('common.reset'),
                disabled: loading || saving,
                onPressed: onReset,
              ),
            if (lyricsCanToggleTimestamps)
              _LyricsTimestampToggle(
                value: showLyricsTimestamps,
                onChanged: loading || saving ? null : onToggleTimestamps,
              ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 44),
            child:
                loading
                    ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : TextField(
                      controller: lyricsController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      enabled: !saving,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText:
                            lyrics?.source == LyricsSource.none
                                ? i18n.t('nowPlaying.noLyrics')
                                : '',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: PopupDialogColors.fieldSurface,
                      ),
                      style: const TextStyle(height: 1.7),
                    ),
          ),
        ),
      ],
    );
  }
}
