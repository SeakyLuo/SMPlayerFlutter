import 'local_folder_model.dart';

String getUpdateResultRelativeFileTitle(String filePath, String folderPath) {
  return getUpdateResultFileTitle(filePath, folderPath);
}

String getUpdateResultFileTitle(String filePath, String folderPath) {
  final normalizedFilePath = normalizePath(filePath);
  final normalizedFolderPath = normalizePath(folderPath);
  final filePathKey = normalizedFilePath.toLowerCase();
  final folderPathKey = normalizedFolderPath.toLowerCase();
  final relativePath =
      filePathKey.startsWith('$folderPathKey/')
          ? normalizedFilePath.substring(normalizedFolderPath.length + 1)
          : normalizedFilePath;
  final extensionIndex = relativePath.lastIndexOf('.');
  return extensionIndex > 0
      ? relativePath.substring(0, extensionIndex)
      : relativePath;
}

List<({String path, String title})> getUpdateResultFileItems(
  List<String> filePaths,
  String folderPath,
) {
  final items = [
    for (final filePath in filePaths)
      (path: filePath, title: getUpdateResultFileTitle(filePath, folderPath)),
  ];
  final titleCounts = <String, int>{};
  for (final item in items) {
    titleCounts[item.title] = (titleCounts[item.title] ?? 0) + 1;
  }
  return [
    for (final item in items)
      (
        path: item.path,
        title: titleCounts[item.title]! > 1 ? item.path : item.title,
      ),
  ];
}
