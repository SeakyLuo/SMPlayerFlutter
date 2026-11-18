import 'dart:async';

const recentHistoryScope = 'history:recent';
const searchHistoryScope = 'history:search';

final libraryHistoryChanges =
    StreamController<({String device, String scope})>.broadcast();
