import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_overlay_glass.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';

void main() {
  testWidgets('PlaylistControlItem opens shared swipe remove action', (
    tester,
  ) async {
    var removed = false;
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: PlaylistControlItem(
                song: _song,
                current: true,
                playing: false,
                selected: false,
                selectionMode: false,
                removeLabel: 'Remove',
                onPlayTrack: () {},
                onTogglePlayPause: () {},
                onToggleSelection: () {},
                onOpenContextMenu: _noopPosition,
                onPlayNextClick: () {},
                onRemoveFromListClick: () {
                  removed = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PlaylistControlItem)),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-50, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byType(PlaylistControlItem)) + const Offset(126, 0),
    );
    await tester.pump();

    expect(removed, isTrue);
  });

  testWidgets('PlaylistControlItem shows Electron drop indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              child: PlaylistControlItem(
                song: _song,
                current: false,
                playing: false,
                selected: false,
                selectionMode: false,
                dropPosition: PlaylistControlDropPosition.before,
                onPlayTrack: _noop,
                onTogglePlayPause: _noop,
                onToggleSelection: _noop,
                onOpenContextMenu: _noopPosition,
                onPlayNextClick: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('PlaylistControlItem.DropIndicator')),
      findsOneWidget,
    );
  });

  testWidgets('PlaylistControlItem play next action uses Electron icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              child: PlaylistControlItem(
                song: _song,
                current: false,
                playing: false,
                selected: false,
                selectionMode: false,
                onPlayTrack: _noop,
                onTogglePlayPause: _noop,
                onToggleSelection: _noop,
                onOpenContextMenu: _noopPosition,
                onPlayNextClick: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    final action = find.byKey(
      const ValueKey('PlaylistControlItem.PlayNextAction'),
    );

    expect(action, findsOneWidget);
    expect(
      find.descendant(of: action, matching: find.byType(SmPlayerPlayNextIcon)),
      findsOneWidget,
    );
  });

  testWidgets(
    'PlaylistControlItem keeps Electron required More action and optional Play Next',
    (tester) async {
      var menuOpened = false;
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: PlaylistControlItem(
                  song: _song,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  moreLabel: 'More',
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: (_) {
                    menuOpened = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('PlaylistControlItem.PlayNextAction')),
        findsNothing,
      );
      final moreAction = find.byKey(
        const ValueKey('PlaylistControlItem.MoreAction'),
      );
      expect(moreAction, findsOneWidget);

      await tester.tap(moreAction);
      await tester.pump();

      expect(menuOpened, isTrue);
    },
  );

  testWidgets(
    'PlaylistControlItem does not render static favorite without Electron callback',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 720,
                child: PlaylistControlItem(
                  song: _favoriteSong,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('PlaylistControlItem.FavoriteAction')),
        findsNothing,
      );
      expect(find.byIcon(FluentIcons.heart_20_filled), findsNothing);
    },
  );

  testWidgets('PlaylistControlItem activates with keyboard like Electron', (
    tester,
  ) async {
    var playCount = 0;
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: PlaylistControlItem(
                song: _song,
                current: false,
                playing: false,
                selected: false,
                selectionMode: false,
                onPlayTrack: () {
                  playCount += 1;
                },
                onTogglePlayPause: _noop,
                onToggleSelection: _noop,
                onOpenContextMenu: _noopPosition,
                onPlayNextClick: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PlaylistControlItem));
    await tester.pump();
    playCount = 0;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(playCount, 1);
  });

  testWidgets(
    'PlaylistControlItem animates current playing wave like Electron',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 360,
                child: PlaylistControlItem(
                  song: _song,
                  current: true,
                  playing: true,
                  selected: false,
                  selectionMode: false,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('PlaylistControlItem.Playing.Wave')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('PlaylistControlItem.Playing.Backdrop')),
        findsOneWidget,
      );
      final waveGlass = tester.widget<GlassContainer>(
        find.byKey(const ValueKey('PlaylistControlItem.Playing.Backdrop')),
      );
      expect(waveGlass.settings?.glassColor, artworkOverlayGlassColor);
      expect(waveGlass.settings?.blur, 54);
      expect(waveGlass.settings?.saturation, 1.72);
      expect(waveGlass.settings?.glowIntensity, 0.22);
      expect(
        waveGlass.settings?.standardOpacityMultiplier,
        artworkOverlayGlassOpacityMultiplier,
      );

      final firstHeight = _playingBarHeight(tester, 0);
      await tester.pump(const Duration(milliseconds: 390));

      expect(_playingBarHeight(tester, 0), isNot(firstHeight));
    },
  );

  testWidgets(
    'PlaylistControlItem keeps current playing wave mounted under hover button',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 360,
                child: PlaylistControlItem(
                  song: _song,
                  current: true,
                  playing: true,
                  selected: false,
                  selectionMode: false,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byType(PlaylistControlItem)),
      );
      addTearDown(mouse.removePointer);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('PlaylistControlItem.Playing.Wave')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('PlaylistControlItem.PlayOverlayButton')),
        findsOneWidget,
      );
    },
  );

  testWidgets('PlaylistControlItem keeps current paused wave static', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              child: PlaylistControlItem(
                song: _song,
                current: true,
                playing: false,
                selected: false,
                selectionMode: false,
                onPlayTrack: _noop,
                onTogglePlayPause: _noop,
                onToggleSelection: _noop,
                onOpenContextMenu: _noopPosition,
                onPlayNextClick: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    expect(_playingBarHeight(tester, 0), 7);
    expect(_playingBarHeight(tester, 1), 12);
    expect(_playingBarHeight(tester, 2), 15);
    expect(_playingBarHeight(tester, 3), 9);

    await tester.pump(const Duration(milliseconds: 390));

    expect(_playingBarHeight(tester, 0), 7);
    expect(_playingBarHeight(tester, 1), 12);
    expect(_playingBarHeight(tester, 2), 15);
    expect(_playingBarHeight(tester, 3), 9);
  });

  testWidgets(
    'PlaylistControlItem wide compact duration mirrors Electron width',
    (tester) async {
      tester.view.physicalSize = const Size(1300, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 1200,
                child: PlaylistControlItem(
                  song: _threeFortySevenSong,
                  current: true,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  variant: PlaylistControlItemVariant.compact,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('PlaylistControlItem.Duration')))
            .width,
        50,
      );
      expect(tester.getSize(find.text('3:47')).height, lessThan(24));
      expect(tester.widget<Text>(find.text('3:47')).style?.fontSize, 14);
    },
  );

  testWidgets(
    'PlaylistControlItem narrow compact duration mirrors Electron width',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 360,
                child: PlaylistControlItem(
                  song: _threeFortySevenSong,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  variant: PlaylistControlItemVariant.compact,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('PlaylistControlItem.Duration')))
            .width,
        20,
      );
      expect(tester.getSize(find.text('3:47')).height, lessThan(24));
      expect(tester.widget<Text>(find.text('3:47')).style?.fontSize, 14);
    },
  );

  testWidgets(
    'PlaylistControlItem explicit narrow duration stays on one line',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 360,
                child: PlaylistControlItem(
                  song: _threeFortySevenSong,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  variant: PlaylistControlItemVariant.compact,
                  compactDurationWidth: 20,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('PlaylistControlItem.Duration')))
            .width,
        20,
      );
      expect(tester.getSize(find.text('3:47')).height, lessThan(24));
    },
  );

  testWidgets(
    'PlaylistControlItem headered narrow duration mirrors Electron container query',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 1100,
                child: PlaylistControlItem(
                  song: _threeFortySevenSong,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  showAlbum: true,
                  variant: PlaylistControlItemVariant.headeredPlaylist,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('PlaylistControlItem.Duration')))
            .width,
        20,
      );
      expect(tester.getSize(find.text('3:47')).height, lessThan(24));
    },
  );

  testWidgets(
    'PlaylistControlItem headered wide duration keeps Electron desktop width',
    (tester) async {
      tester.view.physicalSize = const Size(1300, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 1200,
                child: PlaylistControlItem(
                  song: _threeFortySevenSong,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  showAlbum: true,
                  variant: PlaylistControlItemVariant.headeredPlaylist,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('PlaylistControlItem.Duration')))
            .width,
        74,
      );
    },
  );

  testWidgets(
    'PlaylistControlItem standard narrow duration mirrors Electron container query',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 760,
                child: PlaylistControlItem(
                  song: _threeFortySevenSong,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('PlaylistControlItem.Duration')))
            .width,
        20,
      );
      expect(tester.getSize(find.text('3:47')).height, lessThan(24));
      expect(tester.widget<Text>(find.text('3:47')).style?.fontSize, 13);
    },
  );

  testWidgets(
    'PlaylistControlItem standard wide duration keeps Electron desktop width',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 900,
                child: PlaylistControlItem(
                  song: _threeFortySevenSong,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('PlaylistControlItem.Duration')))
            .width,
        74,
      );
    },
  );

  testWidgets('PlaylistControlItem compact actions follow Electron width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 1200,
              child: PlaylistControlItem(
                song: _song,
                current: false,
                playing: false,
                selected: false,
                selectionMode: false,
                variant: PlaylistControlItemVariant.compact,
                onPlayTrack: _noop,
                onTogglePlayPause: _noop,
                onToggleSelection: _noop,
                onOpenContextMenu: _noopPosition,
                onPlayNextClick: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey('PlaylistControlItem.Actions')))
          .width,
      76,
    );
  });

  testWidgets('PlaylistControlItem compact actions center in Electron column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 1200,
              child: PlaylistControlItem(
                song: _song,
                current: false,
                playing: false,
                selected: false,
                selectionMode: false,
                variant: PlaylistControlItemVariant.compact,
                moreLabel: 'More',
                onOpenContextMenu: _noopPosition,
                onPlayTrack: _noop,
                onTogglePlayPause: _noop,
                onToggleSelection: _noop,
                onPlayNextClick: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    final actionsRect = tester.getRect(
      find.byKey(const ValueKey('PlaylistControlItem.Actions')),
    );
    final playNextRect = tester.getRect(
      find.byKey(const ValueKey('PlaylistControlItem.PlayNextAction')),
    );
    final moreRect = tester.getRect(
      find.byKey(const ValueKey('PlaylistControlItem.MoreAction')),
    );

    expect(playNextRect.left - actionsRect.left, 4);
    expect(actionsRect.right - moreRect.right, 4);
  });

  testWidgets(
    'PlaylistControlItem narrow compact actions collapse like Electron',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 360,
                child: PlaylistControlItem(
                  song: _song,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  variant: PlaylistControlItemVariant.compact,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('PlaylistControlItem.Actions')))
            .width,
        34,
      );
    },
  );

  testWidgets(
    'PlaylistControlItem action buttons mirror Electron hover style',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 720,
                child: PlaylistControlItem(
                  song: _song,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  addToPlaylistLabel: 'Add',
                  moreLabel: 'More',
                  onAddToPlaylistClick: _noopContext,
                  onOpenContextMenu: _noopPosition,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onPlayNextClick: _noop,
                  onRemoveFromListClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      final playNext = find.byKey(
        const ValueKey('PlaylistControlItem.PlayNextAction'),
      );
      final addTo = find.byKey(
        const ValueKey('PlaylistControlItem.AddToAction'),
      );
      final remove = find.byKey(
        const ValueKey('PlaylistControlItem.RemoveAction'),
      );
      expect(tester.getSize(playNext), const Size.square(32));
      expect(tester.getSize(addTo), const Size.square(32));
      expect(tester.getRect(playNext).left - tester.getRect(addTo).right, 8);
      expect(tester.getRect(remove).left - tester.getRect(playNext).right, 8);
      var slide = tester.widget<AnimatedSlide>(
        find.descendant(of: playNext, matching: find.byType(AnimatedSlide)),
      );
      var container = tester.widget<AnimatedContainer>(
        find.descendant(of: playNext, matching: find.byType(AnimatedContainer)),
      );
      expect(slide.offset, Offset.zero);
      expect((container.decoration! as BoxDecoration).borderRadius, isNotNull);
      expect(
        (container.decoration! as BoxDecoration).color,
        Colors.transparent,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(playNext));
      addTearDown(mouse.removePointer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      slide = tester.widget<AnimatedSlide>(
        find.descendant(of: playNext, matching: find.byType(AnimatedSlide)),
      );
      container = tester.widget<AnimatedContainer>(
        find.descendant(of: playNext, matching: find.byType(AnimatedContainer)),
      );
      expect(slide.offset, const Offset(0, -1 / 32));
      expect(
        (container.decoration! as BoxDecoration).color,
        const Color(0x9effffff),
      );
    },
  );

  testWidgets(
    'PlaylistControlItem multi-select selected row uses hover color',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 720,
                child: PlaylistControlItem(
                  song: _song,
                  current: true,
                  playing: false,
                  selected: true,
                  selectionMode: true,
                  addToPlaylistLabel: 'Add',
                  moreLabel: 'More',
                  onAddToPlaylistClick: _noopContext,
                  onOpenContextMenu: _noopPosition,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onPlayNextClick: _noop,
                  onRemoveFromListClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      final rowContainer = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(PlaylistControlItem),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final decoration = rowContainer.decoration! as BoxDecoration;
      expect(decoration.color, GlobalUI.hoverBgColorDay);
      expect(
        decoration.boxShadow?.where(
          (shadow) => shadow.color == const Color(0xff0078d7),
        ),
        isEmpty,
      );
    },
  );

  testWidgets('PlaylistControlItem default colors follow Electron night mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            extensions: const [DefaultAlbumArtworkThemeColors.dark],
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 720,
              child: PlaylistControlItem(
                song: _song,
                current: true,
                playing: false,
                selected: false,
                selectionMode: false,
                playNextLabel: 'Play Next',
                onPlayTrack: _noop,
                onTogglePlayPause: _noop,
                onToggleSelection: _noop,
                onOpenContextMenu: _noopPosition,
                onPlayNextClick: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    final rowContainer = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    final rowDecoration = rowContainer.decoration! as BoxDecoration;
    final title = tester.widget<Text>(
      find.byKey(const ValueKey('PlaylistControlItem.Title')),
    );
    final artist = tester.widget<Text>(find.text('Artist').first);
    final actionIconTheme = tester.widget<IconTheme>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey('PlaylistControlItem.PlayNextAction'),
            ),
            matching: find.byType(IconTheme),
          )
          .last,
    );

    expect(rowDecoration.color, const Color(0x2e0078d7));
    expect(title.style?.color, const Color(0xff459de2));
    expect(artist.style?.color, const Color(0xc276b5dc));
    expect(actionIconTheme.data.color, const Color(0xadcbd5e1));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(PlaylistControlItem)),
    );
    addTearDown(mouse.removePointer);
    await tester.pump();

    final hoveredDecoration =
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
                .decoration!
            as BoxDecoration;
    expect(hoveredDecoration.color, const Color(0x2e0078d7));
  });

  testWidgets(
    'PlaylistControlItem current row keeps Electron current background on hover handoff',
    (tester) async {
      const secondSong = LibrarySong(
        id: 2,
        path: '/music/song-2.mp3',
        title: 'Acid Jazz 3',
        artist: 'Unknown Artist',
        artists: ['Unknown Artist'],
        album: 'Unknown Album',
        duration: 180,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-25',
        favorite: false,
        thumbnailPath: '',
      );
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 720,
                child: Column(
                  children: [
                    PlaylistControlItem(
                      song: _song,
                      current: true,
                      playing: false,
                      selected: false,
                      selectionMode: false,
                      onOpenContextMenu: _noopPosition,
                      onPlayTrack: _noop,
                      onTogglePlayPause: _noop,
                      onToggleSelection: _noop,
                    ),
                    PlaylistControlItem(
                      song: secondSong,
                      current: false,
                      playing: false,
                      selected: false,
                      selectionMode: false,
                      onOpenContextMenu: _noopPosition,
                      onPlayTrack: _noop,
                      onTogglePlayPause: _noop,
                      onToggleSelection: _noop,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final rows = find.byType(PlaylistControlItem);
      BoxDecoration rowDecorationAt(int index) {
        final rowContainer =
            find
                .descendant(
                  of: rows.at(index),
                  matching: find.byType(AnimatedContainer),
                )
                .first;
        return tester.widget<AnimatedContainer>(rowContainer).decoration!
            as BoxDecoration;
      }

      expect(rowDecorationAt(0).color, const Color(0x1f0078d7));
      expect(
        rowDecorationAt(1).color,
        GlobalUI.hoverBgColorDay.withValues(alpha: 0),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(rows.first));
      addTearDown(mouse.removePointer);
      await tester.pump();
      expect(rowDecorationAt(0).color, const Color(0x1f0078d7));

      await mouse.moveTo(tester.getCenter(rows.at(1)));
      await tester.pump();
      expect(rowDecorationAt(0).color, const Color(0x1f0078d7));
      expect(rowDecorationAt(1).color, GlobalUI.hoverBgColorDay);
    },
  );

  testWidgets(
    'PlaylistControlItem row hover uses only Electron background layer',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 720,
                child: PlaylistControlItem(
                  song: _song,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  onOpenContextMenu: _noopPosition,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      final rowInkWell = tester.widget<InkWell>(
        find
            .descendant(
              of: find.byType(PlaylistControlItem),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(
        rowInkWell.overlayColor?.resolve({WidgetState.hovered}),
        Colors.transparent,
      );
      expect(
        rowInkWell.overlayColor?.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
      expect(
        rowInkWell.overlayColor?.resolve({WidgetState.focused}),
        Colors.transparent,
      );
      expect(rowInkWell.hoverColor, Colors.transparent);
      expect(rowInkWell.focusColor, Colors.transparent);
      expect(rowInkWell.highlightColor, Colors.transparent);
      expect(rowInkWell.splashColor, Colors.transparent);

      final rowContainer = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(PlaylistControlItem),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(
        (rowContainer.decoration! as BoxDecoration).color,
        GlobalUI.hoverBgColorDay.withValues(alpha: 0),
      );
    },
  );

  testWidgets(
    'PlaylistControlItem narrow compact hover expands actions like Electron',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 360,
                child: PlaylistControlItem(
                  song: _song,
                  current: true,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  variant: PlaylistControlItemVariant.compact,
                  moreLabel: 'More',
                  onOpenContextMenu: _noopPosition,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      AnimatedOpacity hoverOpacityFor(Finder action) {
        return tester.widget<AnimatedOpacity>(
          find
              .ancestor(of: action, matching: find.byType(AnimatedOpacity))
              .first,
        );
      }

      final playNext = find.byKey(
        const ValueKey('PlaylistControlItem.PlayNextAction'),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byType(PlaylistControlItem)),
      );
      addTearDown(mouse.removePointer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(hoverOpacityFor(playNext).opacity, 1);
      expect(
        find.byKey(const ValueKey('PlaylistControlItem.Actions')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('PlaylistControlItem.Actions')))
            .width,
        68,
      );
    },
  );

  testWidgets('PlaylistControlItem metadata uses Electron album separator', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 500,
              child: PlaylistControlItem(
                song: _song,
                current: false,
                playing: false,
                selected: false,
                selectionMode: false,
                onPlayTrack: _noop,
                onTogglePlayPause: _noop,
                onToggleSelection: _noop,
                onOpenContextMenu: _noopPosition,
                onPlayNextClick: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text(' • '), findsOneWidget);
    expect(find.text(' - '), findsNothing);
  });

  testWidgets(
    'PlaylistControlItem drop indicator uses Electron desktop inset',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 900,
                child: PlaylistControlItem(
                  song: _song,
                  current: false,
                  playing: false,
                  selected: false,
                  selectionMode: false,
                  dropPosition: PlaylistControlDropPosition.before,
                  onPlayTrack: _noop,
                  onTogglePlayPause: _noop,
                  onToggleSelection: _noop,
                  onOpenContextMenu: _noopPosition,
                  onPlayNextClick: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      final itemLeft = tester.getTopLeft(find.byType(PlaylistControlItem)).dx;
      final itemRight = tester.getTopRight(find.byType(PlaylistControlItem)).dx;
      final indicator = find.byKey(
        const ValueKey('PlaylistControlItem.DropIndicator'),
      );

      expect(tester.getTopLeft(indicator).dx - itemLeft, 18);
      expect(itemRight - tester.getTopRight(indicator).dx, 22);
    },
  );
}

void _noop() {}

void _noopContext(BuildContext context) {}

void _noopPosition(Offset position) {}

double _playingBarHeight(WidgetTester tester, int index) {
  return tester
      .getSize(find.byKey(ValueKey('PlaylistControlItem.Playing.Bar.$index')))
      .height;
}

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.albumUnknown': 'Unknown Album',
    'common.artistSeparator': ' / ',
    'common.artistUnknown': 'Unknown Artist',
    'context.addToPlaylist': 'Add To',
    'context.play': 'Play',
    'context.playNext': 'Play Next',
    'nowPlaying.remove': 'Remove',
    'player.more': 'More',
    'player.pause': 'Pause',
  },
);

const _song = LibrarySong(
  id: 1,
  path: '/music/song.mp3',
  title: 'Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-05-25',
  favorite: false,
  thumbnailPath: '',
);

const _favoriteSong = LibrarySong(
  id: 3,
  path: '/music/favorite-song.mp3',
  title: 'Favorite Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-05-25',
  favorite: true,
  thumbnailPath: '',
);

const _threeFortySevenSong = LibrarySong(
  id: 2,
  path: '/music/song-2.mp3',
  title: 'Song 2',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 227,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-05-25',
  favorite: false,
  thumbnailPath: '',
);
