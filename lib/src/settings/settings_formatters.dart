String formatSettingsBytes(int size) {
  if (size <= 0) {
    return '0 B';
  }
  if (size < 1024) {
    return '$size B';
  }
  if (size < 1024 * 1024) {
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }
  return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
}
