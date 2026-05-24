import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS voice assistant privacy metadata is present', () {
    final infoPlist = File('macos/Runner/Info.plist');
    expect(infoPlist.existsSync(), isTrue);
    expect(
      _readPlistValue(infoPlist.path, 'NSMicrophoneUsageDescription'),
      isNotEmpty,
    );
    expect(
      _readPlistValue(infoPlist.path, 'NSSpeechRecognitionUsageDescription'),
      isNotEmpty,
    );

    for (final path in [
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ]) {
      expect(
        _readPlistValue(
          path,
          'com.apple.security.personal-information.speech-recognition',
        ),
        'true',
      );
    }

    final project = File('macos/Runner.xcodeproj/project.pbxproj');
    expect(project.existsSync(), isTrue);
    final projectText = project.readAsStringSync();
    expect(
      projectText.contains('ENABLE_DEBUG_DYLIB = NO;'),
      isTrue,
      reason:
          'macOS 26 TCC checks the debug dylib as the privacy accessor when '
          'Xcode debug dylib mode is enabled.',
    );
  });
}

String _readPlistValue(String path, String key) {
  final result = Process.runSync('/usr/libexec/PlistBuddy', [
    '-c',
    'Print :$key',
    path,
  ]);
  if (result.exitCode != 0) {
    return '';
  }
  return (result.stdout as String).trim();
}
