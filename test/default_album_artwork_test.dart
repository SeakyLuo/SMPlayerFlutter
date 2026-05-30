import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';

void main() {
  testWidgets('default album artwork uses Electron app icon in night mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [DefaultAlbumArtworkThemeColors.dark],
        ),
        home: const SizedBox.square(
          dimension: 160,
          child: DefaultAlbumArtwork(),
        ),
      ),
    );

    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.map((image) => (image.image as AssetImage).assetName),
      everyElement('assets/branding/app-icon.png'),
    );
  });

  testWidgets('default album artwork keeps Electron app icon in day mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
          extensions: const [DefaultAlbumArtworkThemeColors.light],
        ),
        home: const SizedBox.square(
          dimension: 160,
          child: DefaultAlbumArtwork(),
        ),
      ),
    );

    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.map((image) => (image.image as AssetImage).assetName),
      everyElement('assets/branding/app-icon.png'),
    );
  });
}
