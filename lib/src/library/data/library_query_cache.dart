import 'package:flutter_riverpod/flutter_riverpod.dart';

final _libraryQueryCacheProvider = Provider((ref) => _LibraryQueryCache());

// Retain successful queries across navigation, with a bounded number of inactive
// views. Active views keep their existing pagination limits. Watched change
// tokens still invalidate retained data; unobserved queries reload on access.
void Function() retainLibraryQuery(Ref ref) {
  final cache = ref.read(_libraryQueryCacheProvider);
  final link = ref.keepAlive();
  final token = Object();
  void release() {
    cache.remove(token);
    link.close();
  }

  ref.onCancel(() => cache.retain(token, link.close));
  ref.onResume(() => cache.remove(token));
  ref.onDispose(() => cache.remove(token));
  return release;
}

class _LibraryQueryCache {
  static const _limit = 24;
  final _inactive = <Object, void Function()>{};

  void retain(Object token, void Function() release) {
    _inactive.remove(token);
    _inactive[token] = release;
    if (_inactive.length > _limit) {
      final oldest = _inactive.keys.first;
      _inactive.remove(oldest)!();
    }
  }

  void remove(Object token) => _inactive.remove(token);
}
