part of 'desktop_feature_service.dart';

String desktopNotificationArtist(LibrarySong song, SmPlayerI18n i18n) {
  return displayArtists(song, i18n);
}

String desktopNotificationAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return displayAlbum(song, i18n);
}

String desktopNotificationBody(TrackNotificationPayload payload) {
  final lyricsPreview = payload.lyricsPreview.trim();
  if (lyricsPreview.isNotEmpty) {
    return lyricsPreview;
  }
  final body = [
    payload.artist,
    payload.album,
  ].where((value) => value.isNotEmpty).join(' - ');
  return body.isEmpty ? 'Simple Melody Player' : body;
}

String windowsToastPowerShellCommand(
  TrackNotificationPayload payload,
  String body,
) {
  final title = _powerShellString(payload.title);
  final message = _powerShellString(body);
  final appId = _powerShellString(windowsAppUserModelId);
  final activationUri = _powerShellString(windowsToastActivationUri);
  final silentAudio =
      payload.silent
          ? r'''
$audio = $xml.CreateElement('audio')
$audio.SetAttribute('silent', 'true')
$xml.DocumentElement.AppendChild($audio) | Out-Null
'''
          : '';
  return '''
\$template = [Windows.UI.Notifications.ToastTemplateType]::ToastText02
\$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(\$template)
\$xml.DocumentElement.SetAttribute('launch', $activationUri)
\$textNodes = \$xml.GetElementsByTagName('text')
\$textNodes.Item(0).AppendChild(\$xml.CreateTextNode($title)) | Out-Null
\$textNodes.Item(1).AppendChild(\$xml.CreateTextNode($message)) | Out-Null
$silentAudio\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show(\$toast)
''';
}

String desktopNotificationLyricsPreview({
  required LyricsSnapshot lyrics,
  required LibrarySong song,
  required double progressSeconds,
}) {
  if (lyrics.lines.isEmpty) {
    return '';
  }
  if (!lyrics.isSynced) {
    return lyrics.lines.first.text.trim();
  }
  final index = currentDesktopLyricIndex(
    lyrics,
    progressSeconds,
    song.lyricsOffsetMs,
  );
  if (index < 0 || index >= lyrics.lines.length) {
    return '';
  }
  return lyrics.lines[index].text.trim();
}

String desktopRecentSongTitle(DesktopRecentSong song) {
  if (song.title.isNotEmpty) {
    return song.title;
  }
  return path.basename(song.path);
}

DesktopFeatureCommand desktopFeatureCommandFromPlatform(String command) {
  return switch (command) {
    'play' => DesktopFeatureCommand.play,
    'pause' => DesktopFeatureCommand.pause,
    'play-pause' => DesktopFeatureCommand.playPause,
    'previous' => DesktopFeatureCommand.previous,
    'next' => DesktopFeatureCommand.next,
    'stop' => DesktopFeatureCommand.stop,
    'quick-play' => DesktopFeatureCommand.quickPlay,
    'show-window' => DesktopFeatureCommand.showWindow,
    'toggle-desktop-lyrics' => DesktopFeatureCommand.toggleDesktopLyrics,
    'disable' ||
    'desktop-lyrics-disable' => DesktopFeatureCommand.disableDesktopLyrics,
    'toggle-lock' || 'desktop-lyrics-toggle-lock' =>
      DesktopFeatureCommand.toggleDesktopLyricsLock,
    'offset:-100' || 'desktop-lyrics-offset-backward' =>
      DesktopFeatureCommand.desktopLyricsOffsetBackward,
    'offset:100' || 'desktop-lyrics-offset-forward' =>
      DesktopFeatureCommand.desktopLyricsOffsetForward,
    'reset-offset' || 'desktop-lyrics-reset-offset' =>
      DesktopFeatureCommand.resetDesktopLyricsOffset,
    'open-settings' => DesktopFeatureCommand.openSettings,
    _ => throw ArgumentError.value(command, 'command'),
  };
}

DesktopFeatureCommand _desktopFeatureCommandFromPlatform(String command) {
  return desktopFeatureCommandFromPlatform(command);
}

DesktopFeatureAction _desktopFeatureActionFromExternal(
  ExternalAppCommand command,
) {
  if (command.kind == ExternalAppCommandKind.voiceCommand) {
    return DesktopFeatureAction(
      DesktopFeatureCommand.voiceCommand,
      voiceCommandText: command.text,
    );
  }
  return DesktopFeatureAction(switch (command.kind) {
    ExternalAppCommandKind.playPause => DesktopFeatureCommand.playPause,
    ExternalAppCommandKind.next => DesktopFeatureCommand.next,
    ExternalAppCommandKind.previous => DesktopFeatureCommand.previous,
    ExternalAppCommandKind.stop => DesktopFeatureCommand.stop,
    ExternalAppCommandKind.quickPlay => DesktopFeatureCommand.quickPlay,
    ExternalAppCommandKind.showWindow => DesktopFeatureCommand.showWindow,
    ExternalAppCommandKind.toggleDesktopLyrics =>
      DesktopFeatureCommand.toggleDesktopLyrics,
    ExternalAppCommandKind.voiceCommand => DesktopFeatureCommand.voiceCommand,
  });
}
