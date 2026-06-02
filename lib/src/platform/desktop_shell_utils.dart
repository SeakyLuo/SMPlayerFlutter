part of 'desktop_feature_service.dart';

Future<String?> pickDesktopColor(String value) async {
  if (kIsWeb) {
    return null;
  }
  if (Platform.isMacOS) {
    return _pickMacOsColor(value);
  }
  if (Platform.isWindows) {
    return _pickWindowsColor(value);
  }
  if (Platform.isLinux) {
    return _pickLinuxColor(value);
  }
  return null;
}

Future<String?> pickDirectoryFromDesktopShell({
  String? title,
  String? buttonLabel,
  String? defaultPath,
  String? locale,
}) {
  final arguments = <String, String>{};
  if (title != null) {
    arguments['title'] = title;
  }
  if (buttonLabel != null) {
    arguments['buttonLabel'] = buttonLabel;
  }
  if (defaultPath != null) {
    arguments['defaultPath'] = defaultPath;
  }
  if (locale != null) {
    arguments['locale'] = locale;
  }
  return _desktopFeatureChannel.invokeMethod<String>(
    'pickDirectory',
    arguments,
  );
}

Future<void> dismissNativeSplash() async {
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows)) {
    await _desktopFeatureChannel.invokeMethod<void>('dismissNativeSplash');
  }
}

Future<String?> _pickMacOsColor(String value) async {
  final rgb = _hexColorToAppleScriptRgb(value);
  if (rgb == null) {
    return null;
  }
  final result = await Process.run('osascript', [
    '-e',
    'choose color default color {${rgb.$1}, ${rgb.$2}, ${rgb.$3}}',
  ]);
  if (result.exitCode != 0) {
    return null;
  }
  final components = '${result.stdout}'
      .trim()
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .toList(growable: false);
  if (components.length < 3 ||
      components[0] == null ||
      components[1] == null ||
      components[2] == null) {
    return null;
  }
  return _appleScriptRgbToHex(components[0]!, components[1]!, components[2]!);
}

Future<String?> _pickWindowsColor(String value) async {
  final rgb = _hexColorToRgb(value);
  if (rgb == null) {
    return null;
  }
  try {
    final result = await Process.run('powershell.exe', [
      '-Sta',
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
\$dialog = New-Object System.Windows.Forms.ColorDialog
\$dialog.FullOpen = \$true
\$dialog.Color = [System.Drawing.Color]::FromArgb(${rgb.$1}, ${rgb.$2}, ${rgb.$3})
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  '#{0:X2}{1:X2}{2:X2}' -f \$dialog.Color.R, \$dialog.Color.G, \$dialog.Color.B
  exit 0
}
exit 1
''',
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    return _desktopColorSelectionToHex('${result.stdout}');
  } on Object {
    return null;
  }
}

Future<String?> _pickLinuxColor(String value) async {
  final hex = _normalizeHexColor(value);
  if (hex == null) {
    return null;
  }
  try {
    final result = await Process.run('sh', [
      '-lc',
      r'''
if command -v zenity >/dev/null 2>&1; then
  zenity --color-selection --color="$1"
elif command -v kdialog >/dev/null 2>&1; then
  kdialog --getcolor "$1"
else
  exit 127
fi
''',
      'smplayer-color-picker',
      hex,
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    return _desktopColorSelectionToHex('${result.stdout}');
  } on Object {
    return null;
  }
}

(int, int, int)? _hexColorToRgb(String value) {
  final hex = _normalizeHexColor(value);
  if (hex == null) {
    return null;
  }
  final digits = hex.substring(1);
  return (
    int.parse(digits.substring(0, 2), radix: 16),
    int.parse(digits.substring(2, 4), radix: 16),
    int.parse(digits.substring(4, 6), radix: 16),
  );
}

(int, int, int)? _hexColorToAppleScriptRgb(String value) {
  final rgb = _hexColorToRgb(value);
  if (rgb == null) {
    return null;
  }
  return (rgb.$1 * 257, rgb.$2 * 257, rgb.$3 * 257);
}

String? _normalizeHexColor(String value) {
  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  return '#${match.group(1)!.toLowerCase()}';
}

String? _desktopColorSelectionToHex(String value) {
  final raw = value.trim();
  final hex = _normalizeHexColor(raw);
  if (hex != null) {
    return hex;
  }
  final rgb = RegExp(
    r'^rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*[^)]*)?\)$',
  ).firstMatch(raw);
  if (rgb == null) {
    return null;
  }
  String component(int index) {
    return int.parse(
      rgb.group(index)!,
    ).clamp(0, 255).toRadixString(16).padLeft(2, '0');
  }

  return '#${component(1)}${component(2)}${component(3)}';
}

String _appleScriptRgbToHex(int red, int green, int blue) {
  String component(int value) {
    return (value / 257)
        .round()
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
  }

  return '#${component(red)}${component(green)}${component(blue)}';
}

int clampedDesktopLyricsOffset(int offsetMs) {
  return offsetMs.clamp(desktopLyricsOffsetMinMs, desktopLyricsOffsetMaxMs);
}

class ShellProcessCommand {
  const ShellProcessCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}

Future<void> revealItemInFolder(String targetPath) async {
  final targetType = await FileSystemEntity.type(targetPath);
  if (targetType == FileSystemEntityType.notFound) {
    return;
  }
  final command = revealItemInFolderCommand(
    targetPath,
    operatingSystem: Platform.operatingSystem,
  );
  await Process.start(command.executable, command.arguments);
}

Future<void> openFolderInShell(String folderPath) async {
  final command = openFolderInShellCommand(
    folderPath,
    operatingSystem: Platform.operatingSystem,
  );
  await Process.start(command.executable, command.arguments);
}

ShellProcessCommand revealItemInFolderCommand(
  String targetPath, {
  required String operatingSystem,
}) {
  return switch (operatingSystem) {
    'windows' => ShellProcessCommand('explorer.exe', ['/select,$targetPath']),
    'macos' => ShellProcessCommand('open', ['-R', targetPath]),
    _ => ShellProcessCommand('xdg-open', [path.dirname(targetPath)]),
  };
}

ShellProcessCommand openFolderInShellCommand(
  String folderPath, {
  required String operatingSystem,
}) {
  return switch (operatingSystem) {
    'windows' => ShellProcessCommand('explorer.exe', [folderPath]),
    'macos' => ShellProcessCommand('open', [folderPath]),
    _ => ShellProcessCommand('xdg-open', [folderPath]),
  };
}

Rect _workAreaForDisplay(screen.Display display) {
  final visiblePosition = display.visiblePosition ?? Offset.zero;
  final visibleSize = display.visibleSize ?? display.size;
  return Rect.fromLTWH(
    visiblePosition.dx,
    visiblePosition.dy,
    visibleSize.width,
    visibleSize.height,
  );
}

double _rectOverlapArea(Rect left, Rect right) {
  final overlapWidth = max(
    0,
    min(left.right, right.right) - max(left.left, right.left),
  );
  final overlapHeight = max(
    0,
    min(left.bottom, right.bottom) - max(left.top, right.top),
  );
  return (overlapWidth * overlapHeight).toDouble();
}

Future<List<String>> loadDesktopSystemFonts() async {
  if (kIsWeb) {
    return const [];
  }
  if (Platform.isWindows) {
    return _readWindowsSystemFonts();
  }
  if (Platform.isMacOS) {
    return _readMacSystemFonts();
  }
  if (Platform.isLinux) {
    return _readLinuxSystemFonts();
  }
  return const [];
}

Future<List<String>> _readWindowsSystemFonts() async {
  try {
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      r'''
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$fontNames = foreach ($key in @(
  'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
  'Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
)) {
  if (Test-Path -LiteralPath $key) {
    (Get-ItemProperty -LiteralPath $key).PSObject.Properties |
      Where-Object { $_.MemberType -eq 'NoteProperty' -and $_.Name -notlike 'PS*' } |
      ForEach-Object { $_.Name }
  }
}
$fontNames | Sort-Object -Unique | ConvertTo-Json -Compress
''',
    ]);
    if (result.exitCode != 0) {
      return const [];
    }
    return systemFontFamiliesFromRawNames(_jsonStringArray('${result.stdout}'));
  } on Object {
    return const [];
  }
}

Future<List<String>> _readMacSystemFonts() async {
  try {
    final result = await Process.run('system_profiler', [
      'SPFontsDataType',
      '-json',
    ]);
    if (result.exitCode != 0) {
      return const [];
    }
    final decoded = jsonDecode('${result.stdout}') as Map<String, dynamic>;
    final fonts =
        (decoded['SPFontsDataType'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>();
    final names = <String>[];
    for (final font in fonts) {
      final name = font['_name'];
      if (name is String) {
        names.add(name);
      }
      final typefaces = font['typefaces'];
      if (typefaces is List) {
        names.addAll(
          typefaces
              .whereType<Map<String, dynamic>>()
              .map((typeface) => typeface['_name'])
              .whereType<String>(),
        );
      }
    }
    return systemFontFamiliesFromRawNames(names);
  } on Object {
    return const [];
  }
}

Future<List<String>> _readLinuxSystemFonts() async {
  try {
    final result = await Process.run('fc-list', [':', 'family']);
    if (result.exitCode != 0) {
      return const [];
    }
    return systemFontFamiliesFromRawNames(
      '${result.stdout}'
          .split(RegExp(r'\r?\n'))
          .expand((line) => line.split(','))
          .map((name) => name.trim()),
    );
  } on Object {
    return const [];
  }
}

List<String> _jsonStringArray(String raw) {
  final decoded = jsonDecode(raw.isEmpty ? '[]' : raw) as Object;
  return switch (decoded) {
    String value => [value],
    List<dynamic> values => values.whereType<String>().toList(),
    _ => const [],
  };
}

List<String> systemFontFamiliesFromRawNames(Iterable<String> fontNames) {
  final fontFamilies = <String>{};
  for (final fontName in fontNames) {
    fontFamilies.addAll(systemFontFamilyNames(fontName));
  }
  final sorted =
      fontFamilies
          .where((font) => font.isNotEmpty && !font.startsWith('.'))
          .toList();
  sorted.sort(
    (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
  );
  return sorted;
}

List<String> systemFontFamilyNames(String fontName) {
  final familyName =
      fontName.replaceFirst(RegExp(r'\s+\([^)]*\)\s*$'), '').trim();
  return familyName
      .split(RegExp(r'\s*&\s*'))
      .map(
        (name) =>
            name
                .replaceFirst(
                  RegExp(
                    r'\s+(Bold Italic|Light Italic|Medium Italic|SemiBold Italic|Black Italic|Thin|ExtraLight|UltraLight|Light|SemiLight|Regular|Medium|SemiBold|DemiBold|Bold|ExtraBold|UltraBold|Black|Heavy|Italic|Oblique)$',
                    caseSensitive: false,
                  ),
                  '',
                )
                .trim(),
      )
      .toList();
}

String _powerShellString(String value) {
  return "'${value.replaceAll("'", "''")}'";
}
