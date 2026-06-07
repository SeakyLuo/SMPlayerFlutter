part of 'music_dialog.dart';

class MusicLyricsControl extends StatelessWidget {
  const MusicLyricsControl({
    super.key,
    required this.loading,
    required this.saving,
    required this.lyrics,
    required this.lyricsController,
    required this.lyricsScrollController,
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
  final ScrollController lyricsScrollController;
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
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;

    return Column(
      children: [
        _MusicDialogCommandBar(
          showBusy: saving,
          children: [
            _MusicDialogCommandButton(
              iconWidget: const _ElectronIcon(
                _ElectronIconName.search,
                size: 20,
              ),
              label: i18n.t('common.search'),
              commandBar: true,
              disabled: loading || saving,
              onPressed: onSearch,
            ),
            _MusicDialogCommandButton(
              iconWidget: const _ElectronIcon(
                _ElectronIconName.import,
                size: 20,
              ),
              label: i18n.t('common.import'),
              commandBar: true,
              disabled: loading || saving,
              onPressed: onImport,
            ),
            _MusicDialogCommandButton(
              iconWidget: const _ElectronIcon(_ElectronIconName.save, size: 20),
              label: i18n.t('settings.save'),
              primary: true,
              commandBar: true,
              disabled: loading || saving,
              onPressed: onSave,
            ),
            if (lyricsDirty)
              _MusicDialogCommandButton(
                iconWidget: const _ElectronIcon(
                  _ElectronIconName.undo,
                  size: 20,
                ),
                label: i18n.t('common.reset'),
                commandBar: true,
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
          child:
              loading
                  ? const _SongDialogLoading()
                  : _SongDialogScrollbarHost(
                    controller: lyricsScrollController,
                    right: mobile ? 15 : 31,
                    bottom: mobile ? 28 : 44,
                    positionKey: const ValueKey(
                      'MusicDialog.LyricsScrollbar.Position',
                    ),
                    thumbKey: const ValueKey(
                      'MusicDialog.LyricsScrollbar.Thumb',
                    ),
                    child: Padding(
                      padding:
                          mobile
                              ? const EdgeInsets.fromLTRB(12, 0, 12, 28)
                              : const EdgeInsets.fromLTRB(28, 0, 28, 44),
                      child: _DialogTextFieldFrame(
                        readOnly: saving,
                        emphasizeReadOnly: false,
                        childBuilder: (context, focusNode) {
                          return TextField(
                            focusNode: focusNode,
                            controller: lyricsController,
                            scrollController: lyricsScrollController,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            enabled: !saving,
                            textAlignVertical: TextAlignVertical.top,
                            cursorColor: colors.accentStrong,
                            style: TextStyle(
                              color:
                                  saving
                                      ? colors.fieldDisabledText
                                      : colors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.7,
                            ),
                            decoration: _dialogFieldDecoration(
                              context,
                              readOnly: saving,
                              emphasizeReadOnly: false,
                              multiline: true,
                              hintText:
                                  lyrics?.source == LyricsSource.none
                                      ? i18n.t('nowPlaying.noLyrics')
                                      : '',
                            ),
                          );
                        },
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}
