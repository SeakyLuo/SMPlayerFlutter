import 'dart:convert';
import 'dart:io';

// The caller supplies at most 128 paths, keeping process arguments bounded.
Future<List<String>> readFileCreationTimes(
  List<String> paths,
  List<FileStat> stats,
) async {
  if (paths.isEmpty) return const [];
  if (Platform.isWindows) {
    // FileStat.changed is the creation time on Windows.
    return [for (final stat in stats) stat.changed.toUtc().toIso8601String()];
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
