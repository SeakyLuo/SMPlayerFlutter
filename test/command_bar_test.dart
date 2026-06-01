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
    await _pumpMultiSelectCommandBar(tester, i18n: i18n, width: 900);

    expect(multiSelectCommandBarScrollSpacer, 108);
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

    final cancel = _buttonWithText(tester, 'Cancel');
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
      cancel.style?.foregroundColor?.resolve({WidgetState.hovered}),
      CommandBarColors.accentStrong,
    );
    expect(_labelStyleForText(tester, 'Cancel').fontSize, 13);
    expect(_labelStyleForText(tester, 'Cancel').height, 1);
    expect(cancel.style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
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
    },
  );

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

    final addTo = _buttonWithText(tester, 'Add selected to');
    expect(_buttonSizeWithText(tester, 'Add selected to').height, 36);
    expect(
      addTo.style?.maximumSize?.resolve(<WidgetState>{}),
      const Size(88, 36),
    );
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

      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Cancel', skipOffstage: false), findsOneWidget);
      final opacity = tester
          .widgetList<AnimatedOpacity>(
            find.byType(AnimatedOpacity, skipOffstage: false),
          )
          .firstWhere((widget) => widget.opacity == 0);
      expect(opacity.opacity, 0);
      final slide = tester.widget<AnimatedSlide>(
        find.byType(AnimatedSlide, skipOffstage: false),
      );
      expect(slide.offset, const Offset(0, 1.1));
      final ignore = tester
          .widgetList<IgnorePointer>(
            find.byType(IgnorePointer, skipOffstage: false),
          )
          .firstWhere((widget) => widget.ignoring);
      expect(ignore.ignoring, isTrue);
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
    expect(find.byType(GlassContainer), findsOneWidget);
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

Future<void> _pumpMultiSelectCommandBar(
  WidgetTester tester, {
  required SmPlayerI18n i18n,
  required double width,
  bool visible = true,
  Brightness brightness = Brightness.light,
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
                    selectedCount: 3,
                    addToSongIds: const [1, 2, 3],
                    includeNowPlayingInAddTo: true,
                    includeFavoritesInAddTo: true,
                    onAddToNowPlaying: () {},
                    onToggleFavorite: () {},
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

TextButton _buttonWithText(WidgetTester tester, String text) {
  return tester.widget<TextButton>(
    find.ancestor(of: find.text(text), matching: find.byType(TextButton)).first,
  );
}

Size _buttonSizeWithText(WidgetTester tester, String text) {
  return tester.getSize(
    find.ancestor(of: find.text(text), matching: find.byType(TextButton)).first,
  );
}

TextStyle _labelStyleForText(WidgetTester tester, String text) {
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
