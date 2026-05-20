const restorableRoutes = {
  '/songs',
  '/artists',
  '/albums',
  '/now-playing',
  '/recent',
  '/local',
  '/playlists',
  '/favorites',
};

String resolveRestoredPage(String lastPage) {
  final normalizedPath = lastPage.trim();
  return restorableRoutes.contains(normalizedPath) ? normalizedPath : '/songs';
}
