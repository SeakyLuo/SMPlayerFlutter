import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
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
    await _pumpMultiSelectCommandBar(tester, i18n: i18n, width: 1320);

    expect(multiSelectCommandBarScrollSpacer, 108);
    expect(multiSelectCommandBarCompactBreakpoint, 1260);
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
    expect(surfaceGlass.settings?.lightIntensity, 0.1);
    expect(surfaceGlass.settings?.glowIntensity, 0.04);
    expect(
      surfaceGlass.settings?.saturation,
      multiSelectCommandBarBackdropSaturation,
    );
    expect(surfaceGlass.settings?.standardOpacityMultiplier, 1);
    expect(bar.padding, const EdgeInsets.fromLTRB(26, 0, 18, 0));
    expect(_separatorCountWithHeight(tester, 28), greaterThanOrEqualTo(2));
    expect(_selectedCountBoxWidth(tester), 154);
    expect(_labelStyleForText(tester, '3 selected').fontSize, 13);
    expect(_labelStyleForText(tester, '3 selected').fontVariations, const [
      FontVariation.weight(760),
    ]);

    final cancel = _buttonWithIcon(tester, FluentIcons.dismiss_20_regular);
    expect(_buttonSizeWithText(tester, 'Cancel').height, 36);
    expect(
      cancel.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(72, 36),
    );
    expect(
      cancel.style?.padding?.resolve(<WidgetState>{}),
      const EdgeInsets.symmetric(horizontal: 12),
    );
    expect(
      cancel.style?.backgroundColor?.resolve(<WidgetState>{}),
      CommandBarColors.actionSurface,
    );
    expect(
      cancel.style?.backgroundColor?.resolve({WidgetState.hovered}),
      CommandBarColors.actionHoverSurface,
    );
    expect(
      cancel.style?.backgroundColor?.resolve({WidgetState.focused}),
      CommandBarColors.actionSurface,
    );
    expect(
      cancel.style?.foregroundColor?.resolve({WidgetState.hovered}),
      CommandBarColors.accentStrong,
    );
    expect(
      cancel.style?.foregroundColor?.resolve({WidgetState.focused}),
      CommandBarColors.textStrong,
    );
    expect(_labelStyleForText(tester, 'Cancel').fontSize, 13);
    expect(_labelStyleForText(tester, 'Cancel').height, 1);
    expect(_labelStyleForText(tester, 'Cancel').fontVariations, const [
      FontVariation.weight(640),
    ]);
    expect(cancel.style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
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
      expect(
        _buttonWithText(tester, label).style?.tapTargetSize,
        MaterialTapTargetSize.shrinkWrap,
      );
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
    'MultiSelectCommandBar shell inset mirrors Electron player-overlap bottom',
    (tester) async {
      await _pumpMultiSelectCommandBar(
        tester,
        i18n: i18n,
        width: 900,
        bottomInset: multiSelectCommandBarShellBottomInset,
      );

      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
      );
      expect(surfaceRect.bottom, 420 - multiSelectCommandBarShellBottomInset);
    },
  );

  testWidgets('MultiSelectCommandBar can bleed across padded page panels', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(
      tester,
      i18n: i18n,
      width: 900,
      horizontalBleed: 24,
    );

    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
    );
    expect(surfaceRect.left, -24);
    expect(surfaceRect.width, 948);
  });

  testWidgets('MultiSelectCommandBar supports asymmetric page panel bleed', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(
      tester,
      i18n: i18n,
      width: 900,
      leftBleed: 24,
      rightBleed: 18,
    );

    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
    );
    expect(surfaceRect.left, -24);
    expect(surfaceRect.right, 918);
    expect(surfaceRect.width, 942);
  });

  testWidgets(
    'MultiSelectCommandBar compact mode moves selection actions to More',
    (tester) async {
      await _pumpMultiSelectCommandBar(tester, i18n: i18n, width: 760);

      expect(find.text('Select All'), findsNothing);
      expect(find.text('Invert Selection'), findsNothing);
      expect(find.text('Clear Selection'), findsNothing);

      final more = tester.widget<IconButton>(
        find.byKey(const ValueKey('MultiSelectCommandBar.MoreButton')),
      );
      expect(
        more.style?.fixedSize?.resolve(<WidgetState>{}),
        const Size(44, 36),
      );
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
      find.ancestor(of: find.text('添加到'), matching: find.byType(TextButton)),
    );
    final moreRect = tester.getRect(
      find.byKey(const ValueKey('MultiSelectCommandBar.MoreButton')),
    );
    expect(addToRect.right, lessThan(moreRect.left));
    expect(
      _buttonWithText(
        tester,
        '添加到',
      ).style?.maximumSize?.resolve(<WidgetState>{}),
      const Size(double.infinity, 36),
    );
  });

  testWidgets(
    'MultiSelectCommandBar Chinese selection actions keep full labels',
    (tester) async {
      await _pumpMultiSelectCommandBar(tester, i18n: zhI18n, width: 1320);

      expect(tester.takeException(), isNull);
      expect(find.text('全选'), findsOneWidget);
      expect(find.text('反选'), findsOneWidget);
      expect(find.text('清除...'), findsOneWidget);

      final reverseRect = tester.getRect(
        find.ancestor(of: find.text('反选'), matching: find.byType(TextButton)),
      );
      final clearRect = tester.getRect(
        find.ancestor(
          of: find.text('清除...'),
          matching: find.byType(TextButton),
        ),
      );
      expect(reverseRect.right, lessThan(clearRect.left));
      expect(clearRect.right, lessThan(1320));
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
    await _pumpMultiSelectCommandBar(tester, i18n: i18n, width: 900);

    final addToFinder = find.text('Add selected to');
    final addToButton = find.ancestor(
      of: addToFinder,
      matching: find.byType(TextButton),
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
      width: 900,
      addToMenuPosition: MultiSelectCommandBarAddToMenuPosition.pointer,
    );

    final addToFinder = find.text('Add selected to');
    final addToButton = find.ancestor(
      of: addToFinder,
      matching: find.byType(TextButton),
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
      width: 900,
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

    final more = tester.widget<IconButton>(
      find.byKey(const ValueKey('MultiSelectCommandBar.MoreButton')),
    );
    expect(more.style?.fixedSize?.resolve(<WidgetState>{}), const Size(40, 36));
    expect(
      _multiSelectBarContainer(tester).padding,
      const EdgeInsets.fromLTRB(12, 0, 10, 0),
    );
    expect(_separatorCountWithHeight(tester, 28), 0);
    expect(_separatorCountWithHeight(tester, 26), 0);

    final cancel = _buttonWithIcon(tester, FluentIcons.dismiss_20_regular);
    expect(
      cancel.style?.fixedSize?.resolve(<WidgetState>{}),
      const Size(40, 36),
    );
    expect(cancel.style?.padding?.resolve(<WidgetState>{}), EdgeInsets.zero);

    final addTo = _buttonWithText(tester, 'Add selected to');
    expect(_buttonSizeWithText(tester, 'Add selected to').height, 36);
    expect(
      addTo.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(40, 36),
    );
    expect(
      addTo.style?.maximumSize?.resolve(<WidgetState>{}),
      const Size(88, 36),
    );
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
      width: 900,
      selectedCount: 0,
    );

    for (final label in [
      'Play Selected',
      'Add selected to',
      'Remove From List',
    ]) {
      expect(_buttonWithText(tester, label).onPressed, isNull);
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
        width: 900,
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
        width: 900,
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
      expect(
        padding.padding,
        const EdgeInsets.only(bottom: multiSelectCommandBarShellBottomInset),
      );

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
      expect(tester.getSize(motionFinder), const Size(942, 64));
    },
  );

  testWidgets('MultiSelectCommandBar night colors mirror Electron target', (
    tester,
  ) async {
    await _pumpMultiSelectCommandBar(
      tester,
      i18n: i18n,
      width: 900,
      brightness: Brightness.dark,
    );

    final play = _buttonWithText(tester, 'Play Selected');
    expect(
      play.style?.backgroundColor?.resolve(<WidgetState>{}),
      CommandBarColors.actionNightSurface,
    );
    expect(
      play.style?.backgroundColor?.resolve({WidgetState.hovered}),
      CommandBarColors.actionNightHoverSurface,
    );
    expect(
      play.style?.foregroundColor?.resolve(<WidgetState>{}),
      CommandBarColors.textNight,
    );
    expect(
      play.style?.foregroundColor?.resolve({WidgetState.hovered}),
      CommandBarColors.accentStrongNight,
    );
    expect(
      play.style?.foregroundColor?.resolve({WidgetState.focused}),
      CommandBarColors.textNight,
    );

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

  test(
    'MusicMenuFlyout mirrors Electron Add To filtering and View submenu',
    () {
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
        everyElement(isTrue),
      );
    },
  );

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

TextButton _buttonWithText(WidgetTester tester, String text) {
  return tester.widget<TextButton>(
    find.ancestor(of: find.text(text), matching: find.byType(TextButton)).first,
  );
}

TextButton _buttonWithIcon(WidgetTester tester, IconData icon) {
  return tester.widget<TextButton>(
    find
        .ancestor(of: find.byIcon(icon), matching: find.byType(TextButton))
        .first,
  );
}

Size _buttonSizeWithText(WidgetTester tester, String text) {
  return tester.getSize(
    find.ancestor(of: find.text(text), matching: find.byType(TextButton)).first,
  );
}

List<double?> _buttonIconSizesWithText(WidgetTester tester, String text) {
  final button =
      find
          .ancestor(of: find.text(text), matching: find.byType(TextButton))
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
  return tester
          .widget<DecoratedBox>(
            find
                .ancestor(
                  of: find.text(text),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration
      as BoxDecoration;
}

double _opacityForButtonText(WidgetTester tester, String text) {
  return tester
      .widget<Opacity>(
        find
            .ancestor(of: find.text(text), matching: find.byType(Opacity))
            .first,
      )
      .opacity;
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
  return tester
      .getSize(
        find
            .ancestor(
              of: find.text('3 selected'),
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
