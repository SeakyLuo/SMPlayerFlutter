import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

void main() {
  test('evictSmPlayerLocaleAssets clears every locale asset', () {
    final bundle = _RecordingAssetBundle();

    evictSmPlayerLocaleAssets(bundle: bundle);

    expect(bundle.evictedAssetKeys.toSet(), {
      for (final locale in smPlayerSupportedLocaleNames) 'locales/$locale.json',
    });
  });
}

class _RecordingAssetBundle extends CachingAssetBundle {
  final evictedAssetKeys = <String>[];

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }

  @override
  void evict(String key) {
    evictedAssetKeys.add(key);
    super.evict(key);
  }
}
