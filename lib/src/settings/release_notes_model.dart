import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

class ReleaseNoteEntry {
  const ReleaseNoteEntry({required this.version, required this.items});

  final String version;
  final List<String> items;
}

class _ReleaseNoteDefinition {
  const _ReleaseNoteDefinition(this.version, this.itemKeys);

  final String version;
  final List<String> itemKeys;
}

List<ReleaseNoteEntry> getReleaseNotes(SmPlayerI18n i18n) {
  return _releaseNoteDefinitions
      .map(
        (definition) => ReleaseNoteEntry(
          version: definition.version,
          items:
              definition.itemKeys
                  .map((key) => i18n.t('releaseNotes.$key'))
                  .toList(),
        ),
      )
      .toList();
}

const _releaseNoteDefinitions = [
  _ReleaseNoteDefinition('4.0.0', [
    'tryLiquidGlass',
    'lyricsSearchSupport',
    'batchEditSongInfoSupport',
    'randomPlayMenuScopes',
    'aiControlSupport',
  ]),
  _ReleaseNoteDefinition('3.0.0', [
    'architectureFeedback',
    'modernUi',
    'nightMode',
    'multiLanguageSupport',
    'multiArtistRecognition',
    'desktopLyricsReplacement',
    'tilesUnsupported',
  ]),
  _ReleaseNoteDefinition('2.10.7', [
    'newUiComing',
    'renameToSimpleMelodyPlayer',
    'bugFixes',
  ]),
  _ReleaseNoteDefinition('2.10.3', ['bugFixes']),
  _ReleaseNoteDefinition('2.10.1', [
    'switchLanguageSupported',
    'improvedVoiceAssistant',
  ]),
  _ReleaseNoteDefinition('2.9.15', ['addSeeAlbumArtToFullPage', 'crashFixes']),
  _ReleaseNoteDefinition('2.9.14', [
    'bugFixForImportData',
    'crashFixes',
    'bugFixes',
  ]),
  _ReleaseNoteDefinition('2.9.11', ['crashFixes']),
  _ReleaseNoteDefinition('2.9.8', ['bugFixForImportData', 'crashFixes']),
  _ReleaseNoteDefinition('2.9.6', ['crashFixes']),
  _ReleaseNoteDefinition('2.9.2', ['crashFixes']),
  _ReleaseNoteDefinition('2.9.0', [
    'addPointerOverButtonsToMusicList',
    'bugFixForPlayInTheFlyoutMenu',
  ]),
  _ReleaseNoteDefinition('2.8.21', ['lazyContent']),
  _ReleaseNoteDefinition('2.8.20', ['supportOgg']),
  _ReleaseNoteDefinition('2.8.18', [
    'cancel5SecondsMovePrev',
    'lyricsCanBeSavedLater',
    'locateMusicBugFix',
  ]),
  _ReleaseNoteDefinition('2.8.15', [
    'loopModeMovePrevNextChange',
    'recentPlayedNotShow',
    'bugFixes',
  ]),
  _ReleaseNoteDefinition('2.8.13', ['addAuthorizeOtherFolder']),
  _ReleaseNoteDefinition('2.8.11', ['bugFixes']),
  _ReleaseNoteDefinition('2.8.8', ['bugFixesMovingFolderNotMovingAllFiles']),
  _ReleaseNoteDefinition('2.8.6', ['bugFixForNowPlayingPlaylist']),
  _ReleaseNoteDefinition('2.8.5', [
    'bugFixForResumeFile',
    'bugFixForSelectingPlayedNowPlayingMusic',
  ]),
  _ReleaseNoteDefinition('2.8.0', [
    'notificationLyricsSource',
    'useHideFolder',
    'bugFixes',
  ]),
  _ReleaseNoteDefinition('2.7.11', ['useFilenameInsteadOfMusicName']),
  _ReleaseNoteDefinition('2.7.6', ['bugFixes']),
  _ReleaseNoteDefinition('2.7.4', ['localPageDisplayWhenHoverButton']),
  _ReleaseNoteDefinition('2.7.3', ['bugFixForLyrics']),
  _ReleaseNoteDefinition('2.7.1', ['bugFixes']),
  _ReleaseNoteDefinition('2.7.0', [
    'updateDialogWithItemClick',
    'fixDuplicateMusicWhenReAdded',
  ]),
  _ReleaseNoteDefinition('2.6.19', ['systemLog']),
  _ReleaseNoteDefinition('2.6.18', ['fixPlaylistControlNoUpdate']),
  _ReleaseNoteDefinition('2.6.17', ['fixSettingsPageCrash']),
  _ReleaseNoteDefinition('2.6.15', [
    'movePreferenceSettings',
    'nowPlayingSupportsMultiSelect',
    'bugFixes',
  ]),
  _ReleaseNoteDefinition('2.6.11', [
    'unableToAddNewMusic',
    'fixFolderSortMakesFolderInvisible',
    'fixSearchCrash',
  ]),
  _ReleaseNoteDefinition('2.6.7', [
    'fixCrashOfRefreshingDirectory',
    'improveLocalPageDropdown',
  ]),
  _ReleaseNoteDefinition('2.6.6', ['bugFixes']),
  _ReleaseNoteDefinition('2.6.1', [
    'fixSearchResultPageSort',
    'fixPreferenceSettingsCrash',
    'supportsOtherMusicFormat',
  ]),
  _ReleaseNoteDefinition('2.6.0', [
    'redesignLocalPagePathBox',
    'adjustAlbumGroupingLogic',
    'incompatibleTile',
    'improvedLocalPageDragAndDrop',
    'updateFolderResult',
  ]),
  _ReleaseNoteDefinition('2.5.8', ['preferenceSettingsDislikedAndDoNotAppear']),
  _ReleaseNoteDefinition('2.5.6', ['fixedPreferenceSettings']),
  _ReleaseNoteDefinition('2.5.5', [
    'improvedLocalManagement',
    'bugFixesForAddingPlaylistWhenNone',
    'importantNoteDataStructureChanged',
  ]),
  _ReleaseNoteDefinition('2.5.2', [
    'voiceAssistantImprovements2',
    'preferenceSettingsPreferenceLevelAdded',
  ]),
  _ReleaseNoteDefinition('2.5.1', [
    'showInExplorerBugFix',
    'settingsCheckBoxChanged',
    'preferenceSettingsAdded',
    'voiceAssistantImprovements',
  ]),
  _ReleaseNoteDefinition('2.5.0', ['voiceAssistant']),
  _ReleaseNoteDefinition('2.4.6', [
    'showLyricsInNotifications',
    'importLyrics',
    'nowPlayingHighlight',
  ]),
  _ReleaseNoteDefinition('2.4.5', [
    'playNext',
    'feedbackViaEmail',
    'bugFixesDragAndDrop',
    'playWithSmplayer',
  ]),
  _ReleaseNoteDefinition('2.4.4', [
    'improveSearchPage',
    'showCount',
    'bugFixes',
  ]),
  _ReleaseNoteDefinition('2.4.3', [
    'introduceReleaseNotes',
    'improveMultiSelect',
    'createNewPlaylistButtonMoved',
    'searchPageAddAllToButton',
    'sortByDateAdded',
    'bugFixes',
  ]),
  _ReleaseNoteDefinition('History Updates', [
    'openWithSmplayer',
    'supportsMultiSelect',
  ]),
];
