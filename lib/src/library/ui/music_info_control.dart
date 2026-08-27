part of 'music_dialog.dart';

class MusicInfoControl extends StatelessWidget {
  const MusicInfoControl({
    super.key,
    required this.sessionKey,
    required this.loading,
    required this.saving,
    required this.properties,
    required this.artistControllers,
    required this.titleController,
    required this.subtitleController,
    required this.albumController,
    required this.albumArtistController,
    required this.playCountController,
    required this.publisherController,
    required this.trackNumberController,
    required this.yearController,
    required this.bitrateController,
    required this.composersController,
    required this.dateCreatedController,
    required this.dateModifiedController,
    required this.durationController,
    required this.fileSizeController,
    required this.fileTypeController,
    required this.genreController,
    required this.pathController,
    required this.canPause,
    required this.onPlay,
    required this.onSave,
    required this.onReset,
    required this.onClearPlayCount,
    required this.onAddArtistCell,
    required this.onRemoveArtistCell,
    required this.onReveal,
  });

  final MusicDialogSessionKey sessionKey;
  final bool loading;
  final bool saving;
  final SongPropertiesSnapshot? properties;
  final List<TextEditingController> artistControllers;
  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final TextEditingController albumController;
  final TextEditingController albumArtistController;
  final TextEditingController playCountController;
  final TextEditingController publisherController;
  final TextEditingController trackNumberController;
  final TextEditingController yearController;
  final TextEditingController bitrateController;
  final TextEditingController composersController;
  final TextEditingController dateCreatedController;
  final TextEditingController dateModifiedController;
  final TextEditingController durationController;
  final TextEditingController fileSizeController;
  final TextEditingController fileTypeController;
  final TextEditingController genreController;
  final TextEditingController pathController;
  final bool canPause;
  final VoidCallback? onPlay;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final VoidCallback onClearPlayCount;
  final VoidCallback onAddArtistCell;
  final ValueChanged<int> onRemoveArtistCell;
  final ValueChanged<String>? onReveal;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final currentProperties = properties;
    final titleFilename =
        currentProperties == null
            ? ''
            : p.basenameWithoutExtension(currentProperties.path);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;

    return Column(
      children: [
        Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(
              musicDialogPropertiesStateProvider(sessionKey),
            );
            return _MusicDialogCommandBar(
              showBusy: false,
              children: [
                if (state.dirty)
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
                if (onPlay != null)
                  _MusicDialogCommandButton(
                    iconWidget: _ElectronIcon(
                      canPause
                          ? _ElectronIconName.pause
                          : _ElectronIconName.play,
                      size: 20,
                    ),
                    label:
                        canPause
                            ? i18n.t('context.pause')
                            : i18n.t('context.play'),
                    commandBar: true,
                    onPressed: onPlay,
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
                  disabled: loading,
                  onPressed: onSave,
                ),
              ],
            );
          },
        ),
        Expanded(
          child:
              loading
                  ? const _SongDialogLoading()
                  : properties == null
                  ? const SizedBox.expand()
                  : _SongDialogScrollableBody(
                    padding:
                        mobile
                            ? const EdgeInsets.fromLTRB(12, 0, 12, 28)
                            : const EdgeInsets.fromLTRB(28, 6, 28, 44),
                    child: _MusicInfoPropertyList(
                      children: [
                        _PropertyRow(
                          label: i18n.t('table.title'),
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: titleController,
                            builder: (context, value, child) {
                              final showUseFilenameButton =
                                  currentProperties != null &&
                                  value.text != titleFilename;
                              return Row(
                                children: [
                                  Expanded(
                                    child: _DialogField(
                                      controller: titleController,
                                      readOnly: saving,
                                    ),
                                  ),
                                  if (showUseFilenameButton) ...[
                                    const SizedBox(width: 8),
                                    _MusicDialogIconButton(
                                      key: const ValueKey(
                                        'MusicDialog.UseFileNameButton',
                                      ),
                                      iconWidget: const _ElectronIcon(
                                        _ElectronIconName.refresh,
                                        size: 18,
                                      ),
                                      tooltip: i18n.t(
                                        'song.syncTitleToFilename',
                                        {'filename': titleFilename},
                                      ),
                                      disabled: saving,
                                      onPressed: () {
                                        titleController.text = titleFilename;
                                      },
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.subtitle'),
                          child: _DialogField(
                            controller: subtitleController,
                            readOnly: saving,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.artist'),
                          child: MusicDialogArtistFieldGrid(
                            controllers: artistControllers,
                            saving: saving,
                            onAddArtistCell: onAddArtistCell,
                            onRemoveArtistCell: onRemoveArtistCell,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.album'),
                          child: _DialogField(
                            controller: albumController,
                            readOnly: saving,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.albumArtist'),
                          child: _DialogField(
                            controller: albumArtistController,
                            readOnly: saving,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.playCount'),
                          child: ListenableBuilder(
                            listenable: Listenable.merge([
                              titleController,
                              playCountController,
                            ]),
                            builder: (context, child) {
                              final playCount =
                                  int.tryParse(playCountController.text) ?? 0;
                              final tooltip =
                                  playCount == 0
                                      ? i18n.t('song.notPlayedYet', {
                                        'title': titleController.text,
                                      })
                                      : i18n.t('song.hasBeenPlayed', {
                                        'title': titleController.text,
                                        'count': playCount.toString(),
                                      });
                              return Row(
                                children: [
                                  Expanded(
                                    child: Tooltip(
                                      message: tooltip,
                                      child: _DialogField(
                                        controller: playCountController,
                                        readOnly: true,
                                      ),
                                    ),
                                  ),
                                  if (playCount > 0) ...[
                                    const SizedBox(width: 8),
                                    _MusicDialogIconButton(
                                      key: const ValueKey(
                                        'MusicDialog.ClearPlayCountButton',
                                      ),
                                      iconWidget: const _ElectronIcon(
                                        _ElectronIconName.undo,
                                        size: 18,
                                      ),
                                      tooltip: i18n.t(
                                        'song.resetPlayCountToZero',
                                      ),
                                      disabled: saving,
                                      onPressed: onClearPlayCount,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.publisher'),
                          child: _DialogField(
                            controller: publisherController,
                            readOnly: saving,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.trackNumber'),
                          child: _DialogField(
                            key: const ValueKey('TrackNumberTextBox'),
                            controller: trackNumberController,
                            readOnly: saving,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.year'),
                          child: _DialogField(
                            key: const ValueKey('YearTextBox'),
                            controller: yearController,
                            readOnly: saving,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.bitrate'),
                          child: _DialogField(
                            controller: bitrateController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.composers'),
                          child: _DialogField(
                            controller: composersController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.dateCreated'),
                          child: _DialogField(
                            controller: dateCreatedController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.dateModified'),
                          child: _DialogField(
                            controller: dateModifiedController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.duration'),
                          child: _DialogField(
                            controller: durationController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.fileSize'),
                          child: _DialogField(
                            controller: fileSizeController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.fileType'),
                          child: _DialogField(
                            controller: fileTypeController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.genre'),
                          child: _DialogField(
                            controller: genreController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('local.path'),
                          child: Row(
                            children: [
                              Expanded(
                                child: _DialogField(
                                  controller: pathController,
                                  readOnly: true,
                                ),
                              ),
                              if (onReveal != null) ...[
                                const SizedBox(width: 8),
                                _MusicDialogIconButton(
                                  key: const ValueKey(
                                    'MusicDialog.ShowInExplorerButton',
                                  ),
                                  iconWidget: const _ElectronIcon(
                                    _ElectronIconName.folder,
                                    size: 18,
                                  ),
                                  tooltip: i18n.t('song.showInExplorer'),
                                  onPressed: () {
                                    onReveal!(pathController.text);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ],
    );
  }
}
