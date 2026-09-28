part of 'desktop_feature_service.dart';

String desktopNotificationArtist(LibrarySong song, SmPlayerI18n i18n) {
  return displayArtists(song, i18n);
}

String desktopNotificationAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return displayAlbum(song, i18n);
}

String desktopNotificationBody(TrackNotificationPayload payload) {
  final metadata = desktopNotificationMetadata(payload);
  return metadata.isEmpty ? 'Simple Melody Player' : metadata;
}

String desktopNotificationMetadata(TrackNotificationPayload payload) {
  return [
    payload.artist,
    payload.album,
  ].where((value) => value.isNotEmpty).join(' - ');
}

String windowsToastPowerShellCommand(TrackNotificationPayload payload) {
  final title = _powerShellString(payload.title);
  final metadata = _powerShellString(desktopNotificationMetadata(payload));
  final appId = _powerShellString(windowsAppUserModelId);
  final activationUri = _powerShellString(windowsToastActivationUri);
  final artwork =
      payload.artworkPath.isEmpty
          ? ''
          : '''
\$image = \$xml.CreateElement('image')
\$image.SetAttribute('placement', 'appLogoOverride')
\$image.SetAttribute('src', ${_powerShellString(Uri.file(payload.artworkPath, windows: true).toString())})
\$binding.AppendChild(\$image) | Out-Null
''';
  final silentAudio =
      payload.silent
          ? r'''
$audio = $xml.CreateElement('audio')
$audio.SetAttribute('silent', 'true')
$xml.DocumentElement.AppendChild($audio) | Out-Null
'''
          : '';
  return '''
\$ErrorActionPreference = 'Stop'
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
\$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
\$xml.LoadXml('<toast><visual><binding template="ToastGeneric"></binding></visual></toast>')
\$xml.DocumentElement.SetAttribute('launch', $activationUri)
\$xml.DocumentElement.SetAttribute('activationType', 'protocol')
\$binding = \$xml.GetElementsByTagName('binding').Item(0)
foreach (\$value in @($title, $metadata)) {
  if (![string]::IsNullOrEmpty(\$value)) {
    \$text = \$xml.CreateElement('text')
    \$text.AppendChild(\$xml.CreateTextNode(\$value)) | Out-Null
    \$binding.AppendChild(\$text) | Out-Null
  }
}
$artwork$silentAudio\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show(\$toast)
''';
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
