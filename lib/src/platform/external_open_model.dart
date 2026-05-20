import 'dart:io';

import 'package:path/path.dart' as p;

enum ExternalAppCommandKind {
  playPause,
  next,
  previous,
  stop,
  quickPlay,
  showWindow,
  toggleDesktopLyrics,
}

class ExternalAppCommand {
  const ExternalAppCommand(this.kind);

  final ExternalAppCommandKind kind;
}

const smPlayerAudioExtensions = {
  '.aac',
  '.aiff',
  '.alac',
  '.ape',
  '.flac',
  '.m4a',
  '.mp3',
  '.ogg',
  '.opus',
  '.wav',
  '.wma',
};

List<String> externalAudioPathsFromArgs(List<String> args) {
  return args.where(isExternalAudioPath).toList();
}

bool isExternalAudioPath(String value) {
  return smPlayerAudioExtensions.contains(p.extension(value).toLowerCase()) &&
      File(value).existsSync();
}

List<ExternalAppCommand> externalAppCommandsFromArgs(List<String> args) {
  return args.expand((value) {
    final command = parseExternalAppCommand(value);
    return command == null ? const <ExternalAppCommand>[] : [command];
  }).toList();
}

ExternalAppCommand? parseExternalAppCommand(String rawUrl) {
  if (!rawUrl.startsWith('smplayer:')) {
    return null;
  }

  final uri = Uri.tryParse(rawUrl);
  if (uri == null || uri.scheme != 'smplayer') {
    return null;
  }

  if (uri.host == 'command') {
    return _parseNamedCommand(
      _decodeCommandPath(uri) ?? uri.queryParameters['name'],
    );
  }

  return _parseNamedCommand(
    uri.host.isEmpty ? _decodeCommandPath(uri) : uri.host,
  );
}

String? _decodeCommandPath(Uri uri) {
  final path = uri.path.replaceFirst(RegExp(r'^/+'), '').trim();
  return path.isEmpty ? null : Uri.decodeComponent(path);
}

ExternalAppCommand? _parseNamedCommand(String? command) {
  return switch (command?.trim()) {
    'play-pause' => const ExternalAppCommand(ExternalAppCommandKind.playPause),
    'next' => const ExternalAppCommand(ExternalAppCommandKind.next),
    'previous' => const ExternalAppCommand(ExternalAppCommandKind.previous),
    'stop' => const ExternalAppCommand(ExternalAppCommandKind.stop),
    'quick-play' => const ExternalAppCommand(ExternalAppCommandKind.quickPlay),
    'show-window' => const ExternalAppCommand(
      ExternalAppCommandKind.showWindow,
    ),
    'toggle-desktop-lyrics' => const ExternalAppCommand(
      ExternalAppCommandKind.toggleDesktopLyrics,
    ),
    _ => null,
  };
}
