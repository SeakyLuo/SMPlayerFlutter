part of 'music_dialog.dart';

class MusicLyricsControl extends StatelessWidget {
  const MusicLyricsControl({
    super.key,
    required this.sessionKey,
    required this.loading,
    required this.operation,
    required this.lyrics,
    required this.lyricsController,
    required this.lyricsScrollController,
    required this.onSearch,
    required this.onImport,
    required this.onSave,
    required this.onReset,
    required this.onToggleTimestamps,
  });

  final MusicDialogSessionKey sessionKey;
  final bool loading;
  final MusicDialogOperation? operation;
  final LyricsSnapshot? lyrics;
  final TextEditingController lyricsController;
  final ScrollController lyricsScrollController;
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
    final saving = operation == MusicDialogOperation.saveLyrics;
    final importing = operation == MusicDialogOperation.importLyrics;
    final editorLocked = saving || importing;

    return Column(
      children: [
        Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(musicDialogLyricsStateProvider(sessionKey));
            final searching =
                ref
                    .watch(internetLyricsCandidateSearchProvider(sessionKey))
                    .isLoading;
            final operationRunning = state.operation != null;
            return _MusicDialogCommandBar(
              showBusy: false,
              children: [
                _MusicDialogCommandButton(
                  iconWidget: const _ElectronIcon(
                    _ElectronIconName.search,
                    size: 20,
                  ),
                  label: i18n.t('common.search'),
                  commandBar: true,
                  loading: searching,
                  disabled: loading || operationRunning,
                  onPressed: onSearch,
                ),
                _MusicDialogCommandButton(
                  iconWidget: const _ElectronIcon(
                    _ElectronIconName.import,
                    size: 20,
                  ),
                  label: i18n.t('common.import'),
                  commandBar: true,
                  loading: importing,
                  disabled: loading || operationRunning || searching,
                  onPressed: onImport,
                ),
                _MusicDialogCommandButton(
                  iconWidget: const _ElectronIcon(
                    _ElectronIconName.save,
                    size: 20,
                  ),
                  label: i18n.t('settings.save'),
                  primary: true,
                  commandBar: true,
                  loading: saving,
                  disabled: loading || operationRunning || searching,
                  onPressed: onSave,
                ),
                if (state.dirty)
                  _MusicDialogCommandButton(
                    iconWidget: const _ElectronIcon(
                      _ElectronIconName.undo,
                      size: 20,
                    ),
                    label: i18n.t('common.reset'),
                    commandBar: true,
                    disabled: loading || operationRunning || searching,
                    onPressed: onReset,
                  ),
                if (state.lyricsCanToggleTimestamps)
                  _LyricsTimestampToggle(
                    value: state.showLyricsTimestamps,
                    onChanged:
                        loading || operationRunning || searching
                            ? null
                            : onToggleTimestamps,
                  ),
              ],
            );
          },
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
                        readOnly: editorLocked,
                        emphasizeReadOnly: false,
                        childBuilder: (context, focusNode) {
                          return ScrollConfiguration(
                            behavior: const _LyricsEditorScrollBehavior(),
                            child: TextField(
                              focusNode: focusNode,
                              controller: lyricsController,
                              scrollController: lyricsScrollController,
                              expands: true,
                              maxLines: null,
                              minLines: null,
                              enabled: !editorLocked,
                              textAlignVertical: TextAlignVertical.top,
                              cursorColor: colors.accentStrong,
                              style: TextStyle(
                                color:
                                    editorLocked
                                        ? colors.fieldDisabledText
                                        : colors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                height: 1.7,
                              ),
                              decoration: _dialogFieldDecoration(
                                context,
                                readOnly: editorLocked,
                                emphasizeReadOnly: false,
                                multiline: true,
                                hintText:
                                    lyrics?.source == LyricsSource.none
                                        ? i18n.t('nowPlaying.noLyrics')
                                        : '',
                              ),
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

class _LyricsEditorScrollBehavior extends MaterialScrollBehavior {
  const _LyricsEditorScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
