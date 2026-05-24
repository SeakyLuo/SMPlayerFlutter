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
      expect(_readPlistValue(path, 'com.apple.security.app-sandbox'), 'true');
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

  test('macOS external audio opens keep sandboxed file access', () {
    final appDelegate = File('macos/Runner/AppDelegate.swift');
    final mainWindow = File('macos/Runner/MainFlutterWindow.swift');
    expect(appDelegate.existsSync(), isTrue);
    expect(mainWindow.existsSync(), isTrue);

    final appDelegateText = appDelegate.readAsStringSync();
    expect(
      appDelegateText,
      contains('securityScopedExternalFileBookmarks'),
    );
    expect(
      appDelegateText,
      contains('url.startAccessingSecurityScopedResource()'),
    );
    expect(
      appDelegateText,
      contains(
        'override func application(_ sender: NSApplication, openFiles filenames: [String])',
      ),
    );
    expect(
      appDelegateText,
      contains('SmPlayerExternalFileAccessStore.shared.storeAccess('),
    );

    final mainWindowText = mainWindow.readAsStringSync();
    expect(
      mainWindowText,
      contains('SmPlayerExternalFileAccessStore.shared.restoreAccess()'),
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
