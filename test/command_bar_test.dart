import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/uniform_multi_select_icon.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar_colors.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.myFavorites': 'My Favorites',
      'common.cancel': 'Cancel',
      'common.nowPlaying': 'Now Playing',
      'albums.addSelectedTo': 'Add selected to',
      'albums.clearSelection': 'Clear Selection',
      'albums.playSelected': 'Play Selected',
      'albums.reverseSelection': 'Invert Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'context.addToPlaylist': 'Add To',
      'context.deleteFromDisk': 'Delete From Disk',
      'context.hideFile': 'Hide File',
      'context.moveToFolder': 'Move To Folder',
      'context.pause': 'Pause',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.removeFromList': 'Remove From List',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLocalFile': 'See In File Explorer',
      'context.seeLyrics': 'See Lyrics',
      'context.seeMusicInfo': 'See Music Info',
      'context.select': 'Select',
      'context.view': 'View',
      'playlists.newPlaylist': 'New Playlist',
      'player.more': 'More',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do Not Appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'preferences.undoPrefer': 'Undo Prefer',
      'notification.removedFrom': 'Removed {title} from {target}',
      'notification.songsRemovedFrom': 'Removed {count} songs from {target}',
      'settings.preferenceSettings': 'Preference Settings',
    },
  );

  const zhI18n = SmPlayerI18n(
    locale: 'zh-CN',
    messages: {
      'common.myFavorites': '我喜欢',
      'common.cancel': '取消',
      'common.nowPlaying': '正在播放',
      'albums.addSelectedTo': '添加到',
      'albums.clearSelection': '清除...',
      'albums.playSelected': '播放',
      'albums.reverseSelection': '反选',
      'albums.selectAll': '全选',
      'albums.selectedCount': '已选择 {count} 项',
      'context.addToPlaylist': '添加到',
      'context.removeFromList': '移除',
      'player.more': '更多',
      'playlists.newPlaylist': '新建播放列表',
    },
  );

  testWidgets('CommandBar keeps buttons inline when space is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: CommandBar(
              children: [
                CommandBarButton(
                  key: const ValueKey('first-button'),
                  icon: FluentIcons.play_24_regular,
                  label: 'First',
                  onPressed: () {},
                ),
                CommandBarButton(
                  key: const ValueKey('second-button'),
                  icon: FluentIcons.add_24_regular,
                  label: 'Second',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('first-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('second-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('CommandBar.MoreButton')), findsNothing);
  });

  testWidgets('MultiSelectCommandBar desktop matches Electron layout rules', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(tester, i18n: i18n, width: 2000);

    expect(multiSelectCommandBarScrollSpacer, 108);
    expect(multiSelectCommandBarCompactBreakpoint, 760);
    expect(_multiSelectExcludeSemantics(tester).excluding, isFalse);
    expect(
      find.byKey(const ValueKey('MultiSelectCommandBar.MoreButton')),
      findsNothing,
    );
    expect(find.text('Select All'), findsOneWidget);
    expect(find.text('Invert Selection'), findsOneWidget);
    expect(find.text('Clear Selection'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);

    final bar = _multiSelectBarContainer(tester);
    expect(tester.getSize(find.byWidget(bar)).height, 64);
    expect(multiSelectCommandBarBackdropSaturation, 1.65);
    final surfaceGlass = tester.widget<GlassContainer>(
      find.byKey(const ValueKey('MultiSelectCommandBar.Glass')),
    );
    expect(surfaceGlass.useOwnLayer, isTrue);
    expect(surfaceGlass.quality, GlassQuality.minimal);
    expect(surfaceGlass.clipBehavior, Clip.hardEdge);
    expect(surfaceGlass.allowElevation, isFalse);
    expect(surfaceGlass.shape, isA<LiquidRoundedRectangle>());
    expect(surfaceGlass.settings?.blur, 46);
    expect(surfaceGlass.settings?.thickness, 20);
    expect(surfaceGlass.settings?.refractiveIndex, 1.06);
    expect(surfaceGlass.settings?.lightIntensity, 0.1);
    expect(surfaceGlass.settings?.ambientStrength, 0.08);
    expect(surfaceGlass.settings?.glowIntensity, 0.04);
    expect(
      surfaceGlass.settings?.glassColor,
      CommandBarColors.multiSelectSurface,
    );
    expect(
      surfaceGlass.settings?.saturation,
      multiSelectCommandBarBackdropSaturation,
    );
    expect(surfaceGlass.settings?.standardOpacityMultiplier, 0.24);
    expect(bar.padding, const EdgeInsets.fromLTRB(26, 0, 18, 0));
    expect(_separatorCountWithHeight(tester, 28), greaterThanOrEqualTo(2));
    expect(_selectedCountBoxWidth(tester), 154);
    expect(_labelStyleForText(tester, '3 selected').fontSize, 13);
    expect(_labelStyleForText(tester, '3 selected').fontVariations, const [
      FontVariation.weight(760),
    ]);

    final cancel = _buttonWithIcon(tester, FluentIcons.dismiss_20_regular);
    expect(_buttonSizeWithText(tester, 'Cancel').height, 36);
    expect(cancel.minWidth, 72);
    expect(cancel.horizontalPadding, 12);
    expect(cancel.height, 36);
    expect(
      _buttonControlDecorationWithText(tester, 'Cancel').color,
      CommandBarColors.actionSurface,
    );
    expect(_labelStyleForText(tester, 'Cancel').fontSize, 13);
    expect(_labelStyleForText(tester, 'Cancel').height, 1);
    expect(_labelStyleForText(tester, 'Cancel').fontVariations, const [
      FontVariation.weight(640),
    ]);
    expect(_buttonDecorationWithText(tester, 'Cancel').boxShadow, isNotEmpty);

    for (final label in [
      'Cancel',
      'Play Selected',
      'Add selected to',
      'Remove From List',
      'Select All',
      'Invert Selection',
      'Clear Selection',
    ]) {
      expect(_buttonSizeWithText(tester, label).height, 36);
      expect(_labelStyleForText(tester, label).fontSize, 13);
      expect(_labelStyleForText(tester, label).height, 1);
      expect(_labelStyleForText(tester, label).fontVariations, const [
        FontVariation.weight(640),
      ]);
      expect(_buttonWithText(tester, label), isA<SmPlayerTextIconButton>());
      expect(_buttonIconSizesWithText(tester, label), everyElement(16));
    }

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.text('Cancel')));
    await tester.pumpAndSettle();
    final hoverShadow = _buttonDecorationWithText(tester, 'Cancel').boxShadow!;
    expect(hoverShadow.first.blurRadius, 10);
    expect(hoverShadow.first.offset, const Offset(0, 3));
  });

  testWidgets(
    'MultiSelectCommandBar keeps desktop action layout above Electron 760px breakpoint',
    (tester) async {
      await _pumpMultiSelectCommandBar(tester, i18n: zhI18n, width: 900);

      expect(
        find.byKey(const ValueKey('MultiSelectCommandBar.MoreButton')),
        findsNothing,
      );
      expect(find.text('全选'), findsOneWidget);
      expect(find.text('反选'), findsOneWidget);
      expect(find.text('清除...'), findsOneWidget);
      expect(
        _multiSelectBarContainer(tester).padding,
        const EdgeInsets.fromLTRB(26, 0, 18, 0),
      );
      expect(_separatorCountWithHeight(tester, 28), greaterThanOrEqualTo(2));
      expect(_selectedCountBoxWidth(tester), 154);
    },
  );

  testWidgets(
    'MultiSelectCommandBar shell inset mirrors Electron player-overlap bottom',
    (tester) async {
      await _pumpMultiSelectCommandBar(
        tester,
        i18n: i18n,
        width: 2000,
        bottomInset: multiSelectCommandBarShellBottomInset,
      );

      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
      );
      expect(surfaceRect.bottom, 420);
      expect(surfaceRect.height, 64 + multiSelectCommandBarShellBottomInset);
    },
  );

  testWidgets('MultiSelectCommandBar can bleed across padded page panels', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(
      tester,
      i18n: i18n,
      width: 2000,
      horizontalBleed: 24,
    );

    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
    );
    expect(surfaceRect.left, -24);
    expect(surfaceRect.width, 2048);
  });

  testWidgets('MultiSelectCommandBar supports asymmetric page panel bleed', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(
      tester,
      i18n: i18n,
      width: 2000,
      leftBleed: 24,
      rightBleed: 18,
    );

    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
    );
    expect(surfaceRect.left, -24);
    expect(surfaceRect.right, 2018);
    expect(surfaceRect.width, 2042);
  });

  testWidgets(
    'MultiSelectCommandBar compact mode moves selection actions to More',
    (tester) async {
      await _pumpMultiSelectCommandBar(tester, i18n: i18n, width: 760);

      expect(find.text('Select All'), findsNothing);
      expect(find.text('Invert Selection'), findsNothing);
      expect(find.text('Clear Selection'), findsNothing);

      final more = tester.widget<SmPlayerTextIconButton>(
        find.byKey(const ValueKey('MultiSelectCommandBar.MoreButton')),
      );
      expect(more.minWidth, 44);
      expect(more.maxWidth, 44);
      expect(more.height, 36);
      expect(
        _multiSelectBarContainer(tester).padding,
        const EdgeInsets.fromLTRB(18, 0, 12, 0),
      );
      expect(_separatorCountWithHeight(tester, 26), 1);
      expect(_selectedCountBoxWidth(tester), 112);
    },
  );

  testWidgets('MultiSelectCommandBar compact Chinese Add To keeps full label', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(tester, i18n: zhI18n, width: 760);

    expect(tester.takeException(), isNull);
    expect(find.text('添加到'), findsOneWidget);
    final addToSize = _buttonSizeWithText(tester, '添加到');
    expect(addToSize.width, greaterThanOrEqualTo(112));
    final addToRect = tester.getRect(
      find.ancestor(
        of: find.text('添加到'),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    final moreRect = tester.getRect(
      find.byKey(const ValueKey('MultiSelectCommandBar.MoreButton')),
    );
    expect(addToRect.right, lessThan(moreRect.left));
    expect(_buttonWithText(tester, '添加到').maxWidth, double.infinity);
  });

  testWidgets(
    'MultiSelectCommandBar Chinese selection actions keep full labels',
    (tester) async {
      await _pumpMultiSelectCommandBar(tester, i18n: zhI18n, width: 2000);

      expect(tester.takeException(), isNull);
      expect(find.text('全选'), findsOneWidget);
      expect(find.text('反选'), findsOneWidget);
      expect(find.text('清除...'), findsOneWidget);

      final reverseRect = tester.getRect(
        find.ancestor(
          of: find.text('反选'),
          matching: find.byType(SmPlayerTextIconButton),
        ),
      );
      final clearRect = tester.getRect(
        find.ancestor(
          of: find.text('清除...'),
          matching: find.byType(SmPlayerTextIconButton),
        ),
      );
      expect(reverseRect.right, lessThan(clearRect.left));
      expect(clearRect.right, lessThan(2000));
    },
  );

  testWidgets('MultiSelectCommandBar More menu opens 8px above anchor', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(tester, i18n: i18n, width: 760);

    final moreFinder = find.byKey(
      const ValueKey('MultiSelectCommandBar.MoreButton'),
    );
    final moreRect = tester.getRect(moreFinder);

    await tester.tap(moreFinder);
    await tester.pumpAndSettle();

    expect(find.text('Select All'), findsOneWidget);
    expect(find.text('Invert Selection'), findsOneWidget);
    expect(find.text('Clear Selection'), findsOneWidget);
    expect(find.text('Remove From List'), findsWidgets);

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );
    expect(panelRect.bottom, moreOrLessEquals(moreRect.top - 8, epsilon: 1));
  });

  testWidgets('MultiSelectCommandBar Add To menu opens 8px above anchor', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(tester, i18n: i18n, width: 2000);

    final addToFinder = find.text('Add selected to');
    final addToButton = find.ancestor(
      of: addToFinder,
      matching: find.byType(SmPlayerTextIconButton),
    );
    final addToRect = tester.getRect(addToButton);

    await tester.tap(addToFinder);
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );
    expect(panelRect.bottom, moreOrLessEquals(addToRect.top - 8, epsilon: 1));
  });

  testWidgets('MultiSelectCommandBar pointer Add To anchor is one-shot', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(
      tester,
      i18n: i18n,
      width: 2000,
      addToMenuPosition: MultiSelectCommandBarAddToMenuPosition.pointer,
    );

    final addToFinder = find.text('Add selected to');
    final addToButton = find.ancestor(
      of: addToFinder,
      matching: find.byType(SmPlayerTextIconButton),
    );
    final addToRect = tester.getRect(addToButton);

    await tester.tapAt(addToRect.center);
    await tester.pumpAndSettle();

    final pointerPanelRect = tester.getRect(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );
    expect(
      pointerPanelRect.bottom,
      isNot(moreOrLessEquals(addToRect.top - 8, epsilon: 1)),
    );

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    _buttonWithText(tester, 'Add selected to').onPressed?.call();
    await tester.pumpAndSettle();

    final fallbackPanelRect = tester.getRect(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );
    expect(
      fallbackPanelRect.bottom,
      moreOrLessEquals(addToRect.top - 8, epsilon: 1),
    );
  });

  testWidgets('MultiSelectCommandBar hides Add To when no target exists', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(
      tester,
      i18n: i18n,
      width: 2000,
      includeNowPlayingInAddTo: false,
      includeFavoritesInAddTo: false,
      onCreatePlaylist: null,
      onAddToPlaylist: null,
    );

    expect(find.text('Add selected to'), findsNothing);
  });

  testWidgets('MultiSelectCommandBar phone keeps truncated Add To text', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(tester, i18n: i18n, width: 520);

    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Add selected to'), findsOneWidget);
    expect(find.text('Remove From List'), findsNothing);

    final more = tester.widget<SmPlayerTextIconButton>(
      find.byKey(const ValueKey('MultiSelectCommandBar.MoreButton')),
    );
    expect(more.minWidth, 40);
    expect(more.maxWidth, 40);
    expect(more.height, 36);
    expect(
      _multiSelectBarContainer(tester).padding,
      const EdgeInsets.fromLTRB(12, 0, 10, 0),
    );
    expect(_separatorCountWithHeight(tester, 28), 0);
    expect(_separatorCountWithHeight(tester, 26), 0);

    final cancel = _buttonWithIcon(tester, FluentIcons.dismiss_20_regular);
    expect(cancel.showLabel, isFalse);
    expect(cancel.minWidth, 40);
    expect(cancel.maxWidth, 40);
    expect(cancel.horizontalPadding, 0);

    final addTo = _buttonWithText(tester, 'Add selected to');
    expect(_buttonSizeWithText(tester, 'Add selected to').height, 36);
    expect(addTo.minWidth, 40);
    expect(addTo.maxWidth, 88);
    expect(_buttonIconSizesWithText(tester, 'Add selected to'), [16]);

    final selectedCount = tester.getRect(find.text('3 selected'));
    final checkIcon = tester.getRect(
      find.byIcon(FluentIcons.checkmark_20_regular),
    );
    expect(checkIcon.left, lessThan(selectedCount.left));
    expect(selectedCount.right - checkIcon.left, lessThanOrEqualTo(96));
  });

  testWidgets('MultiSelectCommandBar disabled actions use Electron opacity', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(
      tester,
      i18n: i18n,
      width: 2000,
      selectedCount: 0,
    );

    for (final label in [
      'Play Selected',
      'Add selected to',
      'Remove From List',
    ]) {
      expect(_buttonWithText(tester, label).disabled, isTrue);
      expect(_opacityForButtonText(tester, label), 0.46);
      expect(_opacityContainsButtonShadow(tester, label), isTrue);
      final disabledShadow =
          _buttonDecorationWithText(tester, label).boxShadow!;
      expect(disabledShadow, hasLength(1));
      expect(disabledShadow.single.color, const Color(0x9effffff));
      expect(disabledShadow.single.blurRadius, 0);
      expect(disabledShadow.single.offset, const Offset(0, 1));
    }
  });

  testWidgets(
    'MultiSelectCommandBar hidden state remains mounted for animation',
    (tester) async {
      await _pumpMultiSelectCommandBar(
        tester,
        i18n: i18n,
        width: 2000,
        visible: false,
      );

      expect(find.text('Cancel'), findsOneWidget);
      final opacity = tester
          .widgetList<AnimatedOpacity>(
            find.byType(AnimatedOpacity, skipOffstage: false),
          )
          .firstWhere((widget) => widget.opacity == 0);
      expect(opacity.opacity, 0);
      expect(opacity.duration, const Duration(milliseconds: 180));
      final slide = tester.widget<AnimatedSlide>(
        find.byType(AnimatedSlide, skipOffstage: false),
      );
      expect(
        slide.offset,
        const Offset(0, multiSelectCommandBarHiddenSlideFraction),
      );
      expect(slide.duration, const Duration(milliseconds: 180));
      expect(slide.curve, Curves.ease);
      expect(_multiSelectExcludeSemantics(tester).excluding, isTrue);
      final ignore = tester
          .widgetList<IgnorePointer>(
            find.byType(IgnorePointer, skipOffstage: false),
          )
          .firstWhere((widget) => widget.ignoring);
      expect(ignore.ignoring, isTrue);
    },
  );

  testWidgets(
    'MultiSelectCommandBar layout changes use Electron transition timing',
    (tester) async {
      await _pumpMultiSelectCommandBar(
        tester,
        i18n: i18n,
        width: 2000,
        bottomInset: multiSelectCommandBarShellBottomInset,
        leftBleed: 24,
        rightBleed: 18,
      );

      final padding = tester.widget<AnimatedPadding>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
              matching: find.byType(AnimatedPadding),
            )
            .first,
      );
      expect(padding.duration, multiSelectCommandBarLayoutAnimationDuration);
      expect(padding.curve, Curves.ease);
      expect(padding.padding, EdgeInsets.zero);

      final motionFinder =
          find
              .ancestor(
                of: find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
                matching: find.byType(AnimatedContainer),
              )
              .first;
      final motion = tester.widget<AnimatedContainer>(motionFinder);
      expect(motion.duration, multiSelectCommandBarLayoutAnimationDuration);
      expect(motion.curve, Curves.ease);
      expect(motion.transform, Matrix4.translationValues(-3, 0, 0));
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
        ),
        const Size(2042, 64 + multiSelectCommandBarShellBottomInset),
      );
    },
  );

  testWidgets('MultiSelectCommandBar night colors mirror Electron target', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(
      tester,
      i18n: i18n,
      width: 2000,
      brightness: Brightness.dark,
    );

    final play = _buttonWithText(tester, 'Play Selected');
    expect(
      _buttonControlDecorationWithText(tester, 'Play Selected').color,
      CommandBarColors.actionNightSurface,
    );
    expect(play.fontSize, 13);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.text('Play Selected')),
    );
    await tester.pumpAndSettle();
    expect(
      _buttonDecorationWithText(tester, 'Play Selected').boxShadow,
      isEmpty,
    );
  });

  testWidgets(
    'CommandBar intrinsic content leaves remaining width to actions',
    (tester) async {
      tester.view.physicalSize = const Size(2000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1800,
                child: CommandBar(
                  contentSizing: CommandBarContentSizing.intrinsic,
                  overflowLabel: 'More',
                  content: const Text('2 folders, 8 songs'),
                  children: [
                    CommandBarButton(
                      key: const ValueKey('random-play-button'),
                      icon: FluentIcons.arrow_shuffle_24_regular,
                      label: 'Random Play',
                      onPressed: () {},
                    ),
                    CommandBarButton(
                      key: const ValueKey('update-folder-button'),
                      icon: FluentIcons.arrow_sync_24_regular,
                      label: 'Update Folder',
                      onPressed: () {},
                    ),
                    CommandBarButton(
                      key: const ValueKey('sort-button'),
                      icon: FluentIcons.arrow_sort_24_regular,
                      label: 'Sort',
                      onPressed: () {},
                    ),
                    CommandBarButton(
                      key: const ValueKey('new-folder-button'),
                      icon: FluentIcons.add_24_regular,
                      label: 'New Folder',
                      onPressed: () {},
                    ),
                    CommandBarButton(
                      key: const ValueKey('multi-select-button'),
                      icon: FluentIcons.multiselect_ltr_24_regular,
                      label: 'Multi Select',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('random-play-button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('update-folder-button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sort-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('new-folder-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('multi-select-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('CommandBar.MoreButton')), findsNothing);
    },
  );

  testWidgets(
    'CommandBar standard text buttons use the shared text icon button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommandBar(
              children: [
                CommandBarButton(
                  icon: FluentIcons.play_24_regular,
                  label: 'Play',
                  onPressed: () {},
                ),
                CommandBarButton(
                  icon: FluentIcons.more_horizontal_24_regular,
                  label: 'More',
                  showLabel: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SmPlayerTextIconButton), findsNWidgets(2));
    },
  );

  testWidgets(
    'CommandBarButton with visible label does not show label tooltip',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommandBar(
              children: [
                CommandBarButton(
                  icon: FluentIcons.checkmark_20_regular,
                  label: 'Multi Select',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(Tooltip), findsNothing);
    },
  );

  testWidgets('CommandBarButton icon-only keeps label tooltip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandBar(
            children: [
              CommandBarButton(
                icon: FluentIcons.more_horizontal_24_regular,
                label: 'More',
                showLabel: false,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'More');
  });

  testWidgets('CommandBar icon-only buttons use night colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [SmPlayerTextIconButtonColors.night],
        ),
        home: Scaffold(
          body: CommandBar(
            children: [
              CommandBarButton(
                key: const ValueKey('more-button'),
                icon: FluentIcons.more_horizontal_24_regular,
                label: 'More',
                showLabel: false,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final decoratedBox = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('more-button')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .firstWhere((box) => box.decoration is BoxDecoration);
    final decoration = decoratedBox.decoration as BoxDecoration;

    expect(decoration.color, SmPlayerTextIconButtonColors.night.control);
    expect(
      decoration.border,
      Border.all(color: SmPlayerTextIconButtonColors.night.controlBorder),
    );
  });

  testWidgets('CommandBar appbar actions share icon and text button metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandBar(
            style: CommandBarStyleVariant.appBar,
            children: [
              CommandBarButton(
                key: const ValueKey('appbar-icon'),
                icon: FluentIcons.search_20_regular,
                label: 'Search',
                showLabel: false,
                onPressed: () {},
              ),
              CommandBarButton(
                key: const ValueKey('appbar-text'),
                icon: FluentIcons.play_20_regular,
                label: 'Quick Play',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final iconRect = tester.getRect(find.byKey(const ValueKey('appbar-icon')));
    final textRect = tester.getRect(find.byKey(const ValueKey('appbar-text')));
    expect(iconRect.size, const Size.square(40));
    expect(textRect.height, 40);

    final textButton = tester.widget<SmPlayerTextIconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('appbar-text')),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    expect(textButton.fontSize, 14);
    expect(textButton.fontVariations, const [FontVariation.weight(650)]);
  });

  testWidgets('CommandBar appbar hover mirrors Electron narrow appbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandBar(
            style: CommandBarStyleVariant.appBar,
            children: [
              CommandBarButton(
                key: const ValueKey('appbar-action'),
                icon: FluentIcons.search_20_regular,
                label: 'Search',
                showLabel: false,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('appbar-action'));
    expect(_textIconButtonDecoration(tester, button).color, Colors.transparent);

    tester.binding.handlePointerEvent(
      PointerHoverEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(button),
      ),
    );
    await tester.pump();

    final hoverDecoration = _textIconButtonDecoration(tester, button);
    expect(hoverDecoration.color, CommandBarColors.appBarHover);
    expect(
      _textIconButtonIconColor(tester, button),
      CommandBarColors.appBarHoverForeground,
    );
  });

  testWidgets('CommandBar appbar night hover mirrors Electron narrow appbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [SmPlayerTextIconButtonColors.night],
        ),
        home: Scaffold(
          body: CommandBar(
            style: CommandBarStyleVariant.appBar,
            children: [
              CommandBarButton(
                key: const ValueKey('appbar-action'),
                icon: FluentIcons.search_20_regular,
                label: 'Search',
                showLabel: false,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('appbar-action'));
    expect(_textIconButtonDecoration(tester, button).color, Colors.transparent);

    tester.binding.handlePointerEvent(
      PointerHoverEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(button),
      ),
    );
    await tester.pump();

    final hoverDecoration = _textIconButtonDecoration(tester, button);
    expect(hoverDecoration.color, CommandBarColors.appBarHoverDark);
    expect(
      _textIconButtonIconColor(tester, button),
      CommandBarColors.appBarHoverForegroundDark,
    );
  });

  testWidgets('SmPlayerTextIconButton does not render a box shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmPlayerTextIconButton(
            icon: FluentIcons.play_24_regular,
            label: 'Play',
            onPressed: () {},
          ),
        ),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(SmPlayerTextIconButton),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.boxShadow, isNull);
  });

  testWidgets(
    'SmPlayerTextIconButton omits implicit tooltip when label is visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmPlayerTextIconButton(
              icon: FluentIcons.play_24_regular,
              label: 'Play',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(Tooltip), findsNothing);
    },
  );

  testWidgets(
    'SmPlayerTextIconButton keeps explicit tooltip when label is visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmPlayerTextIconButton(
              icon: FluentIcons.play_24_regular,
              label: 'Play',
              tooltip: 'Start playback',
              onPressed: () {},
            ),
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Start playback');
    },
  );

  testWidgets(
    'SmPlayerTextIconButton keeps label tooltip for icon-only buttons',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmPlayerTextIconButton(
              icon: FluentIcons.play_24_regular,
              label: 'Play',
              showLabel: false,
              onPressed: () {},
            ),
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Play');
    },
  );

  testWidgets('SmPlayerTextIconButton respects tooltipEnabled false', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmPlayerTextIconButton(
            icon: FluentIcons.play_24_regular,
            label: 'Play',
            tooltip: 'Start playback',
            tooltipEnabled: false,
            showLabel: false,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('SmPlayerTextIconButton can render inside liquid glass', (
    tester,
  ) async {
    const glassSettings = LiquidGlassSettings(
      blur: 46,
      thickness: 20,
      refractiveIndex: 1.06,
      saturation: 1.65,
      chromaticAberration: 0,
      lightIntensity: 0.1,
      ambientStrength: 0.08,
      glowIntensity: 0.04,
      glassColor: Color(0x1cffffff),
      standardOpacityMultiplier: 0.35,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmPlayerTextIconButton(
            icon: FluentIcons.play_24_regular,
            label: 'Play',
            borderRadius: 12,
            glassSettings: glassSettings,
            onPressed: () {},
          ),
        ),
      ),
    );

    final glass = tester.widget<GlassContainer>(
      find.descendant(
        of: find.byType(SmPlayerTextIconButton),
        matching: find.byType(GlassContainer),
      ),
    );
    expect(glass.settings, glassSettings);
    expect(glass.quality, GlassQuality.minimal);
    expect(glass.useOwnLayer, isTrue);
    expect(glass.allowElevation, isFalse);
    expect(glass.clipBehavior, Clip.hardEdge);
    expect(glass.shape, isA<LiquidRoundedRectangle>());

    final decoration = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(SmPlayerTextIconButton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.border != null);
    expect(decoration.borderRadius, BorderRadius.circular(12));
  });

  testWidgets(
    'SmPlayerTextIconButton default hover mirrors Electron accent hover',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmPlayerTextIconButton(
              key: const ValueKey('text-icon-button'),
              icon: FluentIcons.folder_24_regular,
              label: 'Play',
              onPressed: () {},
            ),
          ),
        ),
      );

      final button = find.byKey(const ValueKey('text-icon-button'));
      expect(
        _textIconButtonDecoration(tester, button).color,
        SmPlayerTextIconButtonColors.day.control,
      );

      tester.binding.handlePointerEvent(
        PointerHoverEvent(
          kind: PointerDeviceKind.mouse,
          position: tester.getCenter(button),
        ),
      );
      await tester.pump();

      final hoverDecoration = _textIconButtonDecoration(tester, button);
      expect(
        hoverDecoration.color,
        SmPlayerTextIconButtonColors.day.controlHover,
      );
      expect(
        hoverDecoration.border,
        Border.all(color: SmPlayerTextIconButtonColors.day.controlHoverBorder),
      );
      expect(
        _textIconButtonIconColor(tester, button),
        SmPlayerTextIconButtonColors.day.commandTextHover,
      );
    },
  );

  testWidgets('CommandBar text button hover matches settings buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandBar(
            children: [
              CommandBarButton(
                key: const ValueKey('commandbar-play'),
                icon: FluentIcons.folder_24_regular,
                label: 'Play',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('commandbar-play'));
    tester.binding.handlePointerEvent(
      PointerHoverEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(button),
      ),
    );
    await tester.pump();

    final hoverDecoration = _textIconButtonDecoration(tester, button);
    expect(
      hoverDecoration.color,
      SmPlayerTextIconButtonColors.day.controlHover,
    );
    expect(
      hoverDecoration.border,
      Border.all(color: SmPlayerTextIconButtonColors.day.controlHoverBorder),
    );
    expect(
      _textIconButtonIconColor(tester, button),
      SmPlayerTextIconButtonColors.day.commandTextHover,
    );
  });

  testWidgets('CommandBar text button night hover matches settings buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [SmPlayerTextIconButtonColors.night],
        ),
        home: Scaffold(
          body: CommandBar(
            children: [
              CommandBarButton(
                key: const ValueKey('commandbar-play'),
                icon: FluentIcons.folder_24_regular,
                label: 'Play',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('commandbar-play'));
    tester.binding.handlePointerEvent(
      PointerHoverEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(button),
      ),
    );
    await tester.pump();

    final hoverDecoration = _textIconButtonDecoration(tester, button);
    expect(
      hoverDecoration.color,
      SmPlayerTextIconButtonColors.night.controlHover,
    );
    expect(
      hoverDecoration.border,
      Border.all(color: SmPlayerTextIconButtonColors.night.controlHoverBorder),
    );
    expect(
      _textIconButtonIconColor(tester, button),
      SmPlayerTextIconButtonColors.night.commandTextHover,
    );
  });

  testWidgets('CommandBar moves rightmost overflowable buttons into More', (
    tester,
  ) async {
    var invoked = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 170,
            child: CommandBar(
              overflowLabel: 'More',
              children: [
                CommandBarButton(
                  key: const ValueKey('first-button'),
                  icon: FluentIcons.play_24_regular,
                  label: 'First',
                  onPressed: () {
                    invoked = 'first';
                  },
                ),
                CommandBarButton(
                  key: const ValueKey('second-button'),
                  icon: FluentIcons.add_24_regular,
                  label: 'Second',
                  onPressed: () {
                    invoked = 'second';
                  },
                ),
                CommandBarButton(
                  key: const ValueKey('third-button'),
                  icon: FluentIcons.delete_24_regular,
                  label: 'Third',
                  onPressed: () {
                    invoked = 'third';
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('first-button')), findsNothing);
    expect(find.byKey(const ValueKey('second-button')), findsNothing);
    expect(find.byKey(const ValueKey('third-button')), findsNothing);
    expect(find.byKey(const ValueKey('CommandBar.MoreButton')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('CommandBar.MoreButton')));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);

    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();

    expect(invoked, 'third');
  });

  testWidgets('CommandBar keeps overflow on one row instead of wrapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              child: CommandBar(
                overflowLabel: 'More',
                children: [
                  CommandBarButton(
                    icon: FluentIcons.play_24_regular,
                    label: 'Quick Play',
                    onPressed: () {},
                  ),
                  CommandBarButton(
                    icon: FluentIcons.arrow_shuffle_24_regular,
                    label: 'Random Play',
                    onPressed: () {},
                  ),
                  CommandBarButton(
                    icon: FluentIcons.arrow_sort_24_regular,
                    label: 'Sort',
                    onPressed: () {},
                  ),
                  CommandBarButton(
                    icon: FluentIcons.multiselect_ltr_24_regular,
                    label: 'Multi Select',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final commandBarRect = tester.getRect(find.byType(CommandBar));
    expect(commandBarRect.height, 48);
    expect(find.byKey(const ValueKey('CommandBar.MoreButton')), findsOneWidget);
  });

  testWidgets('CommandBar overflow click can open a new root flyout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 96,
            child: CommandBar(
              overflowLabel: 'More',
              children: [
                CommandBarButton(
                  icon: FluentIcons.arrow_shuffle_24_regular,
                  label: 'Random',
                  onPressed: () {},
                  onOverflowPressedWithContext: (context) {
                    showMenuFlyout(
                      context,
                      items: [
                        MenuFlyoutItem(
                          key: 'library',
                          text: 'Library',
                          onPressed: () {},
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('CommandBar.MoreButton')));
    await tester.pumpAndSettle();

    expect(find.text('Random'), findsOneWidget);
    expect(find.text('Library'), findsNothing);

    await tester.tap(find.text('Random'));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('MenuFlyout opens submenu items like Electron flyouts', (
    tester,
  ) async {
    var selected = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'add-to',
                        text: 'Add To',
                        icon: FluentIcons.add_20_regular,
                        submenu: [
                          MenuFlyoutItem(
                            key: 'playlist',
                            text: 'Mix',
                            icon: FluentIcons.music_note_2_20_regular,
                            onPressed: () {
                              selected = 'mix';
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add To'), findsOneWidget);
    expect(find.text('Mix'), findsNothing);

    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(selected, 'mix');
  });

  testWidgets('MenuFlyout left-opening submenu stays beside parent', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    position: const Offset(260, 40),
                    avoidPlayerBar: false,
                    items: [
                      MenuFlyoutItem(
                        key: 'view',
                        text: 'View',
                        submenu: [
                          MenuFlyoutItem(
                            key: 'artist',
                            text: 'See Artist',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    final panels = find.byKey(const ValueKey('MenuFlyout.GlassPanel'));
    expect(panels, findsNWidgets(2));
    final rootPanelRect = tester.getRect(panels.first);
    final submenuPanelRect = tester.getRect(panels.last);
    expect(rootPanelRect.left - submenuPanelRect.right, lessThanOrEqualTo(8));
  });

  testWidgets('MenuFlyout uses liquid glass background', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'library',
                        text: 'Library',
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('MenuFlyout.GlassPanel')), findsOneWidget);
    final menuGlass = tester.widget<GlassContainer>(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );
    expect(menuGlass.quality, GlassQuality.minimal);
    expect(menuGlass.settings?.blur, 46);
    expect(menuGlass.settings?.saturation, 1.65);
    expect(menuGlass.settings?.standardOpacityMultiplier, 0.24);
    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('MenuFlyout uses the AlbumsPage uniform multi-select icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'select',
                        text: 'Select',
                        icon: FluentIcons.multiselect_ltr_20_regular,
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(UniformMultiSelectIcon), findsOneWidget);
  });

  test('MenuFlyout hover surface matches sidebar selected tab', () {
    expect(
      MenuFlyoutThemeColors.light.hoverSurface,
      GlobalUI.selectedBgColorDay,
    );
    expect(
      MenuFlyoutThemeColors.dark.hoverSurface,
      GlobalUI.selectedBgColorNight,
    );
  });

  testWidgets('MenuFlyout anchors inside nested navigator overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 72),
              Expanded(
                child: Row(
                  children: [
                    const SizedBox(width: 220),
                    Expanded(
                      child: Navigator(
                        onGenerateRoute:
                            (_) => MaterialPageRoute<void>(
                              builder:
                                  (context) => Padding(
                                    padding: const EdgeInsets.only(
                                      left: 48,
                                      top: 64,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Builder(
                                        builder: (context) {
                                          return TextButton(
                                            onPressed: () {
                                              showMenuFlyout(
                                                context,
                                                items: [
                                                  MenuFlyoutItem(
                                                    key: 'nested',
                                                    text: 'Nested Item',
                                                    onPressed: () {},
                                                  ),
                                                ],
                                              );
                                            },
                                            child: const Text('Nested Open'),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final button = find.widgetWithText(TextButton, 'Nested Open');
    final buttonRect = tester.getRect(button);

    await tester.tap(button);
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );
    expect(panelRect.left, moreOrLessEquals(buttonRect.left, epsilon: 1));
    expect(panelRect.top, moreOrLessEquals(buttonRect.bottom + 4, epsilon: 1));
  });

  testWidgets(
    'MenuFlyout closes when titlebar outside nested overlay is tapped',
    (tester) async {
      late BuildContext rootContext;
      var titlebarTapped = false;
      OverlayEntry? titlebarEntry;
      addTearDown(() {
        final entry = titlebarEntry;
        if (entry != null && entry.mounted) {
          entry.remove();
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                rootContext = context;
                return Row(
                  children: [
                    const SizedBox(width: 220),
                    Expanded(
                      child: Navigator(
                        onGenerateRoute:
                            (_) => MaterialPageRoute<void>(
                              builder:
                                  (context) => Padding(
                                    padding: const EdgeInsets.only(
                                      left: 48,
                                      top: 136,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Builder(
                                        builder: (context) {
                                          return TextButton(
                                            onPressed: () {
                                              showMenuFlyout(
                                                context,
                                                items: [
                                                  MenuFlyoutItem(
                                                    key: 'nested',
                                                    text: 'Nested Item',
                                                    onPressed: () {},
                                                  ),
                                                ],
                                              );
                                            },
                                            child: const Text('Nested Open'),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                            ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Nested Open'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
        findsOneWidget,
      );

      titlebarEntry = OverlayEntry(
        builder:
            (_) => Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: 72,
              child: GestureDetector(
                key: const ValueKey('TestTitleBar'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  titlebarTapped = true;
                },
                child: const SizedBox.expand(),
              ),
            ),
      );
      Overlay.of(rootContext, rootOverlay: true).insert(titlebarEntry);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('TestTitleBar')));
      await tester.pumpAndSettle();

      expect(titlebarTapped, isTrue);
      expect(find.byKey(const ValueKey('MenuFlyout.GlassPanel')), findsNothing);
    },
  );

  testWidgets('MenuFlyout explicit anchor uses nested overlay coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 72),
              Expanded(
                child: Row(
                  children: [
                    const SizedBox(width: 220),
                    Expanded(
                      child: Navigator(
                        onGenerateRoute:
                            (_) => MaterialPageRoute<void>(
                              builder:
                                  (context) => Padding(
                                    padding: const EdgeInsets.only(
                                      left: 48,
                                      top: 180,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Builder(
                                        builder: (context) {
                                          return TextButton(
                                            onPressed: () {
                                              final box =
                                                  context.findRenderObject()
                                                      as RenderBox;
                                              showMenuFlyout(
                                                context,
                                                position: box.localToGlobal(
                                                  const Offset(0, -8),
                                                ),
                                                items: [
                                                  MenuFlyoutItem(
                                                    key: 'nested-above',
                                                    text: 'Nested Above Item',
                                                    onPressed: () {},
                                                  ),
                                                ],
                                              );
                                            },
                                            child: const Text(
                                              'Nested Above Open',
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final button = find.widgetWithText(TextButton, 'Nested Above Open');
    final buttonRect = tester.getRect(button);

    await tester.tap(button);
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );
    expect(panelRect.left, moreOrLessEquals(buttonRect.left, epsilon: 1));
    expect(panelRect.bottom, moreOrLessEquals(buttonRect.top - 8, epsilon: 1));
  });

  testWidgets('MenuFlyout closes on Escape like Electron flyouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'first',
                        text: 'First',
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('First'), findsNothing);
  });

  testWidgets('MenuFlyout item actions receive the source anchor context', (
    tester,
  ) async {
    BuildContext? sourceContext;
    BuildContext? actionContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) {
                sourceContext = context;
                return TextButton(
                  onPressed: () {
                    showMenuFlyout(
                      context,
                      items: [
                        MenuFlyoutItem(
                          key: 'anchor-action',
                          text: 'Anchor Action',
                          onPressedWithContext: (context) {
                            actionContext = context;
                          },
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anchor Action'));
    await tester.pumpAndSettle();

    expect(actionContext, same(sourceContext));
  });

  testWidgets('MenuFlyout closes before async dialog actions complete', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'open-dialog',
                        text: 'Open Dialog',
                        onPressedWithContext: (menuContext) {
                          return showDialog<void>(
                            context: menuContext,
                            builder:
                                (context) => AlertDialog(
                                  content: const Text('Dialog Body'),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                          );
                        },
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Open Dialog'), findsOneWidget);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Open Dialog'), findsNothing);
    expect(find.text('Dialog Body'), findsOneWidget);
  });

  testWidgets('MenuFlyout closes before synchronous dialog actions run', (
    tester,
  ) async {
    var showDialogBody = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Stack(
                children: [
                  Builder(
                    builder: (context) {
                      return TextButton(
                        onPressed: () {
                          showMenuFlyout(
                            context,
                            items: [
                              MenuFlyoutItem(
                                key: 'open-sync-dialog',
                                text: 'Open Sync Dialog',
                                onPressed:
                                    () => setState(() {
                                      showDialogBody = true;
                                    }),
                              ),
                            ],
                          );
                        },
                        child: const Text('Open'),
                      );
                    },
                  ),
                  if (showDialogBody) const Text('Sync Dialog Body'),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Open Sync Dialog'), findsOneWidget);

    await tester.tap(find.text('Open Sync Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Open Sync Dialog'), findsNothing);
    expect(find.text('Sync Dialog Body'), findsOneWidget);
  });

  testWidgets('MenuFlyout action closes every open flyout', (tester) async {
    var actionRan = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Stack(
                children: [
                  Builder(
                    builder: (context) {
                      return TextButton(
                        onPressed: () {
                          showMenuFlyout(
                            context,
                            position: const Offset(20, 20),
                            avoidPlayerBar: false,
                            items: [
                              MenuFlyoutItem(
                                key: 'first-open-flyout-action',
                                text: 'First Open Flyout Action',
                                onPressed: () {},
                              ),
                            ],
                          );
                          showMenuFlyout(
                            context,
                            position: const Offset(260, 20),
                            avoidPlayerBar: false,
                            items: [
                              MenuFlyoutItem(
                                key: 'second-open-flyout-action',
                                text: 'Second Open Flyout Action',
                                onPressed:
                                    () => setState(() {
                                      actionRan = true;
                                    }),
                              ),
                            ],
                          );
                        },
                        child: const Text('Open'),
                      );
                    },
                  ),
                  if (actionRan) const Text('Action Ran'),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('First Open Flyout Action'), findsOneWidget);
    expect(find.text('Second Open Flyout Action'), findsOneWidget);

    await tester.tap(find.text('Second Open Flyout Action'));
    await tester.pumpAndSettle();

    expect(find.text('First Open Flyout Action'), findsNothing);
    expect(find.text('Second Open Flyout Action'), findsNothing);
    expect(find.text('Action Ran'), findsOneWidget);
  });

  testWidgets('MusicMenuFlyout view info closes the submenu before opening', (
    tester,
  ) async {
    var dialogShown = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Stack(
                children: [
                  Builder(
                    builder: (context) {
                      return TextButton(
                        onPressed: () {
                          showMenuFlyout(
                            context,
                            position: const Offset(20, 20),
                            avoidPlayerBar: false,
                            items: buildMusicMenuFlyoutItems(
                              i18n: i18n,
                              songId: 1,
                              isFavorite: false,
                              isCurrentTrack: false,
                              isPlaying: false,
                              playlists: const [],
                              showSelect: false,
                              showPreference: false,
                              onPlay: () {},
                              onPause: () {},
                              onPlayNext: () {},
                              onAddToNowPlaying: () {},
                              onCreatePlaylist: () {},
                              onAddToPlaylist: (_) {},
                              onRemove: () {},
                              onToggleFavorite: () {},
                              onSetPreference: (_) {},
                              onSeeArtist: () {},
                              onSeeAlbum: () {},
                              onSeeMusicInfo:
                                  () => setState(() {
                                    dialogShown = true;
                                  }),
                              onSeeLyrics: () {},
                              onSeeAlbumArt: () {},
                              onSeeLocal: () {},
                              onSelect: () {},
                            ),
                          );
                        },
                        child: const Text('Open'),
                      );
                    },
                  ),
                  if (dialogShown) const Text('Music Info Dialog'),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('View')));
    await tester.pumpAndSettle();

    expect(find.text('See Music Info'), findsOneWidget);

    await tester.tap(find.text('See Music Info'));
    await tester.pumpAndSettle();

    expect(find.text('View'), findsNothing);
    expect(find.text('See Music Info'), findsNothing);
    expect(find.text('Music Info Dialog'), findsOneWidget);
  });

  testWidgets('MenuFlyout hover highlights only the hovered root item', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'first',
                        text: 'First',
                        onPressed: () {},
                      ),
                      MenuFlyoutItem(
                        key: 'second',
                        text: 'Second',
                        onPressed: () {},
                      ),
                      MenuFlyoutItem(
                        key: 'third',
                        text: 'Third',
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('Second')));
    await tester.pumpAndSettle();

    expect(
      _menuFlyoutItemDecorationWithText(tester, 'First').color,
      Colors.transparent,
    );
    expect(
      _menuFlyoutItemDecorationWithText(tester, 'Second').color,
      MenuFlyoutThemeColors.light.hoverSurface,
    );
    expect(
      _menuFlyoutItemDecorationWithText(tester, 'Third').color,
      Colors.transparent,
    );
  });

  testWidgets('MenuFlyout hover does not rebuild the glass panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'first',
                        text: 'First',
                        onPressed: () {},
                      ),
                      MenuFlyoutItem(
                        key: 'second',
                        text: 'Second',
                        onPressed: () {},
                      ),
                      MenuFlyoutItem(
                        key: 'third',
                        text: 'Third',
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final glassPanel = tester.widget<GlassContainer>(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('Second')));
    await tester.pump();

    expect(
      tester.widget<GlassContainer>(
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
      ),
      same(glassPanel),
    );
    expect(
      _menuFlyoutItemDecorationWithText(tester, 'Second').color,
      MenuFlyoutThemeColors.light.hoverSurface,
    );

    await gesture.moveTo(tester.getCenter(find.text('Third')));
    await tester.pump();

    expect(
      tester.widget<GlassContainer>(
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
      ),
      same(glassPanel),
    );
    expect(
      _menuFlyoutItemDecorationWithText(tester, 'Second').color,
      Colors.transparent,
    );
    expect(
      _menuFlyoutItemDecorationWithText(tester, 'Third').color,
      MenuFlyoutThemeColors.light.hoverSurface,
    );
  });

  testWidgets('MenuFlyout items render above the glass layer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'first',
                        text: 'First',
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
        matching: find.text('First'),
      ),
      findsNothing,
    );
  });

  testWidgets('MenuFlyout hover has no implicit row animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'first',
                        text: 'First',
                        onPressed: () {},
                      ),
                      MenuFlyoutItem(
                        key: 'second',
                        text: 'Second',
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MenuFlyoutPanel.0.2')),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'MenuFlyout submenu hover highlights only the active branch and item',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    showMenuFlyout(
                      context,
                      position: const Offset(8, 8),
                      avoidPlayerBar: false,
                      items: [
                        MenuFlyoutItem(
                          key: 'parent',
                          text: 'Parent',
                          submenu: [
                            MenuFlyoutItem(
                              key: 'child-a',
                              text: 'Child A',
                              onPressed: () {},
                            ),
                            MenuFlyoutItem(
                              key: 'child-b',
                              text: 'Child B',
                              onPressed: () {},
                            ),
                            MenuFlyoutItem(
                              key: 'child-c',
                              text: 'Child C',
                              onPressed: () {},
                            ),
                          ],
                        ),
                        MenuFlyoutItem(
                          key: 'sibling',
                          text: 'Sibling',
                          onPressed: () {},
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.text('Parent')));
      await tester.pumpAndSettle();
      await gesture.moveTo(tester.getCenter(find.text('Child B')));
      await tester.pumpAndSettle();

      expect(
        _menuFlyoutItemDecorationWithText(tester, 'Parent').color,
        MenuFlyoutThemeColors.light.hoverSurface,
      );
      expect(
        _menuFlyoutItemDecorationWithText(tester, 'Sibling').color,
        Colors.transparent,
      );
      expect(
        _menuFlyoutItemDecorationWithText(tester, 'Child A').color,
        Colors.transparent,
      );
      expect(
        _menuFlyoutItemDecorationWithText(tester, 'Child B').color,
        MenuFlyoutThemeColors.light.hoverSurface,
      );
      expect(
        _menuFlyoutItemDecorationWithText(tester, 'Child C').color,
        Colors.transparent,
      );
    },
  );

  testWidgets('MenuFlyout submenu item hover does not rebuild glass panels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    position: const Offset(8, 8),
                    avoidPlayerBar: false,
                    items: [
                      MenuFlyoutItem(
                        key: 'parent',
                        text: 'Parent',
                        submenu: [
                          MenuFlyoutItem(
                            key: 'child-a',
                            text: 'Child A',
                            onPressed: () {},
                          ),
                          MenuFlyoutItem(
                            key: 'child-b',
                            text: 'Child B',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('Parent')));
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(find.text('Child A')));
    await tester.pump();
    final glassPanels =
        tester
            .widgetList<GlassContainer>(
              find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
            )
            .toList();

    expect(glassPanels, hasLength(2));

    await gesture.moveTo(tester.getCenter(find.text('Child B')));
    await tester.pump();
    final movedGlassPanels =
        tester
            .widgetList<GlassContainer>(
              find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
            )
            .toList();

    expect(movedGlassPanels[0], same(glassPanels[0]));
    expect(movedGlassPanels[1], same(glassPanels[1]));
    expect(
      _menuFlyoutItemDecorationWithText(tester, 'Child A').color,
      Colors.transparent,
    );
    expect(
      _menuFlyoutItemDecorationWithText(tester, 'Child B').color,
      MenuFlyoutThemeColors.light.hoverSurface,
    );
  });

  testWidgets('MenuFlyout does not scroll when all items fit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'first',
                        text: 'First',
                        onPressed: () {},
                      ),
                      MenuFlyoutItem(
                        key: 'second',
                        text: 'Second',
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('MenuFlyout root does not scroll like Electron root flyouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    position: const Offset(8, 8),
                    avoidPlayerBar: false,
                    items: [
                      for (var index = 0; index < 8; index += 1)
                        MenuFlyoutItem(
                          key: 'item-$index',
                          text: 'Item $index',
                          onPressed: () {},
                        ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('MenuFlyout submenu does not scroll when all items fit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    position: const Offset(8, 8),
                    avoidPlayerBar: false,
                    items: [
                      MenuFlyoutItem(
                        key: 'parent',
                        text: 'Parent',
                        submenu: [
                          for (var index = 0; index < 4; index += 1)
                            MenuFlyoutItem(
                              key: 'submenu-item-$index',
                              text: 'Submenu Item $index',
                              onPressed: () {},
                            ),
                        ],
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('Parent')));
    await tester.pumpAndSettle();

    expect(find.text('Submenu Item 0'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets(
    'MenuFlyout submenu scrolls when items exceed the available height',
    (tester) async {
      tester.view.physicalSize = const Size(320, 220);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    showMenuFlyout(
                      context,
                      position: const Offset(8, 8),
                      avoidPlayerBar: false,
                      items: [
                        MenuFlyoutItem(
                          key: 'parent',
                          text: 'Parent',
                          submenu: [
                            for (var index = 0; index < 8; index += 1)
                              MenuFlyoutItem(
                                key: 'submenu-item-$index',
                                text: 'Submenu Item $index',
                                onPressed: () {},
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.text('Parent')));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(Scrollable), findsOneWidget);
    },
  );

  test('MusicMenuFlyout filters Add To and closes View dialog actions', () {
    final items = buildMusicMenuFlyoutItems(
      i18n: i18n,
      songId: 1,
      isFavorite: false,
      isCurrentTrack: false,
      isPlaying: true,
      currentTrackId: 2,
      playlists: const [
        MultiSelectCommandBarPlaylist(
          id: 10,
          name: 'Already Has Song',
          songIds: [1],
        ),
        MultiSelectCommandBarPlaylist(id: 11, name: 'Mix', songIds: [2]),
      ],
      folders: const [
        MenuFlyoutFolder(
          id: 1,
          name: 'Rock',
          path: r'C:\Music\Rock',
          parentId: 0,
        ),
      ],
      showMoveToFolder: true,
      showHideFile: true,
      preferenceLevel: 'high',
      onPlay: () {},
      onPause: () {},
      onPlayNext: () {},
      onAddToNowPlaying: () {},
      onCreatePlaylist: () {},
      onAddToPlaylist: (_) {},
      onRemove: () {},
      onSelect: () {},
      onToggleFavorite: () {},
      onSetPreference: (_) {},
      onUndoPreference: () {},
      onMoveToFolder: (_) {},
      onDelete: () {},
      onHide: () {},
      onSeeArtist: () {},
      onSeeAlbum: () {},
      onSeeMusicInfo: () {},
      onSeeLyrics: () {},
      onSeeAlbumArt: () {},
      onSeeLocal: () {},
    );

    final addToItem = items.singleWhere((item) => item.key == 'add-to');
    expect(
      addToItem.submenu.map((item) => item.text),
      containsAll(['Now Playing', 'My Favorites', 'New Playlist', 'Mix']),
    );
    expect(
      addToItem.submenu.map((item) => item.text),
      isNot(contains('Already Has Song')),
    );

    expect(
      items.map((item) => item.key),
      containsAll(['select', 'preference', 'delete', 'hide-file', 'view']),
    );
    expect(
      items.singleWhere((item) => item.key == 'select').icon,
      FluentIcons.multiselect_ltr_20_regular,
    );
    final viewItem = items.singleWhere((item) => item.key == 'view');
    expect(viewItem.submenu.map((item) => item.text), [
      'See Artist',
      'See Album',
      'See Music Info',
      'See Lyrics',
      'See Album Art',
      'See In File Explorer',
    ]);
    expect(
      viewItem.submenu
          .where(
            (item) => {
              'see-music-info',
              'see-lyrics',
              'see-album-art',
            }.contains(item.key),
          )
          .map((item) => item.keepOpen),
      everyElement(isFalse),
    );
  });

  test('MusicMenuFlyout hides View when music properties are disabled', () {
    final items = buildMusicMenuFlyoutItems(
      i18n: i18n,
      songId: 1,
      isFavorite: false,
      isCurrentTrack: false,
      isPlaying: true,
      currentTrackId: 2,
      playlists: const [],
      showMusicProperties: false,
      onPlay: () {},
      onPause: () {},
      onPlayNext: () {},
      onAddToNowPlaying: () {},
      onCreatePlaylist: () {},
      onAddToPlaylist: (_) {},
      onRemove: () {},
      onSelect: () {},
      onToggleFavorite: () {},
      onSetPreference: (_) {},
      onSeeArtist: () {},
      onSeeAlbum: () {},
      onSeeMusicInfo: () {},
      onSeeLyrics: () {},
      onSeeAlbumArt: () {},
      onSeeLocal: () {},
    );

    expect(items.map((item) => item.key), isNot(contains('view')));
  });

  test('MusicMenuFlyout can hide artist and album View actions', () {
    final items = buildMusicMenuFlyoutItems(
      i18n: i18n,
      songId: 1,
      isFavorite: false,
      isCurrentTrack: false,
      isPlaying: true,
      currentTrackId: 2,
      playlists: const [],
      showSeeArtistsAndSeeAlbum: false,
      onPlay: () {},
      onPause: () {},
      onPlayNext: () {},
      onAddToNowPlaying: () {},
      onCreatePlaylist: () {},
      onAddToPlaylist: (_) {},
      onRemove: () {},
      onSelect: () {},
      onToggleFavorite: () {},
      onSetPreference: (_) {},
      onSeeArtist: () {},
      onSeeAlbum: () {},
      onSeeMusicInfo: () {},
      onSeeLyrics: () {},
      onSeeAlbumArt: () {},
      onSeeLocal: () {},
    );

    final viewItem = items.singleWhere((item) => item.key == 'view');
    expect(viewItem.submenu.map((item) => item.key), [
      'see-music-info',
      'see-lyrics',
      'see-album-art',
      'see-local',
    ]);
  });

  test(
    'songsRemovedUndoMessage mirrors Electron single and count messages',
    () {
      const songsById = {
        1: LibrarySong(
          id: 1,
          path: '/music/first.mp3',
          title: 'First',
          artist: 'Artist',
          artists: ['Artist'],
          album: 'Album',
          duration: 100,
          playCount: 1,
          lyricsOffsetMs: 0,
          dateAdded: '2026-01-01',
          favorite: true,
          thumbnailPath: '',
        ),
        2: LibrarySong(
          id: 2,
          path: '/music/second.mp3',
          title: 'Second',
          artist: 'Artist',
          artists: ['Artist'],
          album: 'Album',
          duration: 100,
          playCount: 1,
          lyricsOffsetMs: 0,
          dateAdded: '2026-01-01',
          favorite: true,
          thumbnailPath: '',
        ),
      };

      expect(
        songsRemovedUndoMessage(
          i18n: i18n,
          songIds: const [1],
          songsById: songsById,
          target: 'My Favorites',
        ),
        'Removed First from My Favorites',
      );
      expect(
        songsRemovedUndoMessage(
          i18n: i18n,
          songIds: const [1, 2],
          songsById: songsById,
          target: 'Mix',
        ),
        'Removed 2 songs from Mix',
      );
    },
  );
}

void _noop() {}

Future<void> _pumpMultiSelectCommandBar(
  WidgetTester tester, {
  required SmPlayerI18n i18n,
  required double width,
  bool visible = true,
  Brightness brightness = Brightness.light,
  double bottomInset = 0,
  double horizontalBleed = 0,
  double? leftBleed,
  double? rightBleed,
  int selectedCount = 3,
  MultiSelectCommandBarAddToMenuPosition addToMenuPosition =
      MultiSelectCommandBarAddToMenuPosition.aboveButton,
  bool includeNowPlayingInAddTo = true,
  bool includeFavoritesInAddTo = true,
  VoidCallback? onCreatePlaylist = _noop,
  ValueChanged<int>? onAddToPlaylist,
}) async {
  tester.view.physicalSize = Size(width, 420);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    SmPlayerI18nScope(
      i18n: i18n,
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: MultiSelectCommandBar(
                    visible: visible,
                    bottomInset: bottomInset,
                    horizontalBleed: horizontalBleed,
                    leftBleed: leftBleed,
                    rightBleed: rightBleed,
                    selectedCount: selectedCount,
                    addToSongIds: const [1, 2, 3],
                    playlists:
                        onAddToPlaylist == null
                            ? const []
                            : const [
                              MultiSelectCommandBarPlaylist(
                                id: 10,
                                name: 'Mix',
                                songIds: [],
                              ),
                            ],
                    includeNowPlayingInAddTo: includeNowPlayingInAddTo,
                    includeFavoritesInAddTo: includeFavoritesInAddTo,
                    addToMenuPosition: addToMenuPosition,
                    onAddToNowPlaying: includeNowPlayingInAddTo ? _noop : null,
                    onToggleFavorite: includeFavoritesInAddTo ? _noop : null,
                    onCreatePlaylist: onCreatePlaylist,
                    onAddToPlaylist: onAddToPlaylist,
                    onPlay: () {},
                    onRemove: () {},
                    onSelectAll: () {},
                    onReverseSelection: () {},
                    onClearSelection: () {},
                    onCancel: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Container _multiSelectBarContainer(WidgetTester tester) {
  return tester.widget<Container>(
    find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
  );
}

ExcludeSemantics _multiSelectExcludeSemantics(WidgetTester tester) {
  return tester.widget<ExcludeSemantics>(
    find
        .ancestor(
          of: find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
          matching: find.byType(ExcludeSemantics),
        )
        .first,
  );
}

SmPlayerTextIconButton _buttonWithText(WidgetTester tester, String text) {
  return tester.widget<SmPlayerTextIconButton>(
    find
        .ancestor(
          of: find.text(text),
          matching: find.byType(SmPlayerTextIconButton),
        )
        .first,
  );
}

SmPlayerTextIconButton _buttonWithIcon(WidgetTester tester, IconData icon) {
  return tester.widget<SmPlayerTextIconButton>(
    find
        .ancestor(
          of: find.byIcon(icon),
          matching: find.byType(SmPlayerTextIconButton),
        )
        .first,
  );
}

Size _buttonSizeWithText(WidgetTester tester, String text) {
  return tester.getSize(
    find
        .ancestor(
          of: find.text(text),
          matching: find.byType(SmPlayerTextIconButton),
        )
        .first,
  );
}

List<double?> _buttonIconSizesWithText(WidgetTester tester, String text) {
  final button =
      find
          .ancestor(
            of: find.text(text),
            matching: find.byType(SmPlayerTextIconButton),
          )
          .first;
  return [
    for (final iconElement
        in find.descendant(of: button, matching: find.byType(Icon)).evaluate())
      tester
              .widget<Icon>(
                find.byElementPredicate((element) => element == iconElement),
              )
              .size ??
          tester
              .widgetList<IconTheme>(
                find.ancestor(
                  of: find.byElementPredicate(
                    (element) => element == iconElement,
                  ),
                  matching: find.byType(IconTheme),
                ),
              )
              .map((theme) => theme.data.size)
              .firstWhere((size) => size != null),
  ];
}

TextStyle _labelStyleForText(WidgetTester tester, String text) {
  final directStyle = tester.widget<Text>(find.text(text)).style;
  if (directStyle != null) {
    return directStyle;
  }
  return tester
      .widgetList<DefaultTextStyle>(
        find.ancestor(
          of: find.text(text),
          matching: find.byType(DefaultTextStyle),
        ),
      )
      .map((widget) => widget.style)
      .firstWhere((style) => style.fontSize == 13);
}

BoxDecoration _buttonDecorationWithText(WidgetTester tester, String text) {
  final decorations =
      tester
          .widgetList<DecoratedBox>(
            find.ancestor(
              of: find.text(text),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .toList();
  return decorations.firstWhere(
    (decoration) => decoration.boxShadow != null,
    orElse: () => decorations.first,
  );
}

BoxDecoration _buttonControlDecorationWithText(
  WidgetTester tester,
  String text,
) {
  final button =
      find
          .ancestor(
            of: find.text(text),
            matching: find.byType(SmPlayerTextIconButton),
          )
          .first;
  return tester
          .widget<DecoratedBox>(
            find.descendant(of: button, matching: find.byType(DecoratedBox)),
          )
          .decoration
      as BoxDecoration;
}

double _opacityForButtonText(WidgetTester tester, String text) {
  return tester
      .widgetList<Opacity>(
        find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
      )
      .map((opacity) => opacity.opacity)
      .firstWhere((opacity) => opacity != 1, orElse: () => 1);
}

bool _opacityContainsButtonShadow(WidgetTester tester, String text) {
  final opacity =
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first;
  return find
      .descendant(of: opacity, matching: find.byType(DecoratedBox))
      .evaluate()
      .isNotEmpty;
}

double _selectedCountBoxWidth(WidgetTester tester) {
  final selectedCountText =
      find.text('3 selected').evaluate().isNotEmpty
          ? find.text('3 selected')
          : find.text('已选择 3 项');
  return tester
      .getSize(
        find
            .ancestor(
              of: selectedCountText,
              matching: find.byType(ConstrainedBox),
            )
            .first,
      )
      .width;
}

int _separatorCountWithHeight(WidgetTester tester, double height) {
  return tester
      .widgetList<Container>(find.byType(Container))
      .where(
        (widget) =>
            widget.constraints ==
            BoxConstraints.tightFor(width: 1, height: height),
      )
      .length;
}

BoxDecoration _textIconButtonDecoration(WidgetTester tester, Finder scope) {
  return tester
          .widgetList<DecoratedBox>(
            find.descendant(of: scope, matching: find.byType(DecoratedBox)),
          )
          .firstWhere((box) => box.decoration is BoxDecoration)
          .decoration
      as BoxDecoration;
}

BoxDecoration _menuFlyoutItemDecorationWithText(
  WidgetTester tester,
  String text,
) {
  return tester
          .widget<Container>(
            find
                .ancestor(of: find.text(text), matching: find.byType(Container))
                .first,
          )
          .decoration
      as BoxDecoration;
}

Color? _textIconButtonIconColor(WidgetTester tester, Finder scope) {
  final icons = tester.widgetList<Icon>(
    find.descendant(of: scope, matching: find.byType(Icon)),
  );
  if (icons.isNotEmpty) {
    return icons.first.color;
  }
  return tester
      .widgetList<IconTheme>(
        find.descendant(of: scope, matching: find.byType(IconTheme)),
      )
      .last
      .data
      .color;
}
