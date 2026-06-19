import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/svg_icon.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/album_artwork_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar_colors.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode, SettingsSnapshot;
// ignore: depend_on_referenced_packages

void main() {
  testWidgets('MusicDialog resolves night mode colors for dialog content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.properties,
        brightness: Brightness.dark,
        onPlay: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _closeButtonSurface(tester).color,
      PopupDialogResolvedColors.dark.buttonSurface,
    );
    final dialogSurface = tester.widget<Container>(
      find.byKey(const ValueKey('popup-dialog-surface')),
    );
    final dialogDecoration = dialogSurface.decoration as BoxDecoration;
    expect(dialogDecoration.color, PopupDialogResolvedColors.dark.surface);
    final dialogBorder = dialogDecoration.border as Border;
    expect(dialogBorder.top.color, PopupDialogResolvedColors.dark.border);
    expect(dialogDecoration.boxShadow?.single.color, const Color(0x7a000000));
    expect(dialogDecoration.boxShadow?.single.blurRadius, 80);
    expect(dialogDecoration.boxShadow?.single.offset, const Offset(0, 26));
    final closeIcon = tester.widget<SvgIcon>(
      find.byKey(const ValueKey('popup-dialog-close-icon')),
    );
    expect(closeIcon.svg, contains('m4.09 4.22'));
    expect(
      find.byKey(const ValueKey('MusicDialog.ElectronIcon.info')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.ElectronIcon.lyrics')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.ElectronIcon.pictures')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.ElectronIcon.play')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.ElectronIcon.save')),
      findsOneWidget,
    );
    _expectElectronIconSvg(tester, 'info', 'M10.5 8.91');
    _expectElectronIconSvg(tester, 'lyrics', 'M15.4 13.84');
    _expectElectronIconSvg(tester, 'pictures', 'M14 7.5');
    _expectElectronIconSvg(tester, 'play', 'M17.22 8.69');
    _expectElectronIconSvg(tester, 'save', 'M3 5c0-1.1');

    final playButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Play'),
    );
    expect(
      playButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      const Color(0x0effffff),
    );
    expect(
      playButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
      PopupDialogResolvedColors.dark.textStrong,
    );
    final infoButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Music Info'),
    );
    expect(
      infoButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
      PopupDialogResolvedColors.dark.activeButtonText,
    );
    expect(
      infoButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      PopupDialogResolvedColors.dark.activeButtonSurface,
    );
    expect(find.text('Add'), findsNothing);

    final titleField = tester.widget<TextField>(find.byType(TextField).first);
    expect(
      titleField.decoration?.fillColor,
      PopupDialogResolvedColors.dark.fieldSurface,
    );
    expect(
      titleField.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 12),
    );
    expect(titleField.style?.color, PopupDialogResolvedColors.dark.text);
    expect(titleField.style?.fontSize, 16);
    expect(titleField.style?.fontWeight, FontWeight.w400);
    await tester.tap(find.widgetWithText(TextField, 'Current Song'));
    await tester.pumpAndSettle();
    final darkFocusedTitleFrame = _textFieldFrameDecoration(
      tester,
      'Current Song',
    );
    expect(
      darkFocusedTitleFrame.boxShadow,
      contains(const BoxShadow(color: Color(0x330078d7), spreadRadius: 3)),
    );
    expect(
      _textFieldFrameInsetTopHighlight(tester, 'Current Song')?.color,
      const Color(0x0effffff),
    );
    final fileTypeField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'MP3'),
    );
    expect(fileTypeField.enabled, isNot(false));
    expect(fileTypeField.readOnly, isTrue);
    expect(fileTypeField.showCursor, isFalse);
    expect(fileTypeField.enableInteractiveSelection, isTrue);
    expect(
      fileTypeField.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 12),
    );
    expect(
      fileTypeField.decoration?.fillColor,
      GlobalUI.readOnlyFieldBgColorNight,
    );
    expect(
      fileTypeField.style?.color,
      PopupDialogResolvedColors.dark.fieldDisabledText,
    );
    expect(
      _textFieldFrameInsetTopHighlight(tester, 'MP3')?.color,
      GlobalUI.readOnlyFieldInsetHighlightNight,
    );
    final artistField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Artist').first,
    );
    expect(
      artistField.decoration?.contentPadding,
      const EdgeInsets.fromLTRB(12, 0, 34, 0),
    );
    expect(tester.getSize(find.byType(TextField).first).height, 42);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('MusicDialog.PropertyList')))
          .height,
      926,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('MusicDialog.PropertyRow.Artist')))
          .height,
      42,
    );
    final infoRect = tester.getRect(
      find.widgetWithText(TextButton, 'Music Info'),
    );
    final lyricsRect = tester.getRect(
      find.widgetWithText(TextButton, 'Lyrics'),
    );
    final albumArtRect = tester.getRect(
      find.widgetWithText(TextButton, 'Album Art'),
    );
    expect(infoRect.width, 138);
    expect(lyricsRect.width, 138);
    expect(albumArtRect.width, 138);
    expect(lyricsRect.left, infoRect.right - 1);
    expect(albumArtRect.left, lyricsRect.right - 1);

    final titleLabel = tester.widget<Text>(find.text('Title'));
    expect(titleLabel.style?.color, PopupDialogResolvedColors.dark.textMuted);
  });

  testWidgets('MusicDialog icon names mirror Electron Fluent mappings', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository:
            _FakeMusicDialogRepository()
              ..propertiesArtists = const ['Artist', 'Guest'],
        initialMode: SongDialogMode.properties,
        currentTrackId: 1,
        isPlaying: true,
        onPlay: () {},
      ),
    );
    await tester.pumpAndSettle();

    _expectElectronIconSvg(tester, 'info', 'M10.5 8.91');
    _expectElectronIconSvg(tester, 'lyrics', 'M15.4 13.84');
    _expectElectronIconSvg(tester, 'pictures', 'M14 7.5');
    _expectElectronIconSvg(tester, 'pause', 'M5 2a2 2');
    _expectElectronIconSvg(tester, 'save', 'M3 5c0-1.1');
    _expectElectronIconSvg(tester, 'plus', 'M10 2.5c.28');
    _expectElectronIconSvg(tester, 'close', 'm4.09 4.22');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.lyrics,
        song: _secondSong,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Changed lyrics');
    await tester.pump();

    _expectElectronIconSvg(tester, 'search', 'M13.73 14.44');
    _expectElectronIconSvg(tester, 'import', 'M15.5 17a.5');
    _expectElectronIconSvg(tester, 'undo', 'M5 2.5a.5');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.albumArt,
        song: _librarySong(id: 3, title: 'Artwork Song', album: 'Album'),
      ),
    );
    await tester.pumpAndSettle();

    _expectElectronIconSvg(tester, 'edit', 'M17.18 2.93');
    _expectElectronIconSvg(tester, 'trash', 'M8.5 4h3');

    await tester.tap(find.widgetWithText(TextButton, 'Change Artwork'));
    await tester.pumpAndSettle();

    _expectElectronIconSvg(tester, 'musicLibrary', 'M2 3.5C2');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('MusicDialog icon action hover uses GlobalUI blue surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.properties,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final addArtistButton = tester.widget<SmPlayerTextIconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('MusicDialog.AddArtistButton')),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    expect(addArtistButton.showLabel, isFalse);
    expect(
      _textIconButtonDecoration(
        tester,
        find.byKey(const ValueKey('MusicDialog.AddArtistButton')),
      ).color,
      PopupDialogResolvedColors.dark.buttonSurface,
    );

    tester.binding.handlePointerEvent(
      PointerHoverEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(
          find.byKey(const ValueKey('MusicDialog.AddArtistButton')),
        ),
      ),
    );
    await tester.pump();

    expect(
      _textIconButtonDecoration(
        tester,
        find.byKey(const ValueKey('MusicDialog.AddArtistButton')),
      ).color,
      GlobalUI.buttonHoverBgColorNight,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(
        find.byKey(const ValueKey('MusicDialog.AddArtistButton')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets(
    'MusicDialog artist remove button hover uses GlobalUI blue surface',
    (tester) async {
      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository:
              _FakeMusicDialogRepository()
                ..propertiesArtists = const ['Artist', 'Guest'],
          initialMode: SongDialogMode.properties,
        ),
      );
      await tester.pumpAndSettle();

      var removeButton = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MusicDialog.ElectronIcon.close')),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(
        removeButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
        PopupDialogResolvedColors.light.textMuted,
      );
      expect(
        removeButton.style?.foregroundColor?.resolve(const <WidgetState>{
          WidgetState.hovered,
        }),
        PopupDialogResolvedColors.light.text,
      );
      expect(
        removeButton.style?.backgroundColor?.resolve(const <WidgetState>{
          WidgetState.hovered,
        }),
        GlobalUI.buttonHoverBgColorDay,
      );
      expect(removeButton.tooltip, 'Remove');

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository:
              _FakeMusicDialogRepository()
                ..propertiesArtists = const ['Artist', 'Guest'],
          initialMode: SongDialogMode.properties,
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();

      removeButton = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MusicDialog.ElectronIcon.close')),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(
        removeButton.style?.foregroundColor?.resolve(const <WidgetState>{
          WidgetState.hovered,
        }),
        PopupDialogResolvedColors.dark.text,
      );
      expect(
        removeButton.style?.backgroundColor?.resolve(const <WidgetState>{
          WidgetState.hovered,
        }),
        GlobalUI.buttonHoverBgColorNight,
      );
    },
  );

  testWidgets('MusicDialog skips property save when nothing changed', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.properties,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.updateSongPropertiesCount, 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('MusicDialog loading spinner mirrors Electron song dialog', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final lyricsCompleter = Completer<LyricsSnapshot>();
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository:
            _FakeMusicDialogRepository()
              ..getSongLyricsCompleter = lyricsCompleter,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pump();

    final spinner = find.byKey(const ValueKey('MusicDialog.LoadingSpinner'));
    expect(spinner, findsOneWidget);
    expect(tester.getSize(spinner), const Size(38, 38));
    expect(tester.getTopLeft(spinner), const Offset(581, 397));
    final progress = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: spinner,
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(progress.strokeWidth, 3);
    expect(progress.color, PopupDialogResolvedColors.light.accent);
    expect(
      progress.backgroundColor,
      PopupDialogResolvedColors.light.accent.withValues(alpha: 0.16),
    );
  });

  testWidgets('MusicDialog body scrollbar mirrors Electron overlay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.properties,
        onPlay: () {},
      ),
    );
    await tester.pumpAndSettle();

    final track = find.byKey(
      const ValueKey('MusicDialog.BodyScrollbar.Position'),
    );
    final thumb = find.byKey(const ValueKey('MusicDialog.BodyScrollbar.Thumb'));
    expect(track, findsOneWidget);
    expect(thumb, findsOneWidget);
    expect(find.byType(Scrollbar), findsNothing);
    expect(find.byType(RawScrollbar), findsNothing);
    expect(tester.getSize(track).width, 9);
    expect(tester.getSize(thumb).height, greaterThanOrEqualTo(38));
    expect(tester.getSize(thumb).width, 5);

    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('popup-dialog-surface')),
    );
    final trackRect = tester.getRect(track);
    expect(dialogRect.right - trackRect.right, 5);

    final thumbTopBefore = tester.getTopLeft(thumb).dy;
    await tester.drag(thumb, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(thumb).dy, greaterThan(thumbTopBefore));
  });

  testWidgets('MusicDialog mobile properties layout mirrors Electron grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.properties,
        onPlay: () {},
      ),
    );
    await tester.pumpAndSettle();

    final commandBarPadding = tester
        .widgetList<Padding>(
          find.ancestor(
            of: find.widgetWithText(TextButton, 'Play'),
            matching: find.byType(Padding),
          ),
        )
        .firstWhere(
          (padding) =>
              padding.padding == const EdgeInsets.fromLTRB(12, 0, 12, 12),
        );
    expect(commandBarPadding.padding, const EdgeInsets.fromLTRB(12, 0, 12, 12));
    final bodyScroll = tester.widget<SingleChildScrollView>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('MusicDialog.PropertyList')),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    expect(bodyScroll.padding, const EdgeInsets.fromLTRB(12, 0, 12, 28));

    final titleLabelRect = tester.getRect(find.text('Title'));
    final titleFieldRect = tester.getRect(
      find.widgetWithText(TextField, 'Current Song'),
    );
    expect(titleFieldRect.left, titleLabelRect.left);
    expect(titleFieldRect.top, greaterThan(titleLabelRect.bottom));

    final artistFieldRect = tester.getRect(
      find.widgetWithText(TextField, 'Artist').first,
    );
    final addArtistRect = tester.getRect(
      find
          .ancestor(
            of: find.byKey(const ValueKey('MusicDialog.ElectronIcon.plus')),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(addArtistRect.top, greaterThan(artistFieldRect.bottom));
    expect(addArtistRect.left, artistFieldRect.left);
  });

  testWidgets(
    'MusicDialog text fields use restored read-only chrome and focus ring',
    (tester) async {
      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: _FakeMusicDialogRepository(),
          initialMode: SongDialogMode.properties,
        ),
      );
      await tester.pumpAndSettle();

      final titleFrameBefore = _textFieldFrameDecoration(
        tester,
        'Current Song',
      );
      expect(
        titleFrameBefore.boxShadow,
        contains(
          const BoxShadow(
            color: Color(0x0a253143),
            offset: Offset(0, 8),
            blurRadius: 18,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(TextField, 'Current Song'));
      await tester.pumpAndSettle();

      final titleFrameFocused = _textFieldFrameDecoration(
        tester,
        'Current Song',
      );
      expect(
        titleFrameFocused.boxShadow,
        contains(const BoxShadow(color: Color(0x290078d7), spreadRadius: 3)),
      );

      final fileTypeFrame = _textFieldFrameDecoration(tester, 'MP3');
      expect(fileTypeFrame.boxShadow, isEmpty);
      expect(
        _textFieldFrameInsetTopHighlight(tester, 'Current Song')?.color,
        const Color(0xa6ffffff),
      );
      expect(
        _textFieldFrameInsetTopHighlight(tester, 'MP3')?.color,
        GlobalUI.readOnlyFieldInsetHighlightDay,
      );
      final fileTypeField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'MP3'),
      );
      expect(fileTypeField.enabled, isNot(false));
      expect(fileTypeField.readOnly, isTrue);
      expect(fileTypeField.showCursor, isFalse);
      expect(fileTypeField.enableInteractiveSelection, isTrue);
      expect(
        fileTypeField.decoration?.contentPadding,
        const EdgeInsets.symmetric(horizontal: 12),
      );
      expect(
        fileTypeField.decoration?.fillColor,
        GlobalUI.readOnlyFieldBgColorDay,
      );
      final fileTypeDisabledBorder =
          fileTypeField.decoration?.disabledBorder as OutlineInputBorder?;
      expect(
        fileTypeDisabledBorder?.borderSide.color,
        GlobalUI.readOnlyFieldBorderColorDay,
      );
      expect(
        fileTypeField.style?.color,
        PopupDialogResolvedColors.light.fieldDisabledText,
      );
      _expectElectronSelectionColor(
        _textSelectionThemeForTextField(tester, 'Current Song').selectionColor,
      );
    },
  );

  testWidgets('MusicDialog lyrics textarea uses Electron selection color', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    _expectElectronSelectionColor(
      _textSelectionThemeForTextField(
        tester,
        '[00:01.00]Original line',
      ).selectionColor,
    );
  });

  testWidgets('MusicDialog lyrics textarea uses only custom scrollbar', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()
          ..lyricsRawText = List.generate(
            80,
            (index) => '[00:${index.toString().padLeft(2, '0')}.00]Line $index',
          ).join('\n');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('MusicDialog.LyricsScrollbar.Position')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.LyricsScrollbar.Thumb')),
      findsOneWidget,
    );
    expect(find.byType(RawScrollbar), findsNothing);
  });

  testWidgets('MusicDialog formats readonly tag lists like Electron', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()
          ..propertiesComposers = 'Composer A, Composer B'
          ..propertiesGenre = 'Pop, Rock';

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.properties,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Composer A、Composer B'), findsOneWidget);
    expect(find.text('Pop、Rock'), findsOneWidget);
    expect(find.text('2026/1/1 08:00:00'), findsNWidgets(2));
  });

  testWidgets(
    'MusicDialog normalizes artists and numeric fields like Electron',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..propertiesArtists = ['Artist; Other', 'artist', '第三|第四'];

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.properties,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Renamed Song');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('TrackNumberTextBox')),
          matching: find.byType(TextField),
        ),
        '12a3',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('YearTextBox')),
          matching: find.byType(TextField),
        ),
        '20x26',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.lastPropertiesUpdate?.artists, [
        'Artist',
        'Other',
        '第三',
        '第四',
      ]);
      expect(repository.lastPropertiesUpdate?.artist, 'Artist, Other, 第三, 第四');
      expect(repository.lastPropertiesUpdate?.trackNumber, 123);
      expect(repository.lastPropertiesUpdate?.year, 2026);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('MusicDialog loads embedded lyrics like Electron', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.lastSongLyricsMode, LyricsRequestMode.embedded);
  });

  testWidgets('MusicDialog ignores stale lyrics load after song switch', (
    tester,
  ) async {
    final firstLyrics = Completer<LyricsSnapshot>();
    final secondLyrics = Completer<LyricsSnapshot>();
    final repository =
        _FakeMusicDialogRepository()
          ..getSongLyricsCompleters.addAll([firstLyrics, secondLyrics]);

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        song: _secondSong,
      ),
    );
    await tester.pump();

    secondLyrics.complete(
      const LyricsSnapshot(
        source: LyricsSource.lrcFile,
        isSynced: true,
        rawText: '[00:02.00]Second song line',
        lines: [LyricsLine(id: 0, timestampMs: 2000, text: 'Second song line')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[00:02.00]Second song line'), findsOneWidget);

    firstLyrics.complete(
      const LyricsSnapshot(
        source: LyricsSource.lrcFile,
        isSynced: true,
        rawText: '[00:01.00]Stale first song line',
        lines: [
          LyricsLine(id: 0, timestampMs: 1000, text: 'Stale first song line'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[00:02.00]Second song line'), findsOneWidget);
    expect(find.text('[00:01.00]Stale first song line'), findsNothing);
  });

  testWidgets(
    'MusicDialog song switch lyrics failure keeps previous text like Electron',
    (tester) async {
      final failedLyrics = Completer<LyricsSnapshot>();
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('[00:01.00]Original line'), findsOneWidget);

      repository.getSongLyricsCompleters.add(failedLyrics);
      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          song: _secondSong,
        ),
      );
      await tester.pump();

      failedLyrics.completeError(StateError('lyrics failed'));
      await tester.pumpAndSettle();

      expect(find.text('[00:01.00]Original line'), findsOneWidget);
      expect(
        find.text('Failed to get lyrics. Please try again later.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('MusicDialog shows no-lyrics placeholder only for none source', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()
          ..lyricsSource = LyricsSource.none
          ..lyricsRawText = '';

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Lyrics'), findsOneWidget);

    repository
      ..lyricsSource = LyricsSource.lrcFile
      ..lyricsRawText = '';
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        song: _secondSong,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Lyrics'), findsNothing);
  });

  testWidgets('MusicDialog keeps properties available when lyrics load fails', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository()..failLyricsLoad = true;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.properties,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current Song'), findsOneWidget);
    expect(
      find.text('Failed to get lyrics. Please try again later.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog keeps property loading state on property load failure',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()..failPropertiesLoad = true;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.properties,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey('MusicDialog.LoadingSpinner')),
        findsOneWidget,
      );
      expect(find.text('Update failed'), findsNothing);
    },
  );

  testWidgets(
    'MusicDialog switches same-song mode without reloading like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.properties,
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.getSongPropertiesCount, 1);

      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.albumArt,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtFallbackShell')),
        findsOneWidget,
      );
      expect(repository.getSongPropertiesCount, 1);
    },
  );

  testWidgets(
    'MusicDialog shows property reset only when dirty like Electron',
    (tester) async {
      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: _FakeMusicDialogRepository(),
          initialMode: SongDialogMode.properties,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Reset'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Renamed Song');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
    },
  );

  testWidgets('MusicDialog clear play count waits for property save', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository()..propertiesPlayCount = 3;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.properties,
      ),
    );
    await tester.pumpAndSettle();

    final clearButton = tester.widget<SmPlayerTextIconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('MusicDialog.ClearPlayCountButton')),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    expect(clearButton.onPressed, isNotNull);
    expect(clearButton.tooltip, 'Reset to 0');
    expect(find.byTooltip('Reset to 0'), findsOneWidget);
    _expectElectronIconSvg(tester, 'undo', 'M5 2.5a.5');

    await tester.tap(
      find.byKey(const ValueKey('MusicDialog.ClearPlayCountButton')),
    );
    await tester.pumpAndSettle();

    final saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(saveButton.onPressed, isNotNull);
    expect(repository.updateSongPlayCountCount, 0);
    expect(repository.updateSongPropertiesCount, 0);
    expect(find.widgetWithText(TextField, '0'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('MusicDialog.ClearPlayCountButton')),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    expect(repository.updateSongPlayCountCount, 0);
    expect(repository.updateSongPropertiesCount, 0);

    await tester.tap(
      find.byKey(const ValueKey('MusicDialog.ClearPlayCountButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(repository.updateSongPlayCountCount, 0);
    expect(repository.updateSongPropertiesCount, 1);
    expect(repository.lastPropertiesUpdate?.playCount, 0);
    expect(
      find.byKey(const ValueKey('MusicDialog.ClearPlayCountButton')),
      findsNothing,
    );
  });

  testWidgets('MusicDialog inline property actions keep Electron row layout', (
    tester,
  ) async {
    String? revealedPath;
    final repository = _FakeMusicDialogRepository()..propertiesPlayCount = 3;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.properties,
        onReveal: (path) {
          revealedPath = path;
        },
      ),
    );
    await tester.pumpAndSettle();

    final playCountFieldRect = tester.getRect(
      find.widgetWithText(TextField, '3'),
    );
    expect(
      find.byTooltip('"Current Song" has been played 3 times.'),
      findsOneWidget,
    );
    final clearButtonRect = tester.getRect(
      find.byKey(const ValueKey('MusicDialog.ClearPlayCountButton')),
    );
    expect(clearButtonRect.height, 40);
    expect(playCountFieldRect.height, 42);

    expect(find.widgetWithText(TextButton, 'Show in Explorer'), findsNothing);
    expect(find.byTooltip('Show in Explorer'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('MusicDialog.ElectronIcon.folder')),
      findsOneWidget,
    );
    final revealButtonRect = tester.getRect(
      find.byKey(const ValueKey('MusicDialog.ShowInExplorerButton')),
    );
    final pathFieldRect = tester.getRect(
      find.widgetWithText(TextField, 'song.mp3'),
    );
    final pathField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'song.mp3'),
    );
    final revealButton = tester.widget<SmPlayerTextIconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('MusicDialog.ShowInExplorerButton')),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    expect(revealButton.tooltip, 'Show in Explorer');
    expect(pathField.enabled, isNot(false));
    expect(pathField.readOnly, isTrue);
    expect(pathField.showCursor, isFalse);
    expect(pathField.enableInteractiveSelection, isTrue);
    expect(
      pathField.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 12),
    );
    expect(revealButtonRect.height, 40);
    expect(revealButtonRect.width, 42);
    expect(pathFieldRect.height, 42);

    await tester.ensureVisible(find.byTooltip('Show in Explorer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show in Explorer'));
    await tester.pump();

    expect(revealedPath, 'song.mp3');
  });

  testWidgets('MusicDialog title can use filename when it differs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.properties,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('MusicDialog.UseFileNameButton')),
      findsOneWidget,
    );
    expect(find.byTooltip('Sync to filename "song"'), findsOneWidget);
    final useFileNameButton = tester.widget<SmPlayerTextIconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('MusicDialog.UseFileNameButton')),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    expect(useFileNameButton.tooltip, 'Sync to filename "song"');
    _expectElectronIconSvg(tester, 'refresh', 'M4.97 4.97');

    await tester.tap(
      find.byKey(const ValueKey('MusicDialog.UseFileNameButton')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'song'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('MusicDialog.UseFileNameButton')),
      findsNothing,
    );
  });

  testWidgets('MusicDialog shows zero play count without clear action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository()..propertiesPlayCount = 0,
        initialMode: SongDialogMode.properties,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('MusicDialog.ClearPlayCountButton')),
      findsNothing,
    );
    expect(
      find.byTooltip('"Current Song" has not been played yet.'),
      findsOneWidget,
    );
  });

  testWidgets('MusicDialog hides add artist button after six artists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository:
            _FakeMusicDialogRepository()
              ..propertiesArtists = const [
                'Artist 1',
                'Artist 2',
                'Artist 3',
                'Artist 4',
                'Artist 5',
                'Artist 6',
              ],
        initialMode: SongDialogMode.properties,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('MusicDialog.ElectronIcon.plus')),
      findsNothing,
    );
    expect(find.widgetWithText(TextField, 'Artist 6'), findsOneWidget);
  });

  testWidgets('MusicDialog disabled command buttons keep Electron chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository =
        _FakeMusicDialogRepository()
          ..updateSongPropertiesCompleter = Completer<void>();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.properties,
        onPlay: () {},
      ),
    );
    await tester.pumpAndSettle();

    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('popup-dialog-surface')),
    );
    final playRect = tester.getRect(find.widgetWithText(TextButton, 'Play'));
    final cleanSaveRect = tester.getRect(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(
      dialogRect.right - cleanSaveRect.right,
      moreOrLessEquals(32, epsilon: 1),
    );
    expect(
      cleanSaveRect.left - playRect.right,
      moreOrLessEquals(6, epsilon: 1),
    );

    await tester.enterText(find.byType(TextField).first, 'Renamed Song');
    await tester.pumpAndSettle();
    final resetRect = tester.getRect(find.widgetWithText(TextButton, 'Reset'));
    final dirtySaveRect = tester.getRect(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(
      resetRect.left - dirtySaveRect.right,
      moreOrLessEquals(6, epsilon: 1),
    );
    expect(
      dialogRect.right - resetRect.right,
      moreOrLessEquals(32, epsilon: 1),
    );

    final activeSaveShadowBox = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.widgetWithText(TextButton, 'Save').first,
            matching: find.byWidgetPredicate((widget) {
              if (widget is! DecoratedBox) {
                return false;
              }
              final decoration = widget.decoration;
              return decoration is BoxDecoration &&
                  decoration.boxShadow?.isNotEmpty == true;
            }),
          )
          .first,
    );
    final activeSaveShadowDecoration =
        activeSaveShadowBox.decoration as BoxDecoration;
    expect(activeSaveShadowDecoration.borderRadius, BorderRadius.circular(10));
    final activeSaveShadow = activeSaveShadowDecoration.boxShadow!.single;
    expect(activeSaveShadow.color.a, moreOrLessEquals(0.26));
    expect(activeSaveShadow.color.r, 0);
    expect(activeSaveShadow.color.g, moreOrLessEquals(120 / 255));
    expect(activeSaveShadow.color.b, moreOrLessEquals(215 / 255));
    expect(activeSaveShadow.offset, const Offset(0, 10));
    expect(activeSaveShadow.blurRadius, 22);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('MusicDialog.SaveProgress')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('MusicDialog.SaveProgress')))
          .height,
      3,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('MusicDialog.SaveProgress')))
          .width,
      0,
    );
    final progressPadding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('MusicDialog.SaveProgress')),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(progressPadding.padding, const EdgeInsets.only(top: 2));

    final playButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Play'),
    );
    _expectElectronIconSvg(tester, 'play', 'M17.22 8.69');
    _expectElectronIconSvg(tester, 'save', 'M3 5c0-1.1');
    _expectElectronIconSvg(tester, 'undo', 'M5 2.5a.5');
    final playButtonStack =
        find
            .ancestor(
              of: find.widgetWithText(TextButton, 'Play'),
              matching: find.byType(Stack),
            )
            .first;
    expect(
      find.descendant(
        of: playButtonStack,
        matching: find.byKey(
          const ValueKey('MusicDialog.CommandButtonInsetHighlight'),
        ),
      ),
      findsOneWidget,
    );
    final playInsetHighlight = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: playButtonStack,
            matching: find.byKey(
              const ValueKey('MusicDialog.CommandButtonInsetHighlight'),
            ),
          )
          .first,
    );
    final playInsetDecoration = playInsetHighlight.decoration as BoxDecoration;
    expect(playInsetDecoration.color, const Color(0x6bffffff));
    final commandBar = tester.widget<Row>(
      find
          .ancestor(
            of: find.widgetWithText(TextButton, 'Play'),
            matching: find.byType(Row),
          )
          .first,
    );
    expect(commandBar.mainAxisSize, MainAxisSize.min);
    final commandBarBox = tester.widget<ConstrainedBox>(
      find
          .ancestor(
            of: find.widgetWithText(TextButton, 'Play'),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(commandBarBox.constraints.minHeight, 48);
    expect(
      find.ancestor(
        of: find.widgetWithText(TextButton, 'Play'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == const EdgeInsets.fromLTRB(28, 0, 28, 18),
        ),
      ),
      findsOneWidget,
    );
    expect(
      playButton.style?.backgroundColor?.resolve(const <WidgetState>{
        WidgetState.disabled,
      }),
      const Color(0x8fffffff),
    );
    expect(
      playButton.style?.foregroundColor?.resolve(const <WidgetState>{
        WidgetState.disabled,
      }),
      PopupDialogResolvedColors.light.textStrong,
    );
    expect(
      playButton.style?.backgroundColor?.resolve(const <WidgetState>{
        WidgetState.hovered,
      }),
      GlobalUI.buttonHoverBgColorDay,
    );
    expect(
      playButton.style?.foregroundColor?.resolve(const <WidgetState>{
        WidgetState.hovered,
      }),
      PopupDialogResolvedColors.light.textStrong,
    );
    expect(
      playButton.style?.minimumSize?.resolve(const <WidgetState>{}),
      const Size(44, 40),
    );
    expect(
      playButton.style?.padding?.resolve(const <WidgetState>{}),
      const EdgeInsets.symmetric(horizontal: 14),
    );
    final playShape =
        playButton.style?.shape?.resolve(const <WidgetState>{})
            as RoundedRectangleBorder?;
    expect(playShape?.borderRadius, BorderRadius.circular(10));
    expect(playShape?.side.color, const Color(0x24536379));

    final saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(
      saveButton.style?.backgroundColor?.resolve(const <WidgetState>{
        WidgetState.disabled,
      }),
      const Color(0xc7e6ebf3),
    );
    final saveShape =
        saveButton.style?.shape?.resolve(const <WidgetState>{
              WidgetState.disabled,
            })
            as RoundedRectangleBorder?;
    expect(saveShape?.side.color, const Color(0x619ba6b6));
    expect(
      saveButton.style?.backgroundColor?.resolve(const <WidgetState>{
        WidgetState.disabled,
        WidgetState.hovered,
      }),
      const Color(0xc7e6ebf3),
    );
    expect(
      saveButton.style?.foregroundColor?.resolve(const <WidgetState>{
        WidgetState.disabled,
        WidgetState.hovered,
      }),
      const Color(0xb85e6773),
    );
    final disabledSaveOpacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.widgetWithText(TextButton, 'Save'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(disabledSaveOpacity.opacity, 0.45);

    repository.updateSongPropertiesCompleter!.complete();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('MusicDialog.SaveProgress')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog dark command button hover uses GlobalUI blue surface',
    (tester) async {
      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: _FakeMusicDialogRepository(),
          initialMode: SongDialogMode.properties,
          brightness: Brightness.dark,
          onPlay: () {},
        ),
      );
      await tester.pumpAndSettle();

      final playButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Play'),
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.CommandButtonInsetHighlight')),
        findsNothing,
      );
      expect(
        playButton.style?.backgroundColor?.resolve(const <WidgetState>{
          WidgetState.hovered,
        }),
        GlobalUI.buttonHoverBgColorNight,
      );
      expect(
        playButton.style?.foregroundColor?.resolve(const <WidgetState>{
          WidgetState.hovered,
        }),
        PopupDialogResolvedColors.dark.textStrong,
      );
    },
  );

  testWidgets('MusicDialog offers pending lyrics save when song changes', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();
    var savedCurrentDialogSong = false;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        onSaved: () {
          savedCurrentDialogSong = true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Edited pending line');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        song: _secondSong,
        onSaved: () {
          savedCurrentDialogSong = true;
        },
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'The lyrics of "Current Song" have been changed but not saved.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Save Immediately'));
    await tester.pumpAndSettle();

    expect(repository.savedLyricsSongId, 1);
    expect(repository.savedLyrics, 'Edited pending line');
    expect(savedCurrentDialogSong, isFalse);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(MusicDialog)),
      ).read(lyricsSavedEventProvider)?.songId,
      1,
    );
    expect(
      find.text(
        'The lyrics of "Current Song" have been updated. Now showing the lyrics of "Match Song".',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog pending lyrics discard after song change leaves current song like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Edited old song');

      repository.lyricsRawText = '[00:02.00]Second song line';
      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          song: _secondSong,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The lyrics of "Current Song" have been changed but not saved.',
        ),
        findsOneWidget,
      );
      expect(find.text('[00:02.00]Second song line'), findsOneWidget);

      await tester.tap(find.text('Discard Changes'));
      await tester.pump();

      expect(repository.saveSongLyricsCount, 0);
      expect(find.text('Edited old song'), findsNothing);
      expect(find.text('[00:01.00]Original line'), findsNothing);
      expect(find.text('[00:02.00]Second song line'), findsOneWidget);
      expect(find.text('Lyrics reset'), findsNothing);
    },
  );

  testWidgets('MusicDialog pending lyrics save failure mirrors Electron', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository()..failSaveSongLyrics = true;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Edited pending line');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        song: _secondSong,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Save Immediately'));
    await tester.pumpAndSettle();

    expect(repository.saveSongLyricsCount, 1);
    expect(repository.savedLyricsSongId, isNull);
    expect(repository.savedLyrics, isEmpty);
    expect(find.text('Update failed'), findsOneWidget);
    expect(
      find.text(
        'The lyrics of "Current Song" have been updated. Now showing the lyrics of "Match Song".',
      ),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog pending current lyrics save failure keeps dirty editor like Electron',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()..failSaveSongLyrics = true;
      var closed = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          currentTrackId: _currentSong.id,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Edited current line',
      );

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          currentTrackId: _secondSong.id,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Save Immediately'));
      await tester.pumpAndSettle();

      expect(repository.saveSongLyricsCount, 1);
      expect(find.text('Update failed'), findsOneWidget);
      expect(find.text('Edited current line'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
      expect(closed, isFalse);
    },
  );

  testWidgets(
    'MusicDialog does not offer pending lyrics save outside lyrics tab',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Edited hidden line');

      await tester.tap(find.widgetWithText(TextButton, 'Music Info'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.properties,
          song: _secondSong,
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'The lyrics of "Current Song" have been changed but not saved.',
        ),
        findsNothing,
      );
      expect(repository.savedLyricsSongId, isNull);
    },
  );

  testWidgets('MusicDialog clean lyrics close skips confirm like Electron', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();
    var closed = false;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        onClose: () {
          closed = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(find.text('Discard unsaved lyrics changes?'), findsNothing);
  });

  testWidgets('MusicDialog clean lyrics Escape closes like Electron stack', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();
    var closed = false;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        onClose: () {
          closed = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(find.text('Discard unsaved lyrics changes?'), findsNothing);
  });

  testWidgets('MusicDialog close confirm uses PopupConfirm like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeMusicDialogRepository();
    var closed = false;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        onClose: () {
          closed = true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Dirty lyrics');

    await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
    expect(closed, isFalse);
    final confirmSurfaceRect = tester.getRect(
      find.byKey(const ValueKey('popup-input-dialog-surface')),
    );
    expect(confirmSurfaceRect.width, 480);
    final confirmTitle = tester.widget<Text>(find.text('Confirm').first);
    expect(confirmTitle.style?.fontSize, 22);
    expect(confirmTitle.style?.fontWeight, FontWeight.w700);
    expect(confirmTitle.style?.height, 1.25);
    final confirmMessage = tester.widget<Text>(
      find.text('Discard unsaved lyrics changes?'),
    );
    expect(confirmMessage.textAlign, TextAlign.center);
    expect(confirmMessage.style?.fontSize, 15);
    expect(confirmMessage.style?.fontWeight, isNull);
    expect(confirmMessage.style?.height, 1.55);
    final confirmButtonRect = tester.getRect(
      find.widgetWithText(TextButton, 'Confirm').last,
    );
    final cancelButtonRect = tester.getRect(
      find.widgetWithText(TextButton, 'Cancel').last,
    );
    expect(confirmButtonRect.height, 36);
    expect(cancelButtonRect.height, 36);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved lyrics changes?'), findsNothing);
    expect(closed, isFalse);

    await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Confirm').last);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets(
    'MusicDialog dirty lyrics close confirms outside lyrics tab like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var closed = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Dirty lyrics');

      await tester.tap(find.widgetWithText(TextButton, 'Music Info'));
      await tester.pumpAndSettle();
      expect(find.text('Title'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
      expect(closed, isFalse);

      await tester.tap(find.widgetWithText(TextButton, 'Confirm').last);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    },
  );

  testWidgets(
    'MusicDialog dirty lyrics Escape opens one confirm like Electron stack',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var closed = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Dirty lyrics');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
      expect(closed, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Lyrics'), findsOneWidget);
      expect(closed, isFalse);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved lyrics changes?'), findsNothing);
      expect(closed, isFalse);
    },
  );

  testWidgets(
    'MusicDialog offers pending lyrics save when current track leaves',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var saved = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          currentTrackId: _currentSong.id,
          onSaved: () {
            saved = true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Edited current line',
      );

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          currentTrackId: _secondSong.id,
          onSaved: () {
            saved = true;
          },
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'The lyrics of "Current Song" have been changed but not saved.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Save Immediately'));
      await tester.pump();

      expect(repository.savedLyricsSongId, 1);
      expect(repository.savedLyrics, 'Edited current line');
      expect(saved, isTrue);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('MusicDialog clears pending lyrics after save like Electron', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        currentTrackId: _currentSong.id,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Edited current line');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        currentTrackId: _secondSong.id,
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'The lyrics of "Current Song" have been changed but not saved.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Save Immediately'));
    await tester.pumpAndSettle();

    expect(repository.saveSongLyricsCount, 1);
    expect(repository.savedLyrics, 'Edited current line');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        currentTrackId: _currentSong.id,
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
        currentTrackId: _secondSong.id,
      ),
    );
    await tester.pump();

    expect(repository.saveSongLyricsCount, 1);
    expect(
      find.text(
        'The lyrics of "Current Song" have been changed but not saved.',
      ),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog does not offer pending lyrics save when dialog song was not current like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Edited background line',
      );

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          currentTrackId: _secondSong.id,
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'The lyrics of "Current Song" have been changed but not saved.',
        ),
        findsNothing,
      );
      expect(repository.saveSongLyricsCount, 0);
    },
  );

  testWidgets(
    'MusicDialog pending lyrics discard restores text without reset notice',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..lyricsRawText = List.generate(
              80,
              (index) =>
                  '[00:${index.toString().padLeft(2, '0')}.00]Line $index',
            ).join('\n');

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          currentTrackId: _currentSong.id,
        ),
      );
      await tester.pumpAndSettle();
      final lyricsField = tester.widget<TextField>(find.byType(TextField).last);
      final scrollController = lyricsField.scrollController!;
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pump();
      final beforeOffset = scrollController.offset;
      expect(beforeOffset, greaterThan(0));

      await tester.enterText(
        find.byType(TextField).last,
        'Edited current line',
      );
      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          currentTrackId: _secondSong.id,
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'The lyrics of "Current Song" have been changed but not saved.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Discard Changes'));
      await tester.pump();

      expect(find.text('Edited current line'), findsNothing);
      expect(find.text(repository.lyricsRawText), findsOneWidget);
      expect(find.text('Lyrics reset'), findsNothing);
      expect(scrollController.offset, beforeOffset);
    },
  );

  testWidgets('MusicDialog preserves timed lyrics when timestamps are hidden', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[00:01.00]Original line'), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
          )
          .height,
      48,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MusicDialog.LyricsTimestampCheckboxBox')),
      ),
      const Size(18, 18),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 8,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('Original line'), findsOneWidget);
    expect(find.text('[00:01.00]Original line'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'Edited line');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedLyrics, '[00:01.00]Edited line');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog timestamp toggle restores edited timed text like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Edited line');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.text('[00:01.00]Edited line'), findsOneWidget);
      expect(find.text('Edited line'), findsNothing);
      expect(repository.saveSongLyricsCount, 0);
    },
  );

  testWidgets(
    'MusicDialog visible timestamp edits update toggle source like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).last,
        'Untimed manual line',
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedLyrics, 'Untimed manual line');
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('MusicDialog timestamp toggle does not scroll lyrics to top', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()
          ..lyricsRawText = List.generate(
            80,
            (index) => '[00:${index.toString().padLeft(2, '0')}.00]Line $index',
          ).join('\n');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    final lyricsField = tester.widget<TextField>(find.byType(TextField).last);
    final scrollController = lyricsField.scrollController!;
    scrollController.jumpTo(80);
    await tester.pump();
    expect(scrollController.offset, 80);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(find.textContaining('[00:00.00]'), findsNothing);
    expect(find.textContaining('Line 0'), findsOneWidget);
    expect(scrollController.offset, 80);
  });

  testWidgets(
    'MusicDialog song switch keeps raw loaded lyrics when timestamps are hidden like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository =
          _FakeMusicDialogRepository()
            ..lyricsRawText = '[00:01.00]Original line';

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Original line'), findsOneWidget);
      expect(find.text('[00:01.00]Original line'), findsNothing);

      repository.lyricsRawText = '[00:02.00]Second song line';
      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          song: _secondSong,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('[00:02.00]Second song line'), findsOneWidget);
      expect(find.text('Second song line'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
    },
  );

  testWidgets('MusicDialog unchanged lyrics save mirrors Electron notice', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedLyrics, isEmpty);
    expect(find.text('No changes were detected.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog lyrics save success clears dirty state like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var saved = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          onSaved: () {
            saved = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Saved manual lyric');
      await tester.pump();
      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.saveSongLyricsCount, 1);
      expect(repository.savedLyricsSongId, 1);
      expect(repository.savedLyrics, 'Saved manual lyric');
      expect(saved, isTrue);
      expect(
        find.text('The lyrics of "Current Song" have been updated!'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Reset'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog lyrics save failure keeps dirty state like Electron',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()..failSaveSongLyrics = true;
      var saved = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          onSaved: () {
            saved = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        'Failed manual lyric',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.saveSongLyricsCount, 1);
      expect(repository.savedLyricsSongId, isNull);
      expect(repository.savedLyrics, isEmpty);
      expect(saved, isFalse);
      expect(find.text('Update failed'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);

      repository.failSaveSongLyrics = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.saveSongLyricsCount, 2);
      expect(repository.savedLyricsSongId, 1);
      expect(repository.savedLyrics, 'Failed manual lyric');
      expect(saved, isTrue);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog lyrics save keeps current snapshot source like Electron',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..lyricsSource = LyricsSource.none
            ..lyricsRawText = '';

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .decoration
            ?.hintText,
        'No Lyrics',
      );

      await tester.enterText(find.byType(TextField).last, 'Manual lyric');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedLyrics, 'Manual lyric');

      await tester.enterText(find.byType(TextField).last, '');
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .decoration
            ?.hintText,
        'No Lyrics',
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('MusicDialog saving lyrics reports processing like Electron', (
    tester,
  ) async {
    final saveCompleter = Completer<void>();
    final repository =
        _FakeMusicDialogRepository()..saveSongLyricsCompleter = saveCompleter;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Edited saving line');
    await tester.tap(find.text('Save'));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.text('Processing'), findsOneWidget);
    expect(repository.internetLyricsRequested, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.text('Processing'), findsOneWidget);
    expect(repository.internetLyricsRequested, isFalse);

    saveCompleter.complete();
    await tester.pumpAndSettle();
    expect(repository.savedLyrics, 'Edited saving line');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog disables lyrics controls while saving like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final saveCompleter = Completer<void>();
      final repository =
          _FakeMusicDialogRepository()..saveSongLyricsCompleter = saveCompleter;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        '[00:02.00]Edited saving line',
      );
      await tester.tap(find.text('Save'));
      await tester.pump();

      for (final label in ['Search', 'Import', 'Save', 'Reset']) {
        await _expectMusicDialogCommandEnabled(tester, label, false);
      }
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        false,
      );
      final lyricsField = tester.widget<TextField>(find.byType(TextField).last);
      expect(lyricsField.decoration?.fillColor, const Color(0xade6ebf3));
      final lyricsDisabledBorder =
          lyricsField.decoration?.disabledBorder as OutlineInputBorder?;
      expect(lyricsDisabledBorder?.borderSide.color, const Color(0x6bbec8d6));
      final lyricsFrame = _textFieldFrameDecoration(
        tester,
        '[00:02.00]Edited saving line',
      );
      expect(lyricsFrame.boxShadow, isEmpty);
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('MusicDialog.SaveProgress')))
            .width,
        0,
      );

      saveCompleter.complete();
      await tester.pumpAndSettle();
      expect(repository.savedLyrics, '[00:02.00]Edited saving line');
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog lyrics commandbar keeps Save visible at Electron desktop width',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.CommandBar.MoreButton')),
        findsNothing,
      );
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MusicDialog dirty timed lyrics commandbar stays inline at Electron desktop width',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        '[00:01.00]Original line edited',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.CommandBar.MoreButton')),
        findsNothing,
      );
      expect(find.widgetWithText(TextButton, 'Search'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Import'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
            )
            .height,
        48,
      );
    },
  );

  testWidgets(
    'MusicDialog mobile lyrics commandbar keeps Save visible like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 820);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.CommandBar.MoreButton')),
        findsNothing,
      );
      expect(find.widgetWithText(TextButton, 'Search'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Import'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MusicDialog mobile dirty timed lyrics commandbar stays inline like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 820);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        '[00:01.00]Mobile dirty line',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.CommandBar.MoreButton')),
        findsNothing,
      );
      expect(find.widgetWithText(TextButton, 'Search'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Import'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MusicDialog lyrics commandbar overflows into More like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 760);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        '[00:01.00]Narrow dirty line',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.CommandBar.MoreButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('MusicDialog.CommandBar.MoreButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(repository.savedLyrics, '[00:01.00]Narrow dirty line');
      expect(
        find.text('The lyrics of "Current Song" have been updated!'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog re-enables lyrics controls after save like Electron',
    (tester) async {
      final saveCompleter = Completer<void>();
      final repository =
          _FakeMusicDialogRepository()..saveSongLyricsCompleter = saveCompleter;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Edited saving line');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isFalse,
      );
      saveCompleter.complete();
      await tester.pumpAndSettle();

      for (final label in ['Search', 'Import', 'Save']) {
        await _expectMusicDialogCommandEnabled(tester, label, true);
      }
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsNothing,
      );
      expect(find.widgetWithText(TextButton, 'Reset'), findsNothing);
      expect(repository.savedLyrics, 'Edited saving line');
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog re-enables lyrics controls after search like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final searchCompleter = Completer<LyricsSnapshot>();
      final repository =
          _FakeMusicDialogRepository()
            ..getInternetLyricsCompleter = searchCompleter;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pump();

      for (final label in ['Search', 'Import', 'Save']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNull, reason: '$label should be disabled');
      }
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsOneWidget,
      );

      searchCompleter.complete(
        const LyricsSnapshot(
          source: LyricsSource.internet,
          isSynced: true,
          rawText: '[00:05.00]Searched line',
          lines: [LyricsLine(id: 0, timestampMs: 5000, text: 'Searched line')],
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['Search', 'Import', 'Save']) {
        await _expectMusicDialogCommandEnabled(tester, label, true);
      }
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).onChanged,
        isNotNull,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsNothing,
      );
      expect(find.text('[00:05.00]Searched line'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog re-enables lyrics controls after search fallback like Electron',
    (tester) async {
      final searchCompleter = Completer<LyricsSnapshot>();
      final repository =
          _FakeMusicDialogRepository()
            ..getInternetLyricsCompleter = searchCompleter;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pump();

      for (final label in ['Search', 'Import', 'Save']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNull, reason: '$label should be disabled');
      }
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsOneWidget,
      );

      searchCompleter.completeError(StateError('internet lyrics failed'));
      await tester.pumpAndSettle();

      for (final label in ['Search', 'Import', 'Save']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNotNull, reason: '$label should be enabled');
      }
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsNothing,
      );
      expect(repository.openedLyricsSearchSongIds, [1]);
      expect(find.text('Browser opened.'), findsOneWidget);
      expect(find.text('[00:01.00]Original line'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog re-enables lyrics controls after search fallback failure like Electron',
    (tester) async {
      final searchCompleter = Completer<LyricsSnapshot>();
      final repository =
          _FakeMusicDialogRepository()
            ..getInternetLyricsCompleter = searchCompleter
            ..failOpenLyricsSearch = true;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pump();

      for (final label in ['Search', 'Import', 'Save']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNull, reason: '$label should be disabled');
      }
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsOneWidget,
      );

      searchCompleter.completeError(StateError('internet lyrics failed'));
      await tester.pumpAndSettle();

      for (final label in ['Search', 'Import', 'Save']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNotNull, reason: '$label should be enabled');
      }
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsNothing,
      );
      expect(repository.openedLyricsSearchSongIds, [1]);
      expect(find.text('No matching lyrics found.'), findsOneWidget);
      expect(find.text('[00:01.00]Original line'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('MusicDialog lyrics loading state mirrors Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final lyricsCompleter = Completer<LyricsSnapshot>();
    final repository =
        _FakeMusicDialogRepository()..getSongLyricsCompleter = lyricsCompleter;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pump();

    for (final label in ['Search', 'Import', 'Save']) {
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, label),
      );
      expect(button.onPressed, isNull, reason: '$label should be disabled');
    }
    expect(find.byType(Checkbox), findsNothing);
    expect(
      find.byKey(const ValueKey('MusicDialog.SaveProgress')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.LoadingSpinner')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);

    lyricsCompleter.complete(
      const LyricsSnapshot(
        source: LyricsSource.lrcFile,
        isSynced: true,
        rawText: '[00:01.00]Original line',
        lines: [LyricsLine(id: 0, timestampMs: 1000, text: 'Original line')],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('MusicDialog.CommandBar.MoreButton')),
      findsNothing,
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNotNull);
    expect(
      find.byKey(const ValueKey('MusicDialog.SaveProgress')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.LoadingSpinner')),
      findsNothing,
    );
    expect(
      find.widgetWithText(TextField, '[00:01.00]Original line'),
      findsOneWidget,
    );
  });

  testWidgets('MusicDialog reset scrolls lyrics editor to top like Electron', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()
          ..lyricsRawText = List.generate(
            80,
            (index) => 'Line $index',
          ).join('\n');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();
    final lyricsTextField = tester.widget<TextField>(
      find.byType(TextField).last,
    );
    expect(lyricsTextField.style?.fontSize, 16);
    expect(lyricsTextField.style?.fontWeight, FontWeight.w400);
    expect(lyricsTextField.style?.height, 1.7);
    final scrollController = lyricsTextField.scrollController!;
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();
    expect(scrollController.offset, greaterThan(0));

    await tester.enterText(
      find.byType(TextField).last,
      '${repository.lyricsRawText}\nDirty tail',
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(scrollController.offset, 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('MusicDialog lyrics scrollbar mirrors Electron overlay', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()
          ..lyricsRawText = List.generate(
            80,
            (index) =>
                '[00:${(index + 1).toString().padLeft(2, '0')}.00]Line $index',
          ).join('\n');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    final scrollController =
        tester.widget<TextField>(find.byType(TextField).last).scrollController!;
    expect(scrollController.position.maxScrollExtent, greaterThan(1));

    final track = find.byKey(
      const ValueKey('MusicDialog.LyricsScrollbar.Position'),
    );
    final thumb = find.byKey(
      const ValueKey('MusicDialog.LyricsScrollbar.Thumb'),
    );
    expect(track, findsOneWidget);
    expect(thumb, findsOneWidget);
    expect(tester.getSize(track).width, 9);
    expect(tester.getSize(thumb).height, greaterThanOrEqualTo(38));
    expect(tester.getSize(thumb).width, 5);

    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('popup-dialog-surface')),
    );
    final trackRect = tester.getRect(track);
    expect(dialogRect.right - trackRect.right, 32);

    await tester.drag(thumb, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(scrollController.offset, greaterThan(0));
  });

  testWidgets('MusicDialog mobile lyrics body mirrors Electron padding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository:
            _FakeMusicDialogRepository()
              ..lyricsRawText = List.generate(
                48,
                (index) => 'Line ${index + 1}',
              ).join('\n'),
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    final track = find.byKey(
      const ValueKey('MusicDialog.LyricsScrollbar.Position'),
    );
    final textFieldFrame =
        find
            .ancestor(
              of: find.byType(TextField).last,
              matching: find.byKey(
                const ValueKey('MusicDialog.DialogTextFieldFrame'),
              ),
            )
            .first;
    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('popup-dialog-surface')),
    );
    final trackRect = tester.getRect(track);
    final frameRect = tester.getRect(textFieldFrame);

    expect(dialogRect.right - trackRect.right, 15);
    expect(frameRect.left - dialogRect.left, 12);
    expect(dialogRect.right - frameRect.right, 12);
    expect(dialogRect.bottom - trackRect.bottom, 28);
  });

  testWidgets('MusicDialog album art loading uses Electron cover shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.albumArt,
      ),
    );

    final shell = find.byKey(
      const ValueKey('MusicDialog.AlbumArtLoadingShell'),
    );
    expect(shell, findsOneWidget);
    expect(tester.getSize(shell), const Size(340, 340));
    final shellBox = tester.widget<DecoratedBox>(
      find.descendant(of: shell, matching: find.byType(DecoratedBox)).first,
    );
    final shellDecoration = shellBox.decoration as BoxDecoration;
    expect(shellDecoration.borderRadius, BorderRadius.circular(10));
    expect(shellDecoration.boxShadow?.single.blurRadius, 42);
    expect(shellDecoration.boxShadow?.single.offset, const Offset(0, 18));

    final spinner = find.descendant(
      of: shell,
      matching: find.byKey(const ValueKey('MusicDialog.LoadingSpinner')),
    );
    expect(spinner, findsOneWidget);
    expect(tester.getSize(spinner), const Size(38, 38));

    await tester.pumpAndSettle();
    final fallback = tester.widget<SizedBox>(
      find.byKey(const ValueKey('MusicDialog.AlbumArtFallbackShell')),
    );
    expect(fallback.width, 500);
    expect(fallback.height, 500);
    expect(fallback.child, isA<Stack>());
    expect(
      find.byKey(const ValueKey('MusicDialog.DefaultAlbumArtwork')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.DefaultAlbumArtworkLogo')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MusicDialog.AlbumArtFallbackShell')),
        matching: find.byType(Center),
      ),
      findsAtLeastNWidgets(1),
    );
    final noArtworkText = tester.widget<Text>(
      find
          .descendant(
            of: find.byKey(const ValueKey('MusicDialog.AlbumArtFallbackShell')),
            matching: find.text('No album art'),
          )
          .first,
    );
    expect(
      tester.getCenter(find.text('No album art')),
      tester.getCenter(
        find.byKey(const ValueKey('MusicDialog.AlbumArtFallbackShell')),
      ),
    );
    expect(noArtworkText.style?.color, PopupDialogResolvedColors.light.text);
    expect(noArtworkText.style?.fontSize, 16);
    expect(noArtworkText.style?.fontWeight, FontWeight.w400);
  });

  testWidgets('MusicDialog no album art fallback shows centered text only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository()..librarySongs = [_currentSong],
        initialMode: SongDialogMode.albumArt,
      ),
    );
    await tester.pumpAndSettle();

    final fallbackShell = find.byKey(
      const ValueKey('MusicDialog.AlbumArtFallbackShell'),
    );
    expect(fallbackShell, findsOneWidget);
    expect(
      find.byKey(const ValueKey('MusicDialog.DefaultAlbumArtwork')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.DefaultAlbumArtworkLogo')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
      findsNothing,
    );
    expect(find.text('No album art'), findsOneWidget);
    expect(
      tester.getCenter(find.text('No album art')),
      tester.getCenter(fallbackShell),
    );
  });

  testWidgets('MusicDialog resolves current artwork like Electron hook', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()..currentSongResolvedArtwork = true;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.albumArt,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('MusicDialog.AlbumArtFallbackShell')),
      findsNothing,
    );
    expect(find.text('No album art'), findsNothing);
    expect(
      find.byKey(const ValueKey('MusicDialog.AlbumArtworkImageShell')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MusicDialog.AlbumArtworkImageShell')),
        matching: find.byKey(
          const ValueKey('MusicDialog.AlbumArtworkImageShadow'),
        ),
      ),
      findsOneWidget,
    );
    final imageShellBox = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey('MusicDialog.AlbumArtworkImageShell'),
            ),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final imageShellDecoration = imageShellBox.decoration as BoxDecoration;
    expect(imageShellDecoration.color, const Color(0xb8ffffff));
    expect(imageShellDecoration.boxShadow, isNull);
  });

  testWidgets('AlbumArtEditorControl keeps artwork shell while loading', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestShell(
        repository: repository,
        child: AlbumArtEditorControl(
          title: 'Song',
          loading: true,
          saving: false,
          showBusy: true,
          artworkUrl: repository.recommendedArtworkPath,
          artworkDirty: false,
          fallbackArtwork: true,
          showDeleteConfirm: false,
          onChangeArtwork: () {},
          onSaveArtwork: () {},
          onRequestDelete: () {},
          onConfirmDelete: () {},
          onCancelDelete: () {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('MusicDialog.AlbumArtLoadingShell')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.AlbumArtworkImageShell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.AlbumArtworkLoadingOverlay')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
    final loadingArtworkOpacity = tester.widget<Opacity>(
      find.byWidgetPredicate(
        (widget) => widget is Opacity && widget.opacity == 0,
      ),
    );
    expect(loadingArtworkOpacity.opacity, 0);
  });

  testWidgets('MusicDialog mobile album art body mirrors Electron padding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.albumArt,
      ),
    );

    final loadingShell = find.byKey(
      const ValueKey('MusicDialog.AlbumArtLoadingShell'),
    );
    final loadingScroll = tester.widget<SingleChildScrollView>(
      find
          .ancestor(
            of: loadingShell,
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    expect(loadingScroll.padding, const EdgeInsets.fromLTRB(12, 0, 12, 28));

    await tester.pumpAndSettle();

    final fallbackShell = find.byKey(
      const ValueKey('MusicDialog.AlbumArtFallbackShell'),
    );
    final fallbackScroll = tester.widget<SingleChildScrollView>(
      find
          .ancestor(
            of: fallbackShell,
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    expect(fallbackScroll.padding, const EdgeInsets.fromLTRB(12, 0, 12, 28));
  });

  testWidgets('MusicDialog applies recommended library album art', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.albumArt,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Reset'), findsNothing);
    expect(
      find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
      findsOneWidget,
    );
    expect(find.text('No album art'), findsOneWidget);
    final recommendationLabel = tester.widget<Text>(find.text('No album art'));
    expect(
      recommendationLabel.style?.color,
      PopupDialogResolvedColors.light.text,
    );
    expect(recommendationLabel.style?.fontSize, 16);
    expect(recommendationLabel.style?.fontWeight, FontWeight.w400);
    expect(recommendationLabel.style?.height, 1.35);
    final recommendationButton = tester.widget<SizedBox>(
      find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendationButton')),
    );
    expect(recommendationButton.width, closeTo(281.4921875, 0.001));
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('MusicDialog.AlbumArtRecommendationButton'),
            ),
          )
          .height,
      40,
    );
    final recommendationButtonChrome = tester.widget<SizedBox>(
      find.byKey(
        const ValueKey('MusicDialog.AlbumArtRecommendationButtonChrome'),
      ),
    );
    expect(
      recommendationButtonChrome.key,
      const ValueKey('MusicDialog.AlbumArtRecommendationButtonChrome'),
    );
    expect(find.text('"Match Song"'), findsNothing);
    final recommendationLine = tester.widget<Text>(
      find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendationLine')),
    );
    expect(
      recommendationLine.data,
      'Smart match: use Artist\'s "Match Song" as the cover',
    );
    expect(recommendationLine.maxLines, 1);
    expect(recommendationLine.overflow, TextOverflow.ellipsis);
    expect(recommendationLine.softWrap, isFalse);
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('MusicDialog.AlbumArtRecommendationLine'),
            ),
          )
          .width,
      closeTo(220, 0.001),
    );
    expect(
      recommendationLine.style?.color,
      PopupDialogResolvedColors.light.text,
    );
    expect(recommendationLine.style?.fontSize, 16);
    expect(recommendationLine.style?.height, 1.35);
    expect(recommendationLine.style?.fontWeight, FontWeight.w400);
    final previewBefore = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendationPreview')),
    );
    expect(previewBefore.opacity, 0);

    await tester.ensureVisible(
      find.byKey(
        const ValueKey('MusicDialog.AlbumArtRecommendationButtonHitTarget'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('MusicDialog.AlbumArtRecommendationButtonHitTarget'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
      findsNothing,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedArtworkPath, repository.recommendedArtworkPath);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('MusicDialog saved artwork keeps Electron display source URL', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();
    final displayArtworkPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}smplayer-dialog-display-art.png';
    final sourceArtworkPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}smplayer-dialog-source-art.png';
    File(repository.recommendedArtworkPath).copySync(displayArtworkPath);
    File(repository.recommendedArtworkPath).copySync(sourceArtworkPath);
    repository.artworkSnapshotsCompleter =
        Completer<List<SongArtworkSnapshot>>()..complete([
          SongArtworkSnapshot(
            songId: 2,
            artworkUrl: displayArtworkPath,
            sourceUrl: displayArtworkPath,
            sourcePath: sourceArtworkPath,
            source: SongArtworkSource.cached,
          ),
        ]);

    await _openAlbumArtLibraryPicker(tester, repository);
    await tester.tap(find.text('Use this cover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedArtworkPath, sourceArtworkPath);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('MusicDialog.AlbumArtworkImageShell')),
        matching: find.byType(Image),
      ),
    );
    expect((image.image as FileImage).file.path, displayArtworkPath);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog save without pending album art is silent like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var savedCount = 0;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.albumArt,
          onSaved: () {
            savedCount += 1;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.savedArtworkPath, isEmpty);
      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.savedArtworkPath, isEmpty);
      expect(savedCount, 0);
      expect(find.text('New album art has been saved!'), findsNothing);
      expect(find.text('No changes were detected.'), findsNothing);
      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MusicDialog reset clears album art recommendation like Electron',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.albumArt,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('MusicDialog.AlbumArtRecommendationButtonHitTarget'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
        findsNothing,
      );

      final parentArtworkRequest = Completer<List<SongArtworkSnapshot>>();
      final recommendationArtworkRequest =
          Completer<List<SongArtworkSnapshot>>();
      repository.artworkSnapshotsCompletersByRequest.addAll({
        '1': parentArtworkRequest,
        '2': recommendationArtworkRequest,
      });
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(
        repository.artworkSnapshotRequests.any(
          (request) => request.length == 1 && request.single == 1,
        ),
        isTrue,
      );
      parentArtworkRequest.complete([
        const SongArtworkSnapshot(
          songId: 1,
          artworkUrl: '',
          sourceUrl: '',
          sourcePath: '',
          source: SongArtworkSource.none,
        ),
      ]);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
        findsNothing,
      );
      expect(
        repository.artworkSnapshotRequests.any(
          (request) => request.length == 1 && request.single == 2,
        ),
        isTrue,
      );
      recommendationArtworkRequest.complete([
        SongArtworkSnapshot(
          songId: 2,
          artworkUrl: repository.recommendedArtworkPath,
          sourceUrl: repository.recommendedArtworkPath,
          sourcePath: repository.recommendedArtworkPath,
          source: SongArtworkSource.cached,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('MusicDialog album art recommendation hover shows preview', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.albumArt,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(
        const ValueKey('MusicDialog.AlbumArtRecommendationButtonHitTarget'),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(
        find.byKey(
          const ValueKey('MusicDialog.AlbumArtRecommendationButtonHitTarget'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final preview = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendationPreview')),
    );
    expect(preview.opacity, 1);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendationPreview')),
      ),
      const Size(128, 128),
    );
  });

  testWidgets(
    'MusicDialog recommendation keeps Electron raw album comparison',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..librarySongs = [
              _librarySong(id: 1, title: 'Current Song', album: 'Album '),
              _librarySong(id: 2, title: 'Different Song', album: 'Album'),
            ];

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.albumArt,
          song: _librarySong(id: 1, title: 'Current Song', album: 'Album '),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('"Different Song"'), findsNothing);
    },
  );

  testWidgets('MusicDialog recommendation matches Electron unknown artists', (
    tester,
  ) async {
    final currentSong = _librarySong(
      id: 1,
      title: 'Current Song',
      album: 'Album',
      artist: '',
      artists: const [],
    );
    final recommendedSong = _librarySong(
      id: 2,
      title: 'Unknown Match',
      album: 'Album',
      artist: '',
      artists: const [],
    );
    final repository =
        _FakeMusicDialogRepository()
          ..librarySongs = [currentSong, recommendedSong];

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.albumArt,
        song: currentSong,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('"Unknown Match"'), findsNothing);
    expect(
      find.text(
        'Smart match: use Unknown Artist\'s "Unknown Match" as the cover',
      ),
      findsOneWidget,
    );
  });

  testWidgets('MusicDialog recommendation uses Electron title normalization', (
    tester,
  ) async {
    final currentSong = _librarySong(id: 1, title: '雨，夜', album: '');
    final recommendedSong = _librarySong(id: 2, title: '雨夜', album: '');
    final repository =
        _FakeMusicDialogRepository()
          ..librarySongs = [currentSong, recommendedSong];

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.albumArt,
        song: currentSong,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('"雨夜"'), findsNothing);
    expect(
      find.text('Smart match: use Artist\'s "雨夜" as the cover'),
      findsOneWidget,
    );
  });

  testWidgets(
    'MusicDialog album art recommendation does not repeat snapshot requests',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..librarySongs = [
              _currentSong,
              _librarySong(id: 3, title: 'Different Song', album: 'Album'),
            ];

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.albumArt,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pump();

      final recommendationRequests =
          repository.artworkSnapshotRequests
              .where((songIds) => songIds.length == 1 && songIds.single == 3)
              .length;
      expect(recommendationRequests, 1);
      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
        findsNothing,
      );
    },
  );

  testWidgets('MusicDialog album art source menu mirrors Electron flyout', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.albumArt,
      ),
    );
    await tester.pumpAndSettle();

    final changeArtworkButton = find.widgetWithText(
      TextButton,
      'Change Artwork',
    );
    final buttonRect = tester.getRect(changeArtworkButton);
    await tester.tap(changeArtworkButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('MenuFlyout.GlassPanel')), findsOneWidget);
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );
    expect(panelRect.top - buttonRect.bottom, closeTo(6, 0.1));
    expect(find.text('Choose local file'), findsOneWidget);
    expect(find.text('Choose from library'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('MusicDialog.ElectronIcon.pictures')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.ElectronIcon.musicLibrary')),
      findsOneWidget,
    );
    _expectElectronIconSvg(tester, 'musicLibrary', 'M2 3.5C2');
  });

  testWidgets('MusicDialog library artwork picker mirrors search history', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()
          ..recentSearches = const [
            SearchHistoryEntry(
              id: 7,
              query: 'History Query',
              type: SearchHistoryType.sidebar,
              searchedAt: '2026-06-05T00:00:00Z',
            ),
            SearchHistoryEntry(
              id: 8,
              query: 'Artist Query',
              type: SearchHistoryType.artists,
              searchedAt: '2026-06-05T00:00:00Z',
            ),
          ];

    await _openAlbumArtLibraryPicker(tester, repository);

    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistoryPanel')),
      findsOneWidget,
    );
    final historyPanel = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistoryPanel')),
    );
    final historyDecoration = historyPanel.decoration as BoxDecoration;
    expect(historyDecoration.color, const Color(0xf5f4f6f9));
    final historyBorder = historyDecoration.border as Border;
    expect(historyBorder.top.color, const Color(0x24536379));
    expect(historyBorder.top.width, 1);
    expect(historyDecoration.boxShadow, hasLength(1));
    expect(historyDecoration.boxShadow!.single.color, const Color(0x2935495f));
    expect(historyDecoration.boxShadow!.single.offset, const Offset(0, 18));
    expect(historyDecoration.boxShadow!.single.blurRadius, 36);
    expect(find.text('History Query'), findsOneWidget);
    expect(find.text('Artist Query'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistorySelect.7')),
    );
    await tester.pumpAndSettle();

    final searchField = tester.widget<TextField>(find.byType(TextField).last);
    expect(searchField.controller?.text, 'History Query');
    expect(repository.addedRecentSearchQuery, 'History Query');
    expect(repository.addedRecentSearchType, SearchHistoryType.sidebar);

    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistoryRemove.7')),
    );
    await tester.pump();
    expect(repository.removedRecentSearchIds, [7]);

    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(repository.clearRecentSearchCount, 1);
  });

  testWidgets(
    'MusicDialog library artwork picker dismisses search history like Electron',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..recentSearches = const [
              SearchHistoryEntry(
                id: 7,
                query: 'History Query',
                type: SearchHistoryType.sidebar,
                searchedAt: '2026-06-05T00:00:00Z',
              ),
            ];

      await _openAlbumArtLibraryPicker(tester, repository);
      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistoryPanel')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('AlbumArtLibraryPicker.SearchHistoryDismissLayer'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistoryPanel')),
        findsNothing,
      );
      expect(find.text('Use this cover'), findsOneWidget);
    },
  );

  testWidgets(
    'MusicDialog library artwork picker search does not match file path',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..librarySongs = [
              _currentSong,
              _librarySong(
                id: 2,
                title: 'Visible Cover',
                album: 'Album',
                path: 'secret-path.mp3',
              ),
            ];

      await _openAlbumArtLibraryPicker(tester, repository);
      expect(find.text('Visible Cover'), findsWidgets);

      await tester.enterText(find.byType(TextField).last, 'secret-path');
      await tester.pumpAndSettle();

      expect(find.text('Visible Cover'), findsNothing);
      expect(
        find.text('No available album art in the library'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MusicDialog library artwork picker ranks raw album matches like Electron',
    (tester) async {
      final currentSong = _librarySong(
        id: 1,
        title: 'Current Song',
        album: 'Album ',
      );
      final trimmedAlbumSong = _librarySong(
        id: 2,
        title: 'Trimmed Album Cover',
        album: 'Album',
        playCount: 5,
      );
      final rawAlbumSong = _librarySong(
        id: 3,
        title: 'Raw Album Cover',
        album: 'Album ',
        playCount: 0,
      );
      final repository =
          _FakeMusicDialogRepository()
            ..currentSongHasArtwork = true
            ..librarySongs = [currentSong, trimmedAlbumSong, rawAlbumSong];

      await _openAlbumArtLibraryPicker(
        tester,
        repository,
        song: currentSong,
        clearArtworkRequestsBeforeLibraryOpen: true,
      );

      expect(repository.artworkSnapshotRequests, [
        [3, 2],
      ]);
    },
  );

  testWidgets('MusicDialog library artwork picker loading uses Electron text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository =
        _FakeMusicDialogRepository()
          ..artworkSnapshotsCompleter = Completer<List<SongArtworkSnapshot>>();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.albumArt,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Change Artwork'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.Message')),
      findsOneWidget,
    );
    expect(find.text('Loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final listSize = tester.getSize(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.ListFrame')),
    );
    expect(listSize, const Size(544, 460));
    expect(
      tester.getSize(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.MessageText')),
      ),
      const Size(534, 23),
    );

    repository.artworkSnapshotsCompleter!.complete([
      SongArtworkSnapshot(
        songId: 2,
        artworkUrl: repository.recommendedArtworkPath,
        sourceUrl: repository.recommendedArtworkPath,
        sourcePath: repository.recommendedArtworkPath,
        source: SongArtworkSource.cached,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Loading'), findsNothing);
  });

  testWidgets('MusicDialog library artwork picker handles snapshot failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository =
        _FakeMusicDialogRepository()
          ..currentSongHasArtwork = true
          ..failArtworkSnapshots = true;

    await _openAlbumArtLibraryPicker(tester, repository);

    expect(find.text('No available album art in the library'), findsOneWidget);
    final useCoverFinder = find.byKey(
      const ValueKey('AlbumArtLibraryPicker.ApplyButton'),
    );
    final useCover = tester.widget<SmPlayerTextIconButton>(useCoverFinder);
    expect(useCover.onPressed, isNull);
    expect(useCover.disabled, isTrue);
    expect(useCover.active, isFalse);
    expect(tester.getSize(useCoverFinder).height, 40);
    expect(
      tester.getRect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Preview')),
      ),
      const Rect.fromLTWH(761, 247, 240, 460),
    );
    expect(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.PreviewArtwork')),
      findsNothing,
    );
  });

  testWidgets(
    'MusicDialog library artwork picker ignores stale snapshot loads',
    (tester) async {
      final firstLoad = Completer<List<SongArtworkSnapshot>>();
      final secondLoad = Completer<List<SongArtworkSnapshot>>();
      final repository =
          _FakeMusicDialogRepository()
            ..currentSongHasArtwork = true
            ..librarySongs = [
              _currentSong,
              _librarySong(id: 2, title: 'Initial Cover', album: 'Album'),
              _librarySong(id: 3, title: 'Searchable Cover', album: 'Album'),
            ];

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.albumArt,
        ),
      );
      await tester.pumpAndSettle();
      repository.artworkSnapshotRequests.clear();
      repository.artworkSnapshotsCompleters = [firstLoad, secondLoad];

      await tester.tap(find.widgetWithText(TextButton, 'Change Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pump();
      expect(find.text('Loading'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Searchable');
      await tester.pump();
      expect(repository.artworkSnapshotRequests, [
        [2, 3],
        [3],
      ]);

      firstLoad.complete([
        SongArtworkSnapshot(
          songId: 2,
          artworkUrl: repository.recommendedArtworkPath,
          sourceUrl: repository.recommendedArtworkPath,
          sourcePath: repository.recommendedArtworkPath,
          source: SongArtworkSource.cached,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Initial Cover'), findsNothing);
      expect(find.text('No available album art in the library'), findsNothing);

      secondLoad.complete([
        SongArtworkSnapshot(
          songId: 3,
          artworkUrl: repository.recommendedArtworkPath,
          sourceUrl: repository.recommendedArtworkPath,
          sourcePath: repository.recommendedArtworkPath,
          source: SongArtworkSource.cached,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Loading'), findsNothing);
      expect(find.text('Searchable Cover'), findsWidgets);
    },
  );

  testWidgets(
    'MusicDialog library artwork picker loads choices after songs update',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository: repository,
          child: AlbumArtLibraryPickerDialog(
            albumName: 'Album',
            currentSong: _currentSong,
            songs: const [_currentSong],
            onApply: (_) {},
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Choice.2')),
        findsNothing,
      );
      expect(
        find.text('No available album art in the library'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository: repository,
          child: AlbumArtLibraryPickerDialog(
            albumName: 'Album',
            currentSong: _currentSong,
            songs: const [_currentSong, _defaultRecommendedSong],
            onApply: (_) {},
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Choice.2')),
        findsOneWidget,
      );
      expect(find.text('Match Song'), findsWidgets);
    },
  );

  testWidgets('MusicDialog library artwork picker Enter applies choice', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await _openAlbumArtLibraryPicker(tester, repository);
    _focusAlbumArtLibraryChoice(tester, 2);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Use this cover'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
  });

  testWidgets(
    'MusicDialog library artwork picker closes before parent dialog',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var closed = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.albumArt,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Change Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Title')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Title')),
        findsNothing,
      );
      expect(find.widgetWithText(TextButton, 'Album Art'), findsOneWidget);
      expect(closed, isFalse);
    },
  );

  testWidgets(
    'MusicDialog library artwork picker ignores global Enter like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await _openAlbumArtLibraryPicker(tester, repository);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Use this cover'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Reset'), findsNothing);
    },
  );

  testWidgets(
    'MusicDialog library artwork picker Space selects without apply',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await _openAlbumArtLibraryPicker(tester, repository);
      _focusAlbumArtLibraryChoice(tester, 2);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.text('Use this cover'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Reset'), findsNothing);
      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Preview')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MusicDialog library artwork picker double-click applies choice',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await _openAlbumArtLibraryPicker(tester, repository);
      final choice = find.byKey(
        const ValueKey('AlbumArtLibraryPicker.Choice.2'),
      );
      await tester.tap(choice);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(choice);
      await tester.pumpAndSettle();

      expect(find.text('Use this cover'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
    },
  );

  testWidgets('MusicDialog library artwork picker uses Electron chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeMusicDialogRepository();

    await _openAlbumArtLibraryPicker(tester, repository);

    expect(
      tester.getSize(find.byKey(const ValueKey('popup-dialog-surface')).last),
      const Size(860, 680),
    );
    final pickerTitle = tester.widget<Text>(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.Title')),
    );
    expect(pickerTitle.style?.fontSize, 22);
    expect(
      tester.getSize(find.byKey(const ValueKey('AlbumArtLibraryPicker.Title'))),
      const Size(760, 31),
    );
    final pickerBody = tester.widget<Padding>(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.Body')),
    );
    expect(pickerBody.padding, const EdgeInsets.fromLTRB(28, 0, 28, 0));
    final searchGap = tester.widget<SizedBox>(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchGap')),
    );
    expect(searchGap.height, 16);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchField')),
          )
          .height,
      40,
    );
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(
                const ValueKey('AlbumArtLibraryPicker.SearchField'),
              ),
              matching: find.byType(TextField),
            ),
          )
          .dx,
      239,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('AlbumArtLibraryPicker.ListFrame')),
          )
          .dy,
      247,
    );
    final searchIcon = tester.widget<SvgIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('AlbumArtLibraryPicker.Body')),
        matching: find.byKey(const ValueKey('MusicDialog.ElectronIcon.search')),
      ),
    );
    expect(searchIcon.svg, contains('M13.73 14.44'));
    final pickerFooter = tester.widget<Padding>(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.Footer')),
    );
    expect(pickerFooter.padding, const EdgeInsets.fromLTRB(28, 18, 28, 24));

    final cancelFinder = find.byKey(
      const ValueKey('AlbumArtLibraryPicker.CancelButton'),
    );
    final cancel = tester.widget<SmPlayerTextIconButton>(cancelFinder);
    expect(cancel.minWidth, 44);
    expect(cancel.height, 40);
    expect(tester.getSize(cancelFinder).height, 40);
    expect(cancel.horizontalPadding, 14);
    expect(cancel.borderRadius, 10);
    expect(cancel.fontSize, 14);
    expect(cancel.fontWeight, FontWeight.w700);

    final cancelDecoration = _textIconButtonDecoration(tester, cancelFinder);
    expect(cancelDecoration.color, CommandBarColors.buttonSurface);
    expect(
      cancelDecoration.border,
      Border.all(color: CommandBarColors.buttonBorder),
    );
    tester.binding.handlePointerEvent(
      PointerHoverEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(cancelFinder),
      ),
    );
    await tester.pump();
    final cancelHoverDecoration = _textIconButtonDecoration(
      tester,
      cancelFinder,
    );
    expect(
      cancelHoverDecoration.color,
      SmPlayerTextIconButtonColors.day.controlHover,
    );
    expect(
      cancelHoverDecoration.border,
      Border.all(color: SmPlayerTextIconButtonColors.day.controlHoverBorder),
    );

    final useCoverFinder = find.byKey(
      const ValueKey('AlbumArtLibraryPicker.ApplyButton'),
    );
    final useCover = tester.widget<SmPlayerTextIconButton>(useCoverFinder);
    expect(useCover.minWidth, 44);
    expect(useCover.height, 40);
    expect(useCover.horizontalPadding, 14);
    expect(useCover.borderRadius, 10);
    expect(useCover.fontSize, 14);
    expect(useCover.fontWeight, FontWeight.w700);
    expect(useCover.active, isTrue);
    expect(useCover.disabled, isFalse);
    expect(tester.getSize(useCoverFinder).height, 40);
    final useCoverDecoration = _textIconButtonDecoration(
      tester,
      useCoverFinder,
    );
    expect(useCoverDecoration.color, PopupDialogResolvedColors.light.accent);
    expect(
      useCoverDecoration.border,
      Border.all(color: CommandBarColors.buttonBorder),
    );

    final selectedTile = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('AlbumArtLibraryPicker.Choice.2')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final selectedInkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('AlbumArtLibraryPicker.Choice.2')),
        matching: find.byType(InkWell),
      ),
    );
    expect(
      selectedInkWell.overlayColor?.resolve(const <WidgetState>{
        WidgetState.hovered,
      }),
      Colors.transparent,
    );
    final selectedDecoration = selectedTile.decoration as BoxDecoration;
    expect(selectedDecoration.color, GlobalUI.sourceListSelectedBgColor);
    final selectedBorder = selectedDecoration.border as Border;
    expect(selectedBorder.top.color, GlobalUI.sourceListSelectedBorderColor);
    expect(selectedDecoration.boxShadow, GlobalUI.sourceListSelectedShadow);
    final choiceTitle = tester.widget<Text>(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.ChoiceTitle.2')),
    );
    expect(choiceTitle.maxLines, 1);
    expect(choiceTitle.style?.fontSize, 15);
    expect(choiceTitle.style?.fontWeight, FontWeight.w700);
    expect(choiceTitle.style?.fontVariations, isNull);
    expect(
      choiceTitle.style?.color,
      PopupDialogResolvedColors.light.textStrong,
    );
    expect(choiceTitle.style?.height, 18 / 15);

    final preview = find.byKey(const ValueKey('AlbumArtLibraryPicker.Preview'));
    final previewPadding = tester.widget<Padding>(preview);
    expect(previewPadding.padding, const EdgeInsets.symmetric(vertical: 4));
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('AlbumArtLibraryPicker.PreviewColumn')),
          )
          .width,
      240,
    );
    expect(
      tester.getSize(
        find
            .descendant(
              of: preview,
              matching: find.byWidgetPredicate(
                (widget) => widget is SizedBox && widget.width == 220,
              ),
            )
            .first,
      ),
      const Size(220, 220),
    );
    final previewArtwork = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.PreviewArtwork')),
    );
    final previewArtworkDecoration = previewArtwork.decoration as BoxDecoration;
    expect(previewArtworkDecoration.color, const Color(0xb8ffffff));
    expect(previewArtworkDecoration.borderRadius, BorderRadius.circular(8));
    expect(previewArtworkDecoration.boxShadow, isNull);
    expect(
      find.descendant(
        of: preview,
        matching: find.byKey(
          const ValueKey('AlbumArtLibraryPicker.PreviewArtworkShadow'),
        ),
      ),
      findsOneWidget,
    );
    final choiceArtwork = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.ChoiceArtwork.2')),
    );
    final choiceArtworkDecoration = choiceArtwork.decoration as BoxDecoration;
    expect(choiceArtworkDecoration.color, const Color(0xb8ffffff));
    expect(choiceArtworkDecoration.borderRadius, BorderRadius.circular(6));
    expect(choiceArtworkDecoration.boxShadow, isNull);
    final previewColumn = tester.widget<Column>(
      find.descendant(of: preview, matching: find.byType(Column)),
    );
    expect(previewColumn.crossAxisAlignment, CrossAxisAlignment.center);
    expect(
      find.descendant(
        of: preview,
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 8,
        ),
      ),
      findsNWidgets(3),
    );
    final previewTitle = tester.widget<Text>(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.PreviewTitle')),
    );
    expect(previewTitle.maxLines, 1);
    expect(previewTitle.textAlign, TextAlign.center);
    expect(previewTitle.style?.fontWeight, FontWeight.w700);
    expect(previewTitle.style?.height, 22.5 / 16);
  });

  testWidgets(
    'MusicDialog library artwork picker footer buttons ignore compact density',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await _openAlbumArtLibraryPicker(
        tester,
        repository,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      );

      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('AlbumArtLibraryPicker.CancelButton')),
            )
            .height,
        40,
      );
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('AlbumArtLibraryPicker.ApplyButton')),
            )
            .height,
        40,
      );
    },
  );

  testWidgets(
    'MusicDialog library artwork picker dark source artwork mirrors Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await _openAlbumArtLibraryPicker(
        tester,
        repository,
        brightness: Brightness.dark,
      );

      final choiceArtwork = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.ChoiceArtwork.2')),
      );
      final choiceArtworkDecoration = choiceArtwork.decoration as BoxDecoration;
      expect(choiceArtworkDecoration.color, const Color(0xb8ffffff));
      expect(choiceArtworkDecoration.boxShadow, isNull);

      final previewArtwork = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.PreviewArtwork')),
      );
      final previewArtworkDecoration =
          previewArtwork.decoration as BoxDecoration;
      expect(previewArtworkDecoration.color, const Color(0x14ffffff));
      expect(previewArtworkDecoration.boxShadow, isNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('AlbumArtLibraryPicker.Preview')),
          matching: find.byKey(
            const ValueKey('AlbumArtLibraryPicker.PreviewArtworkShadow'),
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('MusicDialog library artwork picker scrollbar mirrors Electron', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();
    repository.librarySongs = [
      _currentSong,
      for (var index = 2; index <= 28; index += 1)
        _librarySong(id: index, title: 'Cover Song $index', album: 'Album'),
    ];
    repository.artworkSnapshotsCompleter =
        Completer<List<SongArtworkSnapshot>>()..complete([
          for (var index = 2; index <= 28; index += 1)
            SongArtworkSnapshot(
              songId: index,
              artworkUrl: repository.recommendedArtworkPath,
              sourceUrl: repository.recommendedArtworkPath,
              sourcePath: repository.recommendedArtworkPath,
              source: SongArtworkSource.cached,
            ),
        ]);

    await _openAlbumArtLibraryPicker(tester, repository);

    final frame = find.byKey(const ValueKey('AlbumArtLibraryPicker.ListFrame'));
    final track = find.byKey(
      const ValueKey('AlbumArtLibraryPicker.Scrollbar.Position'),
    );
    final thumb = find.byKey(
      const ValueKey('AlbumArtLibraryPicker.Scrollbar.Thumb'),
    );
    expect(frame, findsOneWidget);
    expect(track, findsOneWidget);
    expect(thumb, findsOneWidget);
    expect(tester.getSize(track).width, 9);
    expect(tester.getSize(thumb).width, 5);
    expect(tester.getSize(thumb).height, greaterThanOrEqualTo(38));
    expect(tester.getRect(track).right - tester.getRect(frame).right, 5);

    final listView = tester.widget<ListView>(
      find.descendant(of: frame, matching: find.byType(ListView)),
    );
    expect(listView.padding, const EdgeInsets.only(right: 10));

    final thumbTopBefore = tester.getTopLeft(thumb).dy;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(frame));
    await tester.pumpAndSettle();
    await tester.dragFrom(
      Offset(tester.getRect(frame).right - 2, tester.getRect(thumb).center.dy),
      const Offset(0, 110),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(thumb).dy, greaterThan(thumbTopBefore));
  });

  testWidgets(
    'MusicDialog library artwork picker mobile mirrors Electron list',
    (tester) async {
      tester.view.physicalSize = const Size(640, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeMusicDialogRepository();

      await _openAlbumArtLibraryPicker(tester, repository);

      final pickerShell = find.byKey(const ValueKey('popup-dialog-shell')).last;
      expect(tester.getSize(pickerShell), const Size(640, 820));
      final pickerSurface = tester.widget<Container>(
        find.byKey(const ValueKey('popup-dialog-surface')).last,
      );
      final pickerSurfaceDecoration = pickerSurface.decoration as BoxDecoration;
      expect(pickerSurfaceDecoration.borderRadius, BorderRadius.zero);
      expect(pickerSurfaceDecoration.border, isNull);
      expect(pickerSurfaceDecoration.boxShadow, isNull);

      final pickerTitle = tester.widget<Text>(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Title')),
      );
      expect(pickerTitle.style?.fontSize, 18);
      expect(pickerTitle.style?.height, 25 / 18);
      expect(
        tester.getSize(
          find.byKey(const ValueKey('AlbumArtLibraryPicker.Title')),
        ),
        const Size(616, 25),
      );
      expect(
        tester.getTopLeft(
          find.byKey(const ValueKey('AlbumArtLibraryPicker.Body')),
        ),
        const Offset(0, 79),
      );
      final pickerBody = tester.widget<Padding>(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Body')),
      );
      expect(pickerBody.padding, const EdgeInsets.fromLTRB(12, 0, 12, 0));
      expect(
        tester.getTopLeft(
          find.byKey(const ValueKey('AlbumArtLibraryPicker.ListFrame')),
        ),
        const Offset(12, 131),
      );
      expect(
        tester.getTopLeft(
          find.byKey(const ValueKey('AlbumArtLibraryPicker.Choice.2')),
        ),
        const Offset(12, 135),
      );
      final searchGap = tester.widget<SizedBox>(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchGap')),
      );
      expect(searchGap.height, 12);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchField')),
            )
            .height,
        40,
      );
      expect(
        tester
            .getTopLeft(
              find.descendant(
                of: find.byKey(
                  const ValueKey('AlbumArtLibraryPicker.SearchField'),
                ),
                matching: find.byType(TextField),
              ),
            )
            .dx,
        52,
      );
      final pickerFooter = tester.widget<Padding>(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Footer')),
      );
      expect(pickerFooter.padding, const EdgeInsets.fromLTRB(12, 12, 12, 20));

      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Preview')),
        findsNothing,
      );
      final selectedTileFinder = find.descendant(
        of: find.byKey(const ValueKey('AlbumArtLibraryPicker.Choice.2')),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(selectedTileFinder).height, 92);
      final selectedInkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(const ValueKey('AlbumArtLibraryPicker.Choice.2')),
          matching: find.byType(InkWell),
        ),
      );
      expect(
        selectedInkWell.overlayColor?.resolve(const <WidgetState>{
          WidgetState.hovered,
        }),
        Colors.transparent,
      );
      final selectedTile = tester.widget<AnimatedContainer>(selectedTileFinder);
      final selectedDecoration = selectedTile.decoration as BoxDecoration;
      expect(
        selectedDecoration.color,
        Color.alphaBlend(
          GlobalUI.sourceListMobileSelectedBgColor,
          PopupDialogResolvedColors.light.surface,
        ),
      );
      expect(selectedDecoration.border, isNull);
      expect(
        selectedDecoration.boxShadow,
        GlobalUI.sourceListMobileSelectedShadow,
      );

      final artwork = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byKey(const ValueKey('AlbumArtLibraryPicker.Choice.2')),
              matching: find.byWidgetPredicate(
                (widget) => widget is SizedBox && widget.width == 84,
              ),
            )
            .first,
      );
      expect(artwork.height, 84);
      final title = tester.widget<Text>(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.ChoiceTitle.2')),
      );
      expect(title.maxLines, 2);
      expect(title.style?.fontSize, 15);
      expect(title.style?.fontWeight, FontWeight.w700);
      expect(title.style?.fontVariations, isNull);
      expect(title.style?.color, PopupDialogResolvedColors.light.textStrong);
      expect(title.style?.height, 18 / 15);
    },
  );

  testWidgets(
    'MusicDialog library artwork picker mobile empty message mirrors Electron list padding',
    (tester) async {
      tester.view.physicalSize = const Size(640, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository =
          _FakeMusicDialogRepository()..librarySongs = const [_currentSong];

      await _openAlbumArtLibraryPicker(tester, repository);

      final frame = find.byKey(
        const ValueKey('AlbumArtLibraryPicker.ListFrame'),
      );
      final listView = tester.widget<ListView>(
        find.descendant(of: frame, matching: find.byType(ListView)),
      );
      expect(listView.padding, const EdgeInsets.fromLTRB(0, 4, 0, 12));
      expect(tester.getTopLeft(frame), const Offset(12, 131));
      expect(
        tester.getRect(
          find.byKey(const ValueKey('AlbumArtLibraryPicker.Message')),
        ),
        const Rect.fromLTWH(12, 135, 616, 67),
      );
      expect(
        tester.getRect(
          find.byKey(const ValueKey('AlbumArtLibraryPicker.MessageText')),
        ),
        const Rect.fromLTWH(12, 157, 616, 23),
      );
    },
  );

  testWidgets(
    'MusicDialog library artwork picker mobile scrollbar mirrors Electron',
    (tester) async {
      tester.view.physicalSize = const Size(640, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeMusicDialogRepository();
      repository.librarySongs = [
        _currentSong,
        for (var index = 2; index <= 18; index += 1)
          _librarySong(id: index, title: 'Cover Song $index', album: 'Album'),
      ];
      repository.artworkSnapshotsCompleter =
          Completer<List<SongArtworkSnapshot>>()..complete([
            for (var index = 2; index <= 18; index += 1)
              SongArtworkSnapshot(
                songId: index,
                artworkUrl: repository.recommendedArtworkPath,
                sourceUrl: repository.recommendedArtworkPath,
                sourcePath: repository.recommendedArtworkPath,
                source: SongArtworkSource.cached,
              ),
          ]);

      await _openAlbumArtLibraryPicker(tester, repository);

      final frame = find.byKey(
        const ValueKey('AlbumArtLibraryPicker.ListFrame'),
      );
      final track = find.byKey(
        const ValueKey('AlbumArtLibraryPicker.Scrollbar.Position'),
      );
      final thumb = find.byKey(
        const ValueKey('AlbumArtLibraryPicker.Scrollbar.Thumb'),
      );
      expect(frame, findsOneWidget);
      expect(track, findsOneWidget);
      expect(thumb, findsOneWidget);
      expect(tester.getSize(track).width, 16);
      expect(tester.getSize(thumb).width, 5);
      expect(tester.getRect(track).right - tester.getRect(frame).right, 12);

      final listView = tester.widget<ListView>(
        find.descendant(of: frame, matching: find.byType(ListView)),
      );
      expect(listView.padding, const EdgeInsets.fromLTRB(0, 4, 0, 12));
    },
  );

  testWidgets('MusicDialog album art delete uses inline confirmation', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.albumArt,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Remove Current Song art?'), findsOneWidget);
    final warningPanel = tester.widget<Container>(
      find.byKey(const ValueKey('MusicDialog.ArtworkDeleteConfirm')),
    );
    final warningDecoration = warningPanel.decoration as BoxDecoration;
    expect(warningDecoration.color, const Color(0xebfff5f2));
    final warningBorder = warningDecoration.border as Border;
    expect(warningBorder.top.color, const Color(0x52b0584a));
    expect(find.widgetWithText(FilledButton, 'Yes'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Yes'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Cancel'));
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Current Song art?'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Yes'));
    await tester.tap(find.widgetWithText(TextButton, 'Yes'));
    await tester.pumpAndSettle();

    expect(repository.deletedArtworkSongId, 1);
    expect(find.text('Album art deleted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog album art delete confirmation disables while saving',
    (tester) async {
      final deleteCompleter = Completer<void>();
      final repository =
          _FakeMusicDialogRepository()
            ..deleteSongArtworkCompleter = deleteCompleter;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.albumArt,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Yes'));
      await tester.tap(find.widgetWithText(TextButton, 'Yes'));
      await tester.pump();

      final yesButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Yes'),
      );
      final cancelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(yesButton.onPressed, isNull);
      expect(cancelButton.onPressed, isNull);

      deleteCompleter.complete();
      await tester.pumpAndSettle();
      expect(repository.deletedArtworkSongId, 1);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog search loads internet lyrics before browser fallback',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..internetLyrics = '[00:02.00]Internet line';

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('[00:02.00]Internet line'), findsOneWidget);
      expect(repository.internetLyricsRequested, isTrue);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog hidden timestamps search displays plain text but saves raw',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..internetLyrics = '[00:02.00]Internet line';

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(repository.internetLyricsRequested, isTrue);
      expect(find.text('Internet line'), findsOneWidget);
      expect(find.text('[00:02.00]Internet line'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedLyrics, '[00:02.00]Internet line');
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog unchanged lyrics search keeps scroll like Electron',
    (tester) async {
      final rawLyrics = List.generate(
        80,
        (index) => '[00:${index.toString().padLeft(2, '0')}.00]Line $index',
      ).join('\n');
      final repository =
          _FakeMusicDialogRepository()
            ..lyricsRawText = rawLyrics
            ..internetLyrics = rawLyrics;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      final lyricsField = tester.widget<TextField>(find.byType(TextField).last);
      final scrollController = lyricsField.scrollController!;
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pump();
      final beforeOffset = scrollController.offset;
      expect(beforeOffset, greaterThan(0));

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(repository.internetLyricsRequested, isTrue);
      expect(find.text('No changes were detected.'), findsOneWidget);
      expect(scrollController.offset, beforeOffset);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog hidden timestamp search keeps plain text but updates raw like Electron',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..lyricsRawText = '[00:01.00]Shared line'
            ..internetLyrics = '[00:09.00]Shared line';

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.text('Shared line'), findsOneWidget);
      expect(find.text('[00:01.00]Shared line'), findsNothing);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(repository.internetLyricsRequested, isTrue);
      expect(find.text('No changes were detected.'), findsOneWidget);
      expect(find.text('Shared line'), findsOneWidget);
      expect(find.text('[00:09.00]Shared line'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedLyrics, '[00:09.00]Shared line');
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog untimed search hides timestamp toggle like Electron',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()..internetLyrics = 'Internet plain line';

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(repository.internetLyricsRequested, isTrue);
      expect(find.text('Internet plain line'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedLyrics, 'Internet plain line');
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog timed search restores timestamp toggle like Electron',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()..internetLyrics = 'Internet plain line';

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Internet plain line'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);

      repository.internetLyrics = '[00:04.00]Internet timed line';
      await tester.pump(const Duration(seconds: 6));
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('[00:04.00]Internet timed line'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedLyrics, '[00:04.00]Internet timed line');
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog search opens browser when internet lyrics are empty',
    (tester) async {
      final repository = _FakeMusicDialogRepository()..internetLyrics = '';

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(repository.internetLyricsRequested, isTrue);
      expect(repository.openedLyricsSearchSongIds, [1]);
      expect(find.text('Browser opened.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog search falls back to browser when internet lyrics fail',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()..failInternetLyrics = true;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(repository.internetLyricsRequested, isTrue);
      expect(repository.openedLyricsSearchSongIds, [1]);
      expect(find.text('Browser opened.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog search reports failure when internet and browser both fail',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..failInternetLyrics = true
            ..failOpenLyricsSearch = true;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(repository.internetLyricsRequested, isTrue);
      expect(repository.openedLyricsSearchSongIds, [1]);
      expect(find.text('No matching lyrics found.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog failed lyrics search keeps edited text like Electron',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..failInternetLyrics = true
            ..failOpenLyricsSearch = true;
      var closed = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Dirty lyrics');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(repository.internetLyricsRequested, isTrue);
      expect(repository.openedLyricsSearchSongIds, [1]);
      expect(find.text('No matching lyrics found.'), findsOneWidget);
      expect(find.text('Dirty lyrics'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
      expect(closed, isFalse);
    },
  );

  testWidgets('MusicDialog import lyrics picker mirrors Electron filters', (
    tester,
  ) async {
    final originalFilePicker = FilePickerPlatform.instance;
    final filePicker = _CapturingFilePickerPlatform();
    FilePickerPlatform.instance = filePicker;
    addTearDown(() {
      FilePickerPlatform.instance = originalFilePicker;
    });

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import'));
    await tester.pump();

    expect(filePicker.type, FileType.custom);
    expect(filePicker.dialogTitle, 'Import lyrics');
    expect(filePicker.allowedExtensions, [
      'lrc',
      'txt',
      'aac',
      'aiff',
      'alac',
      'ape',
      'flac',
      'm4a',
      'mp3',
      'ogg',
      'opus',
      'wav',
      'wma',
    ]);
  });

  testWidgets('MusicDialog import lyrics updates editor and scrolls to top', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'smplayer_import_lyrics_test_',
    );
    addTearDown(() {
      tempDir.deleteSync(recursive: true);
    });
    final lyricsFile = File('${tempDir.path}/imported.lrc')
      ..writeAsStringSync('[00:03.00]Imported line');
    final originalFilePicker = FilePickerPlatform.instance;
    final filePicker =
        _CapturingFilePickerPlatform()
          ..result = FilePickerResult([
            PlatformFile(
              name: 'imported.lrc',
              path: lyricsFile.path,
              size: lyricsFile.lengthSync(),
            ),
          ]);
    FilePickerPlatform.instance = filePicker;
    addTearDown(() {
      FilePickerPlatform.instance = originalFilePicker;
    });
    final repository =
        _FakeMusicDialogRepository()
          ..lyricsRawText = List.generate(
            80,
            (index) => '[00:${index.toString().padLeft(2, '0')}.00]Line $index',
          ).join('\n');

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    final lyricsField = tester.widget<TextField>(find.byType(TextField).last);
    final scrollController = lyricsField.scrollController!;
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();
    expect(scrollController.offset, greaterThan(0));

    await tester.tap(find.text('Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('[00:03.00]Imported line'), findsOneWidget);
    expect(repository.readLyricsFilePath, lyricsFile.path);
    expect(scrollController.offset, 0);
  });

  testWidgets(
    'MusicDialog re-enables lyrics controls after import like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final tempDir = Directory.systemTemp.createTempSync(
        'smplayer_import_saving_lyrics_test_',
      );
      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });
      final lyricsFile = File('${tempDir.path}/imported-saving.lrc')
        ..writeAsStringSync('[00:06.00]Imported saving line');
      final originalFilePicker = FilePickerPlatform.instance;
      final filePicker =
          _CapturingFilePickerPlatform()
            ..result = FilePickerResult([
              PlatformFile(
                name: 'imported-saving.lrc',
                path: lyricsFile.path,
                size: lyricsFile.lengthSync(),
              ),
            ]);
      FilePickerPlatform.instance = filePicker;
      addTearDown(() {
        FilePickerPlatform.instance = originalFilePicker;
      });
      final readCompleter = Completer<String>();
      final repository =
          _FakeMusicDialogRepository()
            ..readLyricsFromFileCompleter = readCompleter;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import'));
      await tester.pump();

      for (final label in ['Search', 'Import', 'Save']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNull, reason: '$label should be disabled');
      }
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsOneWidget,
      );
      expect(repository.readLyricsFilePath, lyricsFile.path);

      readCompleter.complete('[00:06.00]Imported saving line');
      await tester.pumpAndSettle();

      for (final label in ['Search', 'Import', 'Save']) {
        await _expectMusicDialogCommandEnabled(tester, label, true);
      }
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).onChanged,
        isNotNull,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsNothing,
      );
      expect(find.text('[00:06.00]Imported saving line'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog re-enables lyrics controls after import failure like Electron',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'smplayer_import_failed_saving_lyrics_test_',
      );
      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });
      final lyricsFile = File('${tempDir.path}/failed-saving.lrc')
        ..writeAsStringSync('[00:07.00]Failed saving line');
      final originalFilePicker = FilePickerPlatform.instance;
      final filePicker =
          _CapturingFilePickerPlatform()
            ..result = FilePickerResult([
              PlatformFile(
                name: 'failed-saving.lrc',
                path: lyricsFile.path,
                size: lyricsFile.lengthSync(),
              ),
            ]);
      FilePickerPlatform.instance = filePicker;
      addTearDown(() {
        FilePickerPlatform.instance = originalFilePicker;
      });
      final readCompleter = Completer<String>();
      final repository =
          _FakeMusicDialogRepository()
            ..readLyricsFromFileCompleter = readCompleter;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import'));
      await tester.pump();

      for (final label in ['Search', 'Import', 'Save']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNull, reason: '$label should be disabled');
      }
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsOneWidget,
      );

      readCompleter.completeError(StateError('import lyrics failed'));
      await tester.pumpAndSettle();

      for (final label in ['Search', 'Import', 'Save']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNotNull, reason: '$label should be enabled');
      }
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsNothing,
      );
      expect(repository.readLyricsFilePath, lyricsFile.path);
      expect(find.text('[00:01.00]Original line'), findsOneWidget);
      expect(find.text('Failed to import lyrics.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog hidden timestamps import displays plain text but saves raw',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'smplayer_import_hidden_timestamps_test_',
      );
      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });
      final lyricsFile = File('${tempDir.path}/imported-hidden.lrc')
        ..writeAsStringSync('[00:03.00]Imported line');
      final originalFilePicker = FilePickerPlatform.instance;
      final filePicker =
          _CapturingFilePickerPlatform()
            ..result = FilePickerResult([
              PlatformFile(
                name: 'imported-hidden.lrc',
                path: lyricsFile.path,
                size: lyricsFile.lengthSync(),
              ),
            ]);
      FilePickerPlatform.instance = filePicker;
      addTearDown(() {
        FilePickerPlatform.instance = originalFilePicker;
      });
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(repository.readLyricsFilePath, lyricsFile.path);
      expect(find.text('Imported line'), findsOneWidget);
      expect(find.text('[00:03.00]Imported line'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedLyrics, '[00:03.00]Imported line');
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog untimed import hides timestamp toggle like Electron',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'smplayer_import_untimed_lyrics_test_',
      );
      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });
      final lyricsFile = File('${tempDir.path}/untimed.txt')
        ..writeAsStringSync('Imported untimed line');
      final originalFilePicker = FilePickerPlatform.instance;
      final filePicker =
          _CapturingFilePickerPlatform()
            ..result = FilePickerResult([
              PlatformFile(
                name: 'untimed.txt',
                path: lyricsFile.path,
                size: lyricsFile.lengthSync(),
              ),
            ]);
      FilePickerPlatform.instance = filePicker;
      addTearDown(() {
        FilePickerPlatform.instance = originalFilePicker;
      });
      final repository =
          _FakeMusicDialogRepository()
            ..importedLyricsText = 'Imported untimed line';

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(repository.readLyricsFilePath, lyricsFile.path);
      expect(find.text('Imported untimed line'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedLyrics, 'Imported untimed line');
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('MusicDialog import lyrics cancel leaves editor unchanged', (
    tester,
  ) async {
    final originalFilePicker = FilePickerPlatform.instance;
    final filePicker = _CapturingFilePickerPlatform();
    FilePickerPlatform.instance = filePicker;
    addTearDown(() {
      FilePickerPlatform.instance = originalFilePicker;
    });
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(repository.readLyricsFilePath, isNull);
    expect(find.text('[00:01.00]Original line'), findsOneWidget);
    expect(find.text('Failed to import lyrics.'), findsNothing);
  });

  testWidgets('MusicDialog import empty lyrics mirrors Electron result', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'smplayer_import_empty_lyrics_test_',
    );
    addTearDown(() {
      tempDir.deleteSync(recursive: true);
    });
    final lyricsFile = File('${tempDir.path}/empty.lrc')..writeAsStringSync('');
    final originalFilePicker = FilePickerPlatform.instance;
    final filePicker =
        _CapturingFilePickerPlatform()
          ..result = FilePickerResult([
            PlatformFile(
              name: 'empty.lrc',
              path: lyricsFile.path,
              size: lyricsFile.lengthSync(),
            ),
          ]);
    FilePickerPlatform.instance = filePicker;
    addTearDown(() {
      FilePickerPlatform.instance = originalFilePicker;
    });
    final repository = _FakeMusicDialogRepository()..importedLyricsText = '';

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    final lyricsField = tester.widget<TextField>(find.byType(TextField).last);
    expect(lyricsField.controller?.text, isEmpty);
    expect(repository.readLyricsFilePath, lyricsFile.path);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
    expect(find.text('Failed to import lyrics.'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedLyrics, isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('MusicDialog import lyrics failure mirrors Electron message', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'smplayer_import_lyrics_failure_test_',
    );
    addTearDown(() {
      tempDir.deleteSync(recursive: true);
    });
    final lyricsFile = File('${tempDir.path}/failed.lrc')
      ..writeAsStringSync('[00:04.00]Failed line');
    final originalFilePicker = FilePickerPlatform.instance;
    final filePicker =
        _CapturingFilePickerPlatform()
          ..result = FilePickerResult([
            PlatformFile(
              name: 'failed.lrc',
              path: lyricsFile.path,
              size: lyricsFile.lengthSync(),
            ),
          ]);
    FilePickerPlatform.instance = filePicker;
    addTearDown(() {
      FilePickerPlatform.instance = originalFilePicker;
    });
    final repository =
        _FakeMusicDialogRepository()..failImportLyricsRead = true;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(repository.readLyricsFilePath, lyricsFile.path);
    expect(find.text('[00:01.00]Original line'), findsOneWidget);
    expect(find.text('Failed to import lyrics.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('MusicDialog local artwork picker mirrors Electron filters', (
    tester,
  ) async {
    final originalFilePicker = FilePickerPlatform.instance;
    final filePicker = _CapturingFilePickerPlatform();
    FilePickerPlatform.instance = filePicker;
    addTearDown(() {
      FilePickerPlatform.instance = originalFilePicker;
    });

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.albumArt,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change Artwork'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose local file'));
    await tester.pump();

    expect(filePicker.type, FileType.custom);
    expect(filePicker.dialogTitle, 'Choose Album Artwork');
    expect(filePicker.allowedExtensions, [
      'jpg',
      'png',
      'jpeg',
      'webp',
      'bmp',
      'aac',
      'aiff',
      'alac',
      'ape',
      'flac',
      'm4a',
      'mp3',
      'ogg',
      'opus',
      'wav',
      'wma',
    ]);
  });

  testWidgets(
    'MusicDialog local artwork picker saves prepared source like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      final originalFilePicker = FilePickerPlatform.instance;
      final filePicker =
          _CapturingFilePickerPlatform()
            ..result = FilePickerResult([
              PlatformFile(
                name: 'local-cover.png',
                path: repository.recommendedArtworkPath,
                size: File(repository.recommendedArtworkPath).lengthSync(),
              ),
            ]);
      FilePickerPlatform.instance = filePicker;
      addTearDown(() {
        FilePickerPlatform.instance = originalFilePicker;
      });
      var saved = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.albumArt,
          onSaved: () {
            saved = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
        findsOneWidget,
      );

      await tester.tap(find.text('Change Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose local file'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
        findsNothing,
      );
      expect(find.text('Reset'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedArtworkPath, repository.recommendedArtworkPath);
      expect(saved, isTrue);
      expect(find.text('New album art has been saved!'), findsOneWidget);
      expect(find.text('Reset'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'MusicDialog local artwork no-artwork notice uses source basename',
    (tester) async {
      final originalFilePicker = FilePickerPlatform.instance;
      final filePicker =
          _CapturingFilePickerPlatform()
            ..result = FilePickerResult([
              PlatformFile(
                name: 'source-track.mp3',
                path: '/tmp/source-track.mp3',
                size: 0,
              ),
            ]);
      FilePickerPlatform.instance = filePicker;
      addTearDown(() {
        FilePickerPlatform.instance = originalFilePicker;
      });

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository:
              _FakeMusicDialogRepository()..failPrepareArtworkSource = true,
          initialMode: SongDialogMode.albumArt,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose local file'));
      await tester.pumpAndSettle();

      expect(
        find.text('"source-track" does not have album art!'),
        findsOneWidget,
      );
      expect(find.textContaining('source-track.mp3'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'AlbumArtworkDialog local picker mirrors Electron filters and source basename',
    (tester) async {
      final originalFilePicker = FilePickerPlatform.instance;
      final filePicker =
          _CapturingFilePickerPlatform()
            ..result = FilePickerResult([
              PlatformFile(
                name: 'album-source.flac',
                path: '/tmp/album-source.flac',
                size: 0,
              ),
            ]);
      FilePickerPlatform.instance = filePicker;
      addTearDown(() {
        FilePickerPlatform.instance = originalFilePicker;
      });

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository:
              _FakeMusicDialogRepository()..failPrepareArtworkSource = true,
          child: AlbumArtworkDialog(
            albumName: 'Album',
            artworkUrl: '',
            songId: 1,
            onClose: () {},
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose local file'));
      await tester.pumpAndSettle();

      expect(filePicker.type, FileType.custom);
      expect(filePicker.dialogTitle, 'Choose Album Artwork');
      expect(filePicker.allowedExtensions, [
        'jpg',
        'png',
        'jpeg',
        'webp',
        'bmp',
        'aac',
        'aiff',
        'alac',
        'ape',
        'flac',
        'm4a',
        'mp3',
        'ogg',
        'opus',
        'wav',
        'wma',
      ]);
      expect(
        find.text('"album-source" does not have album art!'),
        findsOneWidget,
      );
      expect(find.textContaining('album-source.flac'), findsNothing);
    },
  );

  testWidgets(
    'AlbumArtworkDialog local picker saves prepared source like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      final originalFilePicker = FilePickerPlatform.instance;
      final filePicker =
          _CapturingFilePickerPlatform()
            ..result = FilePickerResult([
              PlatformFile(
                name: 'album-local-cover.png',
                path: repository.recommendedArtworkPath,
                size: File(repository.recommendedArtworkPath).lengthSync(),
              ),
            ]);
      FilePickerPlatform.instance = filePicker;
      addTearDown(() {
        FilePickerPlatform.instance = originalFilePicker;
      });
      var saved = false;

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository: repository,
          child: AlbumArtworkDialog(
            albumName: 'Displayed Album',
            artworkUrl: '',
            songId: 1,
            onClose: () {},
            onSaved: () {
              saved = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose local file'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('AlbumArtworkDialog.StatusMessage')),
        findsNothing,
      );
      expect(find.text('Reset'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedAlbumArtworkName, 'Displayed Album');
      expect(
        repository.savedAlbumArtworkPath,
        repository.recommendedArtworkPath,
      );
      expect(saved, isTrue);
      expect(find.text('New album art has been saved!'), findsOneWidget);
      expect(find.text('Reset'), findsNothing);
    },
  );

  testWidgets(
    'AlbumArtworkDialog library picker mirrors Electron source menu',
    (tester) async {
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository: repository,
          child: AlbumArtworkDialog(
            albumName: 'Displayed Album',
            artworkUrl: '',
            songId: 1,
            onClose: () {},
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Artwork'));
      await tester.pumpAndSettle();

      expect(find.text('Choose local file'), findsOneWidget);
      expect(find.text('Choose from library'), findsOneWidget);

      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Title')),
        findsOneWidget,
      );
      expect(find.text('Match Song'), findsAtLeastNWidgets(1));

      await tester.tap(find.text('Use this cover'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Title')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtworkImageShell')),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.savedAlbumArtworkName, 'Displayed Album');
      expect(
        repository.savedAlbumArtworkPath,
        repository.recommendedArtworkPath,
      );
    },
  );

  testWidgets(
    'AlbumArtworkDialog resolves artwork from songId like Electron hook',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()..currentSongResolvedArtwork = true;

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository: repository,
          child: AlbumArtworkDialog(
            albumName: 'Displayed Album',
            artworkUrl: '',
            songId: 1,
            onClose: () {},
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.artworkSnapshotRequests, [
        [1],
      ]);
      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtworkImageShell')),
        findsOneWidget,
      );
      expect(find.text('No album art'), findsNothing);
    },
  );

  testWidgets('AlbumArtworkDialog delete uses Electron albumName prop', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();
    var saved = false;

    await tester.pumpWidget(
      _MusicDialogTestShell(
        repository: repository,
        child: AlbumArtworkDialog(
          albumName: 'Displayed Album',
          artworkUrl: '',
          songId: 1,
          onClose: () {},
          onSaved: () {
            saved = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('MusicDialog.ElectronIcon.albums')),
      findsNothing,
    );
    expect(find.widgetWithText(TextButton, 'Album Art'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Displayed Album art?'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Yes'));
    await tester.tap(find.widgetWithText(TextButton, 'Yes'));
    await tester.pumpAndSettle();

    expect(repository.deletedAlbumArtworkName, 'Displayed Album');
    expect(saved, isTrue);
    final statusText = tester.widget<Text>(
      find.byKey(const ValueKey('AlbumArtworkDialog.StatusMessage')),
    );
    expect(statusText.data, 'Album art deleted');
    expect(statusText.style?.color, PopupDialogResolvedColors.light.text);
    expect(statusText.style?.fontSize, 16);
    expect(statusText.style?.fontWeight, FontWeight.w400);
    final statusRect = tester.getRect(
      find.byKey(const ValueKey('AlbumArtworkDialog.StatusMessage')),
    );
    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('popup-dialog-surface')),
    );
    expect(statusRect.left, dialogRect.left + 1);
  });

  testWidgets(
    'AlbumArtworkDialog save without pending artwork clears status like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var savedCount = 0;

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository: repository,
          child: AlbumArtworkDialog(
            albumName: 'Displayed Album',
            artworkUrl: '',
            songId: 1,
            onClose: () {},
            onSaved: () {
              savedCount += 1;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Yes'));
      await tester.tap(find.widgetWithText(TextButton, 'Yes'));
      await tester.pumpAndSettle();

      expect(find.text('Album art deleted'), findsOneWidget);
      expect(savedCount, 1);

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('AlbumArtworkDialog.StatusMessage')),
        findsNothing,
      );
      expect(repository.savedAlbumArtworkName, '');
      expect(repository.savedAlbumArtworkPath, '');
      expect(savedCount, 1);
    },
  );

  testWidgets(
    'AlbumArtworkDialog saved artwork keeps Electron display source URL',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      final displayArtworkPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}smplayer-album-dialog-display-art.png';
      final sourceArtworkPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}smplayer-album-dialog-source-art.png';
      File(repository.recommendedArtworkPath).copySync(displayArtworkPath);
      File(repository.recommendedArtworkPath).copySync(sourceArtworkPath);
      repository.artworkSnapshotsCompleter =
          Completer<List<SongArtworkSnapshot>>()..complete([
            SongArtworkSnapshot(
              songId: 2,
              artworkUrl: displayArtworkPath,
              sourceUrl: displayArtworkPath,
              sourcePath: sourceArtworkPath,
              source: SongArtworkSource.cached,
            ),
          ]);
      var saved = false;

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository: repository,
          child: AlbumArtworkDialog(
            albumName: 'Displayed Album',
            artworkUrl: '',
            songId: 1,
            onClose: () {},
            onSaved: () {
              saved = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this cover'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedAlbumArtworkName, 'Displayed Album');
      expect(repository.savedAlbumArtworkPath, sourceArtworkPath);
      expect(saved, isTrue);
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey('MusicDialog.AlbumArtworkImageShell')),
          matching: find.byType(Image),
        ),
      );
      expect((image.image as FileImage).file.path, displayArtworkPath);
      expect(find.text('Reset'), findsNothing);
    },
  );

  testWidgets(
    'AlbumArtworkDialog disables artwork controls while saving like Electron',
    (tester) async {
      final saveCompleter = Completer<void>();
      final repository =
          _FakeMusicDialogRepository()
            ..saveAlbumArtworkCompleter = saveCompleter;

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository: repository,
          child: AlbumArtworkDialog(
            albumName: 'Displayed Album',
            artworkUrl: '',
            songId: 1,
            onClose: () {},
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this cover'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();

      expect(repository.savedAlbumArtworkName, 'Displayed Album');
      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsOneWidget,
      );
      for (final label in ['Change Artwork', 'Save', 'Delete']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNull, reason: '$label should be disabled');
      }

      saveCompleter.complete();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicDialog.SaveProgress')),
        findsNothing,
      );
      expect(find.text('New album art has been saved!'), findsOneWidget);
      for (final label in ['Change Artwork', 'Save', 'Delete']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNotNull, reason: '$label should be enabled');
      }
      expect(find.text('Reset'), findsNothing);
    },
  );

  testWidgets(
    'AlbumArtworkDialog library artwork picker closes before parent dialog',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var closed = false;

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository: repository,
          child: AlbumArtworkDialog(
            albumName: 'Album',
            artworkUrl: '',
            songId: 1,
            onClose: () {
              closed = true;
            },
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Title')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('AlbumArtLibraryPicker.Title')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('popup-dialog-surface')),
        findsOneWidget,
      );
      expect(closed, isFalse);
    },
  );

  testWidgets(
    'AlbumArtworkDialog mobile commandbar mirrors Electron geometry',
    (tester) async {
      tester.view.physicalSize = const Size(640, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeMusicDialogRepository();

      await tester.pumpWidget(
        _MusicDialogTestShell(
          repository: repository,
          child: AlbumArtworkDialog(
            albumName: 'Displayed Album',
            artworkUrl: repository.recommendedArtworkPath,
            songId: 1,
            onClose: () {},
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final changeArtworkRect = tester.getRect(
        find.widgetWithText(TextButton, 'Change Artwork'),
      );
      final deleteRect = tester.getRect(
        find.widgetWithText(TextButton, 'Delete'),
      );
      expect(changeArtworkRect.top, 58);
      expect(deleteRect.right, 625);
      final changeArtworkButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Change Artwork'),
      );
      expect(
        changeArtworkButton.style?.padding?.resolve(const <WidgetState>{}),
        const EdgeInsets.symmetric(horizontal: 10),
      );
      expect(
        tester.getTopLeft(
          find.byKey(const ValueKey('MusicDialog.AlbumArtworkImageShell')),
        ),
        const Offset(150, 283),
      );
    },
  );

  testWidgets('MusicDialog shortcuts mirror Electron dialog shortcuts', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()
          ..internetLyrics = '[00:02.00]Internet line';

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Edited line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('[00:01.00]Original line'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(repository.internetLyricsRequested, isTrue);
    expect(find.text('[00:02.00]Internet line'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '[00:03.00]Saved line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(repository.savedLyrics, '[00:03.00]Saved line');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog Ctrl+R outside lyrics keeps dirty lyrics like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var closed = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Dirty lyrics');
      await tester.tap(find.widgetWithText(TextButton, 'Music Info'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('Lyrics reset'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
      expect(closed, isFalse);
    },
  );

  testWidgets(
    'MusicDialog Ctrl+R on album art keeps dirty lyrics like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var closed = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Dirty lyrics');
      await tester.tap(find.widgetWithText(TextButton, 'Album Art'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('Lyrics reset'), findsNothing);
      expect(find.text('Album art reset'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
      expect(closed, isFalse);
    },
  );

  testWidgets(
    'MusicDialog Ctrl+S outside lyrics does not save dirty lyrics like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var closed = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Dirty lyrics');
      await tester.tap(find.widgetWithText(TextButton, 'Music Info'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(repository.saveSongLyricsCount, 0);
      expect(repository.updateSongPropertiesCount, 0);
      expect(find.text('Properties updated'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
      expect(closed, isFalse);
    },
  );

  testWidgets(
    'MusicDialog Ctrl+S on album art does not save dirty lyrics like Electron',
    (tester) async {
      final repository = _FakeMusicDialogRepository();
      var closed = false;

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Dirty lyrics');
      await tester.tap(find.widgetWithText(TextButton, 'Album Art'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(repository.saveSongLyricsCount, 0);
      expect(repository.savedArtworkPath, isEmpty);
      expect(
        find.text('The lyrics of "Current Song" have been updated!'),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
      expect(closed, isFalse);
    },
  );

  testWidgets('MusicDialog ignores Ctrl+F outside lyrics like Electron', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()
          ..internetLyrics = '[00:02.00]Internet line';

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.properties,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(repository.internetLyricsRequested, isFalse);
    expect(find.text('[00:02.00]Internet line'), findsNothing);
  });

  testWidgets('MusicDialog play button starts dialog song like Electron', (
    tester,
  ) async {
    int? playedTrackId;
    List<int>? playedQueueSongIds;
    var toggledCurrentTrack = false;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.properties,
        currentTrackId: 2,
        isPlaying: true,
        queueSongIds: const [2],
        onPlay: () {
          toggledCurrentTrack = true;
        },
        onPlayTrack: (trackId, queueSongIds) {
          playedTrackId = trackId;
          playedQueueSongIds = queueSongIds;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pump();

    expect(toggledCurrentTrack, isFalse);
    expect(playedTrackId, 1);
    expect(playedQueueSongIds, [2, 1]);
  });

  testWidgets('MusicDialog plays dialog song when current track is unknown', (
    tester,
  ) async {
    int? playedTrackId;
    List<int>? playedQueueSongIds;
    var toggledCurrentTrack = false;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.properties,
        queueSongIds: const [3],
        onPlay: () {
          toggledCurrentTrack = true;
        },
        onPlayTrack: (trackId, queueSongIds) {
          playedTrackId = trackId;
          playedQueueSongIds = queueSongIds;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pump();

    expect(toggledCurrentTrack, isFalse);
    expect(playedTrackId, 1);
    expect(playedQueueSongIds, [3, 1]);
  });

  testWidgets('MusicDialog pause button toggles current track like Electron', (
    tester,
  ) async {
    int? playedTrackId;
    var toggledCurrentTrack = false;

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: _FakeMusicDialogRepository(),
        initialMode: SongDialogMode.properties,
        currentTrackId: 1,
        isPlaying: true,
        queueSongIds: const [1, 2],
        onPlay: () {
          toggledCurrentTrack = true;
        },
        onPlayTrack: (trackId, queueSongIds) {
          playedTrackId = trackId;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pause'));
    await tester.pump();

    expect(toggledCurrentTrack, isTrue);
    expect(playedTrackId, isNull);
  });
}

class _MusicDialogTestApp extends StatelessWidget {
  const _MusicDialogTestApp({
    required this.repository,
    required this.initialMode,
    this.currentTrackId,
    this.isPlaying = false,
    this.queueSongIds = const <int>[],
    this.onPlay,
    this.onPlayTrack,
    this.onClose,
    this.onSaved,
    this.onReveal,
    this.brightness,
    this.visualDensity,
    this.song = _currentSong,
  });

  final _FakeMusicDialogRepository repository;
  final SongDialogMode initialMode;
  final int? currentTrackId;
  final bool isPlaying;
  final List<int> queueSongIds;
  final VoidCallback? onPlay;
  final MusicDialogPlayTrackCallback? onPlayTrack;
  final VoidCallback? onClose;
  final VoidCallback? onSaved;
  final ValueChanged<String>? onReveal;
  final Brightness? brightness;
  final VisualDensity? visualDensity;
  final LibrarySong song;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: buildSmPlayerTheme(
            const SettingsSnapshot.defaults(),
            brightness: brightness,
          ).copyWith(visualDensity: visualDensity),
          home: Scaffold(
            body: MusicDialog(
              song: song,
              initialMode: initialMode,
              currentTrackId: currentTrackId,
              isPlaying: isPlaying,
              queueSongIds: queueSongIds,
              onPlay: onPlay,
              onPlayTrack: onPlayTrack,
              onClose: onClose ?? () {},
              onSaved: onSaved,
              onReveal: onReveal,
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicDialogTestShell extends StatelessWidget {
  const _MusicDialogTestShell({required this.repository, required this.child});

  final _FakeMusicDialogRepository repository;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
          home: Scaffold(body: child),
        ),
      ),
    );
  }
}

class _FakeMusicDialogRepository extends LibraryRepository {
  _FakeMusicDialogRepository() {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    final artworkFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}smplayer-dialog-test-art.png',
    )..writeAsBytesSync(bytes);
    recommendedArtworkPath = artworkFile.path;
  }

  late final String recommendedArtworkPath;
  List<LibrarySong>? librarySongs;
  List<SearchHistoryEntry> recentSearches = const [];
  List<String> propertiesArtists = const ['Artist'];
  String propertiesComposers = '';
  String propertiesGenre = '';
  int getSongPropertiesCount = 0;
  SongPropertiesUpdate? lastPropertiesUpdate;
  int updateSongPropertiesCount = 0;
  int propertiesPlayCount = 0;
  int updateSongPlayCountCount = 0;
  int? updatedPlayCount;
  Completer<void>? updateSongPropertiesCompleter;
  Completer<void>? updateSongPlayCountCompleter;
  Completer<LyricsSnapshot>? getSongLyricsCompleter;
  final getSongLyricsCompleters = <Completer<LyricsSnapshot>>[];
  Completer<LyricsSnapshot>? getInternetLyricsCompleter;
  Completer<void>? saveSongLyricsCompleter;
  Completer<void>? saveAlbumArtworkCompleter;
  Completer<void>? deleteSongArtworkCompleter;
  Completer<List<SongArtworkSnapshot>>? artworkSnapshotsCompleter;
  final artworkSnapshotsCompletersByRequest =
      <String, Completer<List<SongArtworkSnapshot>>>{};
  List<Completer<List<SongArtworkSnapshot>>> artworkSnapshotsCompleters =
      const [];
  final artworkSnapshotRequests = <List<int>>[];
  String? addedRecentSearchQuery;
  SearchHistoryType? addedRecentSearchType;
  List<int>? removedRecentSearchIds;
  int clearRecentSearchCount = 0;
  LyricsRequestMode? lastSongLyricsMode;
  int saveSongLyricsCount = 0;
  int? savedLyricsSongId;
  int? deletedArtworkSongId;
  String savedLyrics = '';
  String importedLyricsText = '[00:03.00]Imported line';
  Completer<String>? readLyricsFromFileCompleter;
  String? readLyricsFilePath;
  String savedArtworkPath = '';
  String savedAlbumArtworkName = '';
  String savedAlbumArtworkPath = '';
  String deletedAlbumArtworkName = '';
  String internetLyrics = '';
  String lyricsRawText = '[00:01.00]Original line';
  LyricsSource lyricsSource = LyricsSource.lrcFile;
  final openedLyricsSearchSongIds = <int>[];
  bool internetLyricsRequested = false;
  bool failInternetLyrics = false;
  bool failOpenLyricsSearch = false;
  bool failImportLyricsRead = false;
  bool failSaveSongLyrics = false;
  bool failPropertiesLoad = false;
  bool failLyricsLoad = false;
  bool currentSongHasArtwork = false;
  bool currentSongResolvedArtwork = false;
  bool failArtworkSnapshots = false;
  bool failPrepareArtworkSource = false;

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    return LibraryContentData(
      songs: librarySongs ?? [_currentSong, _defaultRecommendedSong],
      recentSearches: recentSearches,
      hasLibrary: true,
      sortCriterion: MusicLibrarySortCriterion.title,
      albumsSort: AlbumSortCriterion.defaultSort,
      databasePath: '',
    );
  }

  @override
  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    getSongPropertiesCount += 1;
    if (failPropertiesLoad) {
      throw StateError('properties failed');
    }
    return SongPropertiesSnapshot(
      songId: 1,
      path: 'song.mp3',
      title: 'Current Song',
      subtitle: '',
      artist: propertiesArtists.join(', '),
      artists: propertiesArtists,
      album: 'Album',
      albumArtist: '',
      publisher: '',
      trackNumber: 0,
      year: 0,
      genre: propertiesGenre,
      composers: propertiesComposers,
      duration: 180,
      bitrate: 0,
      fileSize: 1024,
      dateCreated: '2026-01-01T00:00:00Z',
      dateModified: '2026-01-01T00:00:00Z',
      fileType: 'MP3',
      playCount: propertiesPlayCount,
    );
  }

  @override
  Future<void> updateSongProperties(
    int songId,
    SongPropertiesUpdate update,
  ) async {
    updateSongPropertiesCount += 1;
    lastPropertiesUpdate = update;
    final completer = updateSongPropertiesCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<void> updateSongPlayCount(int songId, int playCount) async {
    updateSongPlayCountCount += 1;
    updatedPlayCount = playCount;
    final completer = updateSongPlayCountCompleter;
    if (completer != null) {
      await completer.future;
    }
    propertiesPlayCount = playCount;
  }

  @override
  Future<SearchHistoryEntry?> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    addedRecentSearchQuery = query;
    addedRecentSearchType = type;
    return SearchHistoryEntry(
      id: 99,
      query: query,
      type: type,
      searchedAt: '2026-06-05T00:00:00Z',
    );
  }

  @override
  Future<void> removeRecentSearches(List<int> entryIds) async {
    removedRecentSearchIds = entryIds;
  }

  @override
  Future<void> clearRecentSearches() async {
    clearRecentSearchCount += 1;
  }

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    lastSongLyricsMode = mode;
    if (failLyricsLoad) {
      throw StateError('lyrics failed');
    }
    if (getSongLyricsCompleters.isNotEmpty) {
      return getSongLyricsCompleters.removeAt(0).future;
    }
    final completer = getSongLyricsCompleter;
    if (completer != null) {
      return completer.future;
    }
    return LyricsSnapshot(
      source: lyricsSource,
      isSynced: lyricsRawText.contains('[00:01.00]'),
      rawText: lyricsRawText,
      lines:
          lyricsRawText.contains('[00:01.00]')
              ? const [
                LyricsLine(id: 0, timestampMs: 1000, text: 'Original line'),
              ]
              : const [],
    );
  }

  @override
  Future<void> saveSongLyrics(int songId, String rawLyrics) async {
    saveSongLyricsCount += 1;
    if (failSaveSongLyrics) {
      throw StateError('save lyrics failed');
    }
    savedLyricsSongId = songId;
    savedLyrics = rawLyrics;
    final completer = saveSongLyricsCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<String> readLyricsFromFile(String filePath) async {
    readLyricsFilePath = filePath;
    if (failImportLyricsRead) {
      throw StateError('import lyrics failed');
    }
    final completer = readLyricsFromFileCompleter;
    if (completer != null) {
      return completer.future;
    }
    return importedLyricsText;
  }

  @override
  Future<LyricsSnapshot> getInternetLyrics(int songId) async {
    internetLyricsRequested = true;
    if (failInternetLyrics) {
      throw StateError('internet lyrics failed');
    }
    final completer = getInternetLyricsCompleter;
    if (completer != null) {
      return completer.future;
    }
    return LyricsSnapshot(
      source:
          internetLyrics.isEmpty ? LyricsSource.none : LyricsSource.internet,
      isSynced: internetLyrics.contains('[00:02.00]'),
      rawText: internetLyrics,
      lines:
          internetLyrics.isEmpty
              ? const []
              : const [
                LyricsLine(id: 0, timestampMs: 2000, text: 'Internet line'),
              ],
    );
  }

  @override
  Future<void> openLyricsSearchInBrowser(int songId) async {
    openedLyricsSearchSongIds.add(songId);
    if (failOpenLyricsSearch) {
      throw StateError('open lyrics search failed');
    }
  }

  @override
  Future<SongArtworkSnapshot> getSongArtworkSnapshot(int songId) async {
    return SongArtworkSnapshot(
      songId: 1,
      artworkUrl: currentSongHasArtwork ? recommendedArtworkPath : '',
      sourceUrl: currentSongHasArtwork ? recommendedArtworkPath : '',
      sourcePath: currentSongHasArtwork ? recommendedArtworkPath : '',
      source:
          currentSongHasArtwork
              ? SongArtworkSource.cached
              : SongArtworkSource.none,
    );
  }

  @override
  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    artworkSnapshotRequests.add(List<int>.of(songIds));
    final keyedCompleter = artworkSnapshotsCompletersByRequest.remove(
      songIds.join(','),
    );
    if (keyedCompleter != null) {
      return keyedCompleter.future;
    }
    if (artworkSnapshotsCompleters.isNotEmpty) {
      final completer = artworkSnapshotsCompleters.removeAt(0);
      return completer.future;
    }
    final completer = artworkSnapshotsCompleter;
    if (completer != null) {
      return completer.future;
    }
    if (failArtworkSnapshots) {
      throw StateError('artwork snapshots failed');
    }
    return [
      for (final songId in songIds)
        SongArtworkSnapshot(
          songId: songId,
          artworkUrl:
              songId == 2 || (songId == 1 && currentSongResolvedArtwork)
                  ? recommendedArtworkPath
                  : '',
          sourceUrl:
              songId == 2 || (songId == 1 && currentSongResolvedArtwork)
                  ? recommendedArtworkPath
                  : '',
          sourcePath:
              songId == 2 || (songId == 1 && currentSongResolvedArtwork)
                  ? recommendedArtworkPath
                  : '',
          source:
              songId == 2 || (songId == 1 && currentSongResolvedArtwork)
                  ? SongArtworkSource.cached
                  : SongArtworkSource.none,
        ),
    ];
  }

  @override
  Future<String> prepareSongArtworkSource(String sourcePath) async {
    if (failPrepareArtworkSource) {
      throw StateError('No album art found in the selected music file.');
    }
    return sourcePath;
  }

  @override
  Future<void> saveSongArtwork(int songId, String sourcePath) async {
    savedArtworkPath = sourcePath;
  }

  @override
  Future<void> saveAlbumArtwork(String albumName, String sourcePath) async {
    savedAlbumArtworkName = albumName;
    savedAlbumArtworkPath = sourcePath;
    final completer = saveAlbumArtworkCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<void> deleteAlbumArtwork(String albumName) async {
    deletedAlbumArtworkName = albumName;
  }

  @override
  Future<void> deleteSongArtwork(int songId) async {
    deletedArtworkSongId = songId;
    final completer = deleteSongArtworkCompleter;
    if (completer != null) {
      await completer.future;
    }
  }
}

class _CapturingFilePickerPlatform extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  String? dialogTitle;
  FileType? type;
  List<String>? allowedExtensions;
  FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    this.dialogTitle = dialogTitle;
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    return result;
  }
}

const _defaultRecommendedSong = LibrarySong(
  id: 2,
  path: 'match.mp3',
  title: 'Match Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 4,
  lyricsOffsetMs: 0,
  dateAdded: '2026-01-01T00:00:00Z',
  favorite: false,
  thumbnailPath: '',
);

BoxDecoration _closeButtonSurface(WidgetTester tester) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey('popup-dialog-close-button-surface')),
  );
  return decoratedBox.decoration as BoxDecoration;
}

String _electronIconSvg(WidgetTester tester, String name) {
  return tester
      .widget<SvgIcon>(
        find.byKey(ValueKey('MusicDialog.ElectronIcon.$name')).last,
      )
      .svg;
}

void _expectElectronIconSvg(
  WidgetTester tester,
  String name,
  String pathFragment,
) {
  expect(_electronIconSvg(tester, name), contains(pathFragment));
}

BoxDecoration _textFieldFrameDecoration(WidgetTester tester, String text) {
  final frame = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.widgetWithText(TextField, text).first,
          matching: find.byKey(
            const ValueKey('MusicDialog.DialogTextFieldFrame'),
          ),
        )
        .first,
  );
  return frame.decoration as BoxDecoration;
}

BoxDecoration _textIconButtonDecoration(WidgetTester tester, Finder button) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.descendant(of: button, matching: find.byType(DecoratedBox)).first,
  );
  return decoratedBox.decoration as BoxDecoration;
}

TextSelectionThemeData _textSelectionThemeForTextField(
  WidgetTester tester,
  String text,
) {
  final theme = tester.widget<TextSelectionTheme>(
    find
        .ancestor(
          of: find.widgetWithText(TextField, text).first,
          matching: find.byKey(
            const ValueKey('MusicDialog.TextSelectionTheme'),
          ),
        )
        .first,
  );
  return theme.data;
}

void _expectElectronSelectionColor(Color? color) {
  expect(color, isNotNull);
  expect(color!.a, moreOrLessEquals(0.22, epsilon: 0.001));
  expect(color.r, 0);
  expect(color.g, moreOrLessEquals(120 / 255, epsilon: 0.001));
  expect(color.b, moreOrLessEquals(215 / 255, epsilon: 0.001));
}

Future<void> _expectMusicDialogCommandEnabled(
  WidgetTester tester,
  String label,
  bool enabled,
) async {
  final inlineButtonFinder = find.widgetWithText(TextButton, label);
  if (inlineButtonFinder.evaluate().isNotEmpty) {
    final button = tester.widget<TextButton>(inlineButtonFinder.first);
    expect(
      button.onPressed,
      enabled ? isNotNull : isNull,
      reason: '$label should be ${enabled ? 'enabled' : 'disabled'}',
    );
    return;
  }

  final moreButton = find.byKey(
    const ValueKey('MusicDialog.CommandBar.MoreButton'),
  );
  expect(
    moreButton,
    findsOneWidget,
    reason: '$label should be visible or overflowed into More',
  );
  await tester.tap(moreButton);
  await tester.pump();

  final itemTextFinder = find.text(label).last;
  expect(itemTextFinder, findsOneWidget);
  final itemGestureFinder =
      find
          .ancestor(
            of: itemTextFinder,
            matching: find.byWidgetPredicate(
              (widget) => widget is GestureDetector,
            ),
          )
          .last;
  final itemGesture = tester.widget<GestureDetector>(itemGestureFinder);
  expect(
    itemGesture.onTap,
    enabled ? isNotNull : isNull,
    reason:
        '$label overflow item should be ${enabled ? 'enabled' : 'disabled'}',
  );

  await tester.tap(find.byType(TextField).last, warnIfMissed: false);
  await tester.pump();
}

BoxDecoration? _textFieldFrameInsetTopHighlight(
  WidgetTester tester,
  String text,
) {
  final frameFinder =
      find
          .ancestor(
            of: find.widgetWithText(TextField, text).first,
            matching: find.byKey(
              const ValueKey('MusicDialog.DialogTextFieldFrame'),
            ),
          )
          .first;
  final highlightFinder = find.descendant(
    of: frameFinder,
    matching: find.byKey(const ValueKey('MusicDialog.FieldInsetTopHighlight')),
  );
  if (highlightFinder.evaluate().isEmpty) {
    return null;
  }
  final box = tester.widget<DecoratedBox>(highlightFinder.first);
  return box.decoration as BoxDecoration;
}

Future<void> _openAlbumArtLibraryPicker(
  WidgetTester tester,
  _FakeMusicDialogRepository repository, {
  LibrarySong song = _currentSong,
  Brightness? brightness,
  VisualDensity? visualDensity,
  bool clearArtworkRequestsBeforeLibraryOpen = false,
}) async {
  await tester.pumpWidget(
    _MusicDialogTestApp(
      repository: repository,
      initialMode: SongDialogMode.albumArt,
      song: song,
      brightness: brightness,
      visualDensity: visualDensity,
    ),
  );
  await tester.pumpAndSettle();
  if (clearArtworkRequestsBeforeLibraryOpen) {
    repository.artworkSnapshotRequests.clear();
  }

  await tester.tap(find.widgetWithText(TextButton, 'Change Artwork'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose from library'));
  await tester.pumpAndSettle();
}

void _focusAlbumArtLibraryChoice(WidgetTester tester, int songId) {
  final choice = find.byKey(ValueKey('AlbumArtLibraryPicker.Choice.$songId'));
  final choiceInkWell = find.descendant(
    of: choice,
    matching: find.byType(InkWell),
  );
  Focus.of(tester.element(choiceInkWell)).requestFocus();
}

const _currentSong = LibrarySong(
  id: 1,
  path: 'song.mp3',
  title: 'Current Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-01-01T00:00:00Z',
  favorite: false,
  thumbnailPath: '',
);

const _secondSong = LibrarySong(
  id: 2,
  path: 'match.mp3',
  title: 'Match Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 4,
  lyricsOffsetMs: 0,
  dateAdded: '2026-01-01T00:00:00Z',
  favorite: false,
  thumbnailPath: '',
);

LibrarySong _librarySong({
  required int id,
  required String title,
  required String album,
  String artist = 'Artist',
  List<String> artists = const ['Artist'],
  String path = 'song.mp3',
  int playCount = 4,
}) {
  return LibrarySong(
    id: id,
    path: path,
    title: title,
    artist: artist,
    artists: artists,
    album: album,
    duration: 180,
    playCount: playCount,
    lyricsOffsetMs: 0,
    dateAdded: '2026-01-01T00:00:00Z',
    favorite: false,
    thumbnailPath: '',
  );
}

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.add': 'Add',
    'common.album': 'Album',
    'common.albumUnknown': 'Unknown Album',
    'common.artist': 'Artist',
    'common.artistSeparator': ' / ',
    'common.artistUnknown': 'Unknown Artist',
    'common.cancel': 'Cancel',
    'common.clear': 'Clear',
    'common.close': 'Close',
    'common.comma': '、',
    'common.confirm': 'Confirm',
    'common.duration': 'Duration',
    'common.import': 'Import',
    'common.playCount': 'Play Count',
    'common.reset': 'Reset',
    'common.search': 'Search',
    'common.yes': 'Yes',
    'context.pause': 'Pause',
    'context.play': 'Play',
    'context.seeAlbumArt': 'See Album Art',
    'context.seeLyrics': 'See Lyrics',
    'context.seeMusicInfo': 'See Music Info',
    'local.path': 'Path',
    'nowPlaying.loading': 'Loading',
    'nowPlaying.noLyrics': 'No Lyrics',
    'player.more': 'More',
    'playlists.delete': 'Delete',
    'playlists.removeSelected': 'Remove',
    'settings.save': 'Save',
    'settings.loadUsingFilename':
        'Use filename instead of music name when loading a music file.',
    'song.syncTitleToFilename': 'Sync to filename "{filename}"',
    'song.albumArtDeleted': 'Album art deleted',
    'song.albumArtRecommendationPrefix': 'Smart match: use {artist}\'s ',
    'song.albumArtRecommendationSuffix': ' as the cover',
    'song.albumArtRecommendationTitle': '"{title}"',
    'song.albumArtReset': 'Album art reset',
    'song.albumArtSaved': 'New album art has been saved!',
    'song.albumArtist': 'Album Artist',
    'song.bitrate': 'Bitrate',
    'song.changeArtwork': 'Change Artwork',
    'song.chooseAlbumArtwork': 'Choose Album Artwork',
    'song.chooseArtworkFromLibrary': 'Choose from library',
    'song.chooseArtworkFromLocal': 'Choose local file',
    'song.clearPlayCount': 'Clear',
    'song.hasBeenPlayed': '"{title}" has been played {count} times.',
    'song.resetPlayCountToZero': 'Reset to 0',
    'song.composers': 'Composers',
    'song.dateCreated': 'Date Created',
    'song.dateModified': 'Date Modified',
    'song.discardChanges': 'Discard Changes',
    'song.discardLyricsConfirm': 'Discard unsaved lyrics changes?',
    'song.fileSize': 'File Size',
    'song.fileType': 'File Type',
    'song.genre': 'Genre',
    'song.getLyricsFailed': 'Failed to get lyrics. Please try again later.',
    'song.importLyrics': 'Import lyrics',
    'song.importLyricsFailed': 'Failed to import lyrics.',
    'song.lyricsReset': 'Lyrics reset',
    'song.lyricsUpdated': 'The lyrics of "{title}" have been updated!',
    'song.lyricsUpdatedAndRefreshed':
        'The lyrics of "{savedTitle}" have been updated. Now showing the lyrics of "{currentTitle}".',
    'song.musicNoAlbumArt': '"{title}" does not have album art!',
    'song.notPlayedYet': '"{title}" has not been played yet.',
    'song.noAlbumArt': 'No album art',
    'song.noLibraryArtwork': 'No available album art in the library',
    'song.nothingChanged': 'No changes were detected.',
    'song.openBrowserSuccessful': 'Browser opened.',
    'song.pendingSaveLyrics':
        'The lyrics of "{title}" have been changed but not saved.',
    'song.processingRequest': 'Processing',
    'song.propertiesReset': 'Properties reset',
    'song.propertiesUpdated': 'Properties updated',
    'song.publisher': 'Publisher',
    'song.removeAlbumArt': 'Remove {title} art?',
    'song.searchLibraryArtwork': 'Search songs, artists, or albums',
    'song.searchLyricsFailed': 'No matching lyrics found.',
    'song.saveImmediately': 'Save Immediately',
    'song.showInExplorer': 'Show in Explorer',
    'song.showLyricsTimestamps': 'Show timestamps',
    'song.subtitle': 'Subtitle',
    'song.trackNumber': 'Track Number',
    'song.updateFailed': 'Update failed',
    'song.useSelectedArtwork': 'Use this cover',
    'song.year': 'Year',
    'sidebar.recentSearches': 'Recent searches',
    'sidebar.removeRecentSearch': 'Remove {query}',
    'table.title': 'Title',
  },
);
