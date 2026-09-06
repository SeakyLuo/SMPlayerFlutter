import 'dart:convert';
import 'dart:io';

// The caller supplies at most 128 paths, keeping process arguments bounded.
Future<List<String>> readFileCreationTimes(List<String> paths) async {
  if (paths.isEmpty) return const [];
  if (Platform.isWindows) {
    final process = await Process.start('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r"$ErrorActionPreference = 'Stop'; "
          r'[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false); '
          r'$paths = ConvertFrom-Json ([Console]::In.ReadToEnd()); '
          r'foreach ($path in $paths) { '
          r"[System.IO.File]::GetCreationTimeUtc($path).ToString('o') }",
    ]);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(jsonEncode(paths));
    await process.stdin.close();
    final exitCode = await process.exitCode;
    final stderr = await errors;
    final stdout = await output;
    if (exitCode != 0) {
      throw ProcessException('powershell.exe', const [], stderr, exitCode);
    }
    return const LineSplitter()
        .convert(stdout)
        .map((value) => DateTime.parse(value).toUtc().toIso8601String())
        .toList();
  }
  if (Platform.isMacOS || Platform.isLinux) {
    final arguments = [
      if (Platform.isMacOS) ...['-f', '%B'] else ...['-c', '%W', '--'],
      ...paths,
    ];
    final result = await Process.run('stat', arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        'stat',
        arguments,
        '${result.stderr}',
        result.exitCode,
      );
    }
    return const LineSplitter().convert('${result.stdout}').indexed.map((
      entry,
    ) {
      final seconds = int.parse(entry.$2);
      if (Platform.isLinux && seconds <= 0) {
        throw FileSystemException(
          'File creation time is unavailable',
          paths[entry.$1],
        );
      }
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ).toIso8601String();
    }).toList();
  }
  return Future.wait(
    paths.map((path) async {
      return (await File(path).stat()).changed.toUtc().toIso8601String();
    }),
  );
}
