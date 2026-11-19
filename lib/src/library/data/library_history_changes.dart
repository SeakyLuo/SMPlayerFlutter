import 'dart:async';

const recentHistoryScope = 'history:recent';
const searchHistoryScope = 'history:search';
const playedHistoryScope = 'history:played';
const browsedHistoryScope = 'history:browsed';
const sharedHistoryScopes = {
  recentHistoryScope,
  searchHistoryScope,
  playedHistoryScope,
  browsedHistoryScope,
};

final libraryHistoryChanges =
    StreamController<({String device, String scope})>.broadcast();

void notifyLibraryHistoryChanges(String device, List<String> scopes) {
  final typed = scopes.where(sharedHistoryScopes.contains).toSet();
  if (typed.isEmpty && scopes.contains('history')) {
    typed.addAll([recentHistoryScope, searchHistoryScope]);
  }
  if (typed.contains(playedHistoryScope) ||
      typed.contains(browsedHistoryScope)) {
    typed.remove(recentHistoryScope);
  }
  for (final scope in typed) {
    libraryHistoryChanges.add((device: device, scope: scope));
  }
}
