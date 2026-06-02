part of 'music_dialog.dart';

class MusicInfoControl extends StatelessWidget {
  const MusicInfoControl({
    super.key,
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
    required this.propertiesDirty,
    required this.onPlay,
    required this.onSave,
    required this.onReset,
    required this.onClearPlayCount,
    required this.onAddArtistCell,
    required this.onRemoveArtistCell,
    required this.onReveal,
  });

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
  final bool propertiesDirty;
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

    return Column(
      children: [
        _MusicDialogCommandBar(
          children: [
            if (onPlay != null)
              _MusicDialogCommandButton(
                icon:
                    canPause
                        ? FluentIcons.pause_20_regular
                        : FluentIcons.play_20_regular,
                label:
                    canPause ? i18n.t('context.pause') : i18n.t('context.play'),
                onPressed: onPlay,
              ),
            _MusicDialogCommandButton(
              icon: FluentIcons.save_20_regular,
              label: i18n.t('settings.save'),
              primary: true,
              disabled: loading || saving,
              onPressed: onSave,
            ),
            if (propertiesDirty)
              _MusicDialogCommandButton(
                icon: FluentIcons.arrow_reset_20_regular,
                label: i18n.t('common.reset'),
                disabled: loading || saving,
                onPressed: onReset,
              ),
          ],
        ),
        Expanded(
          child:
              loading || properties == null
                  ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 6, 28, 44),
                    child: _MusicInfoPropertyList(
                      children: [
                        _PropertyRow(
                          label: i18n.t('table.title'),
                          child: _DialogField(controller: titleController),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.subtitle'),
                          child: _DialogField(controller: subtitleController),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.artist'),
                          child: _ArtistFieldGrid(
                            controllers: artistControllers,
                            saving: saving,
                            onAddArtistCell: onAddArtistCell,
                            onRemoveArtistCell: onRemoveArtistCell,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.album'),
                          child: _DialogField(controller: albumController),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.albumArtist'),
                          child: _DialogField(
                            controller: albumArtistController,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.playCount'),
                          child: Row(
                            children: [
                              Expanded(
                                child: _DialogField(
                                  controller: playCountController,
                                  readOnly: true,
                                ),
                              ),
                              if ((properties?.playCount ?? 0) > 0) ...[
                                const SizedBox(width: 8),
                                _MusicDialogCommandButton(
                                  label: i18n.t('song.clearPlayCount'),
                                  compact: true,
                                  disabled: saving,
                                  onPressed: onClearPlayCount,
                                ),
                              ],
                            ],
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.publisher'),
                          child: _DialogField(controller: publisherController),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.trackNumber'),
                          child: _DialogField(
                            controller: trackNumberController,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.year'),
                          child: _DialogField(controller: yearController),
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
                                _MusicDialogCommandButton(
                                  label: i18n.t('song.showInExplorer'),
                                  compact: true,
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
