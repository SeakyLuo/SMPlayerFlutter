import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:smplayer_flutter/src/settings/settings_page.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'zh-CN',
    messages: {
      'app.shell': '简音播放器',
      'common.cancel': '取消',
      'common.close': '关闭',
      'common.confirm': '确认',
      'common.continue': '继续',
      'common.clear': '清除',
      'common.detail': '详情',
      'common.folders': '音乐文件夹',
      'common.settings': '设置',
      'library.root': '音乐文件夹',
      'library.refreshing': '正在刷新音乐库...',
      'common.pause': '暂停',
      'common.saved': '已保存',
      'common.start': '开始',
      'common.artistSeparator': '、',
      'settings.autoPlay': '打开应用后自动播放歌曲',
      'settings.autoLyrics': '自动为最近添加的歌曲添加歌词',
      'settings.batchAddLyrics': '批量添加歌词',
      'settings.batchAddLyricsCopy': '为所有歌曲搜索并添加歌词。已有歌词不会重复写入。',
      'settings.dataImported': '数据已导入，正在重新加载',
      'settings.dataImportFailed': '导入失败',
      'settings.dataExported': '数据已导出',
      'settings.dataExportFailed': '导出失败',
      'settings.desktopLyrics': '桌面歌词',
      'settings.desktopLyricsColor': '字体颜色',
      'settings.desktopLyricsFontFamily': '字体',
      'settings.desktopLyricsFontNoResults': '没有匹配的字体',
      'settings.desktopLyricsFontSearch': '搜索字体',
      'settings.desktopLyricsFontSize': '字体字号',
      'settings.desktopLyricsFontSystem': '系统默认',
      'settings.desktopLyricsLock': '锁定桌面歌词并让鼠标点击穿透',
      'settings.desktopLyricsOpacity': '文字透明度',
      'settings.desktopLyricsRestoreDefaults': '恢复默认',
      'settings.desktopLyricsResetOffset': '重置歌词偏移',
      'settings.desktopLyricsStroke': '文字描边',
      'settings.desktopLyricsStrokeColor': '描边颜色',
      'settings.display': '显示',
      'settings.exportData': '导出数据',
      'settings.exportDataHint': '导出数据可备份简音播放器的数据和设置，不包含本地音乐文件。',
      'settings.exportingData': '正在导出数据...',
      'settings.feedback': '提供反馈',
      'settings.hideMultiSelectCommandBar': '在操作后隐藏多选命令栏',
      'settings.importData': '导入数据',
      'settings.importDataConfirm': '导入数据会替换当前本地数据库并重新加载应用。继续吗？',
      'settings.importDataHint': '导入备份数据库来恢复数据。',
      'settings.importingData': '正在导入数据...',
      'settings.interfaceLanguage': '界面语言',
      'settings.languageChinese': '简体中文',
      'settings.languageChineseTraditional': '繁體中文',
      'settings.languageCzech': 'Čeština',
      'settings.languageDutch': 'Nederlands',
      'settings.languageEnglish': 'English',
      'settings.languageFrench': 'Français',
      'settings.languageGerman': 'Deutsch',
      'settings.languageIndonesian': 'Bahasa Indonesia',
      'settings.languageItalian': 'Italiano',
      'settings.languageJapanese': '日本語',
      'settings.languagePortugueseBrazil': 'Português (Brasil)',
      'settings.languageRussian': 'Русский',
      'settings.languageSpanish': 'Español',
      'settings.languageSystem': '跟随系统',
      'settings.languageSwedish': 'Svenska',
      'settings.languageUkrainian': 'Українська',
      'settings.loadUsingFilename': '加载音乐时使用文件名称而非音乐名称',
      'settings.loadUsingMusicName': '加载音乐时使用音乐名称而非文件名称',
      'settings.lyrics': '歌词',
      'settings.lyricsBatchBackedUp': '已备份',
      'settings.lyricsBatchCurrentLyrics': '当前歌词',
      'settings.lyricsBatchDetailNoLyrics': '无歌词',
      'settings.lyricsBatchDetailWrittenLyrics': '写入歌词',
      'settings.lyricsBatchFailed': '失败',
      'settings.lyricsBatchMissing': '未找到',
      'settings.lyricsBatchNewLyrics': '新歌词',
      'settings.lyricsBatchOverwritten': '覆盖',
      'settings.lyricsBatchSaved': '保存',
      'settings.lyricsBatchSkipped': '跳过',
      'settings.lyricsBatchStarting': '正在准备歌词任务',
      'settings.lyricsBatchTaskDetails': '歌词任务详情',
      'settings.musicFolderPlaceholder': '音乐库根目录路径',
      'settings.nightMode': '夜间模式',
      'settings.nightModeSystem': '跟随系统',
      'settings.nightModeAuto': '自定义',
      'settings.nightModeEndTime': '到',
      'settings.nightModeNever': '永不',
      'settings.nightModeOn': '开启',
      'settings.nightModeStartTime': '从',
      'settings.nightModeTimeRange': '夜间模式时间',
      'settings.notification': '通知',
      'settings.notificationSend': '发送通知',
      'settings.notificationSendMusicChanged': '音乐变更',
      'settings.notificationSendNever': '永不发送',
      'settings.openingExportData': '正在选择保存位置...',
      'settings.openingImportData': '正在打开本地文件...',
      'settings.others': '其他',
      'settings.play': '播放',
      'settings.playerLyricsSource': '播放器歌词来源',
      'settings.preferenceSettings': '偏好设置',
      'settings.preserveLyricsTimestamps': '保留网络歌词时间戳',
      'settings.preserveLyricsTimestampsHint': '获取网络歌词时保留 LRC 同步时间戳。',
      'settings.previousButtonRestartsTrack': '上一首按钮在播放超过 5 秒时回到开头',
      'settings.quitOnClose': '关闭窗口时退出应用',
      'settings.releaseNotes': '更新日志',
      'settings.releaseNotesArtists': '音乐可以按歌手和专辑分组。',
      'settings.releaseNotesIntro': '版本历史',
      'settings.releaseNotesLibrary': '设置中可以导入和导出数据。',
      'settings.releaseNotesUi': '可在设置中查看更新日志。',
      'settings.releaseNotesVersion': '版本',
      'releaseNotes.architectureFeedback': '本次更新进行了大量调整，欢迎通过设置进行反馈。',
      'settings.rescan': '正在刷新',
      'settings.saveProgress': '退出时保存播放进度',
      'settings.shuffleAfterOneRound': '播放一轮后重新随机排序',
      'settings.showCounts': '显示计数',
      'settings.sourceEmbedded': '音乐文件歌词',
      'settings.sourceInternet': '网络歌词',
      'settings.sourceLocal': 'LRC 文件歌词',
      'settings.smartMultiArtistFix': '智能修正歌手',
      'settings.smartMultiArtistFixConfirm': '智能修正',
      'settings.smartMultiArtistFixMessage': '是否现在扫描音乐库并生成多歌手更新建议？',
      'settings.smartMultiArtistFixPending': '正在分析...',
      'settings.smartMultiArtistRecognition': '智能识别多歌手',
      'settings.smartMultiArtistRecognitionHint':
          '更新文件夹时，如果音乐库中已有足够证据，会按支持的分隔符拆分歌曲歌手。',
      'settings.systemLog': '系统日志',
      'settings.viaEmail': '通过邮件',
      'library.scanning': '扫描中...',
      'local.updateFolderProgressActionChecking': '检查文件夹',
      'local.updateFolderProgressActionReading': '读取音乐',
      'local.updateFolderProgressActionUpdating': '更新音乐库',
      'local.updateFolderProgressAdded': '新增',
      'local.updateFolderProgressChecked': '已检查 {count}/{total}',
      'local.updateFolderProgressCurrentFolder': '当前文件夹：{name}',
      'local.updateFolderProgressMissing': '缺失',
      'local.updateFolderProgressProcessedSongs': '已处理 {count}/{total} 首',
      'local.updateFolderProgressStop': '停止更新',
      'local.updateFolderProgressStopConfirm': '停止更新',
      'local.updateFolderProgressStopConfirmMessage': '停止后会保留已经完成的检查。',
      'local.updateFolderProgressStopConfirmTitle': '停止更新文件夹？',
      'local.updateFolderProgressTitle': '正在更新文件夹',
      'local.updateFolderProgressUpdated': '更新',
      'settings.viaWebBrowser': '通过浏览器',
      'preferences.albums': '偏好专辑',
      'preferences.artists': '偏好歌手',
      'preferences.clearInvalid': '清理无效项',
      'preferences.collapse': '收起列表',
      'preferences.expand': '展开列表',
      'preferences.folders': '偏好文件夹',
      'preferences.info': '偏好的项目会根据偏好程度以更高或更低的概率出现在「随机播放」->「快速播放」中。',
      'preferences.invalid': '无效',
      'preferences.loading': '正在加载偏好设置...',
      'preferences.loadFailed': '偏好设置加载失败。',
      'preferences.builtin.recent-added': '最近添加',
      'preferences.builtin.my-favorites': '我喜欢',
      'preferences.builtin.most-played': '最多播放',
      'preferences.builtin.least-played': '最少播放',
      'preferences.level.dislike': '不喜欢',
      'preferences.level.do-not-appear': '不出现',
      'preferences.level.high': '高',
      'preferences.level.higher': '很高',
      'preferences.level.normal': '正常',
      'preferences.level.very-high': '非常高',
      'preferences.noItems': '没有项目。',
      'preferences.playlists': '偏好播放列表',
      'preferences.songs': '偏好歌曲',
      'playlists.removeSelected': '删除',
      'song.lyrics.auto': '自动',
      'local.applyingArtistSplits': '正在更新...',
      'local.applyArtistSplits': '全部拆分',
      'local.applySelectedArtistSplits': '更新歌手（{count}）',
      'local.artistSplitAfter': '拆分后',
      'local.artistMergeAfter': '合并后',
      'local.artistMergeSuggestionsTitle': '可以合并的歌手',
      'local.artistSplitOriginal': '原始',
      'local.artistSplitReviewTotal': '共 {count} 首歌',
      'local.directArtistSplitsGroup': '可以直接拆分（{count}）',
      'local.directArtistSplitsTitle': '可以直接拆分',
      'local.keepArtistSplits': '保持原样',
      'local.refreshArtistSplitSuggestionsGroup': '可能的多歌手（{count}）',
      'local.refreshArtistSplitSuggestionsTitle': '可能的多歌手',
      'local.startupArtistSplitSuggestionsTitle': '歌手更新建议',
      'local.selectAllArtistSplits': '全选',
      'local.clearArtistSplitSelection': '清空选择',
    },
  );

  setUp(() {
    resetSmPlayerGlobalSettingsSnapshot();
  });

  testWidgets('SettingsPage renders Electron cards and emits updates', (
    tester,
  ) async {
    AppSettingsUpdate? lastUpdate;

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: SettingsPage(
            onLoadSystemFonts: () async => const [],
            onUpdateSettings: (update) {
              lastUpdate = update;
            },
          ),
        ),
      ),
    );

    expect(find.text('音乐文件夹'), findsOneWidget);
    expect(find.text('桌面歌词'), findsOneWidget);
    expect(find.text('显示'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('打开应用后自动播放歌曲'));
    await tester.pump();

    expect(lastUpdate?.autoPlay, isTrue);

    await tester.tap(find.text('上一首按钮在播放超过 5 秒时回到开头'));
    await tester.pump();

    expect(lastUpdate?.previousButtonRestartsTrack, isFalse);
  });

  testWidgets('SettingsPage app version mirrors Electron footer alignment', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: [
              ShellThemeColors.light,
              DefaultAlbumArtworkThemeColors.light,
              AppNotificationThemeColors.light,
            ],
          ),
          home: Scaffold(
            body: SettingsPage(
              appVersion: '3.1.0',
              onLoadSystemFonts: () async => const [],
            ),
          ),
        ),
      ),
    );

    final footer = find.text('简音播放器 3.1.0');
    expect(footer, findsOneWidget);
    expect(tester.getCenter(footer).dx, closeTo(600, 1));
    final footerText = tester.widget<Text>(footer);
    expect(footerText.textAlign, TextAlign.center);
    expect(footerText.style?.fontSize, 12);
    expect(footerText.style?.height, 1.4);
  });

  testWidgets('SettingsPage lyrics rows mirror Electron order and hints', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: SettingsPage(
            onLoadSystemFonts: () async => const [],
            scanning: true,
            initialSnapshot: const SettingsSnapshot.defaults().copyWith(
              playerLyricsSource: LyricsRequestMode.internet,
            ),
          ),
        ),
      ),
    );

    expect(find.text('扫描中...'), findsNothing);
    expect(find.byTooltip('获取网络歌词时保留 LRC 同步时间戳。'), findsNothing);

    await tester.tap(find.text('网络歌词').first);
    await tester.pumpAndSettle();

    final autoTop = tester.getTopLeft(find.text('自动').first).dy;
    final internetTop = tester.getTopLeft(find.text('网络歌词').last).dy;
    final localTop = tester.getTopLeft(find.text('LRC 文件歌词')).dy;
    final embeddedTop = tester.getTopLeft(find.text('音乐文件歌词')).dy;
    expect(autoTop, lessThan(internetTop));
    expect(internetTop, lessThan(localTop));
    expect(localTop, lessThan(embeddedTop));
  });

  testWidgets('SettingsPage language options use Electron native labels', (
    tester,
  ) async {
    final englishI18n = SmPlayerI18n(
      locale: 'en-US',
      messages: {
        ...i18n.messages,
        'settings.languageSystem': 'System',
        'settings.languageChinese': 'Simplified Chinese',
        'settings.languageChineseTraditional': 'Traditional Chinese',
      },
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: englishI18n,
        child: MaterialApp(
          home: SettingsPage(onLoadSystemFonts: () async => const []),
        ),
      ),
    );

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('繁體中文'), findsOneWidget);
    expect(find.text('Simplified Chinese'), findsNothing);
    expect(find.text('Traditional Chinese'), findsNothing);
  });

  testWidgets('SettingsPage opens PreferenceSettingsPage dialog', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: SettingsPage(onLoadSystemFonts: () async => const []),
        ),
      ),
    );

    await tester.tap(find.text('偏好设置'));
    await tester.pumpAndSettle();

    expect(find.text('偏好歌曲'), findsOneWidget);
    expect(find.text('偏好歌手'), findsOneWidget);
    expect(find.text('偏好专辑'), findsOneWidget);
    expect(find.text('偏好播放列表'), findsOneWidget);
    expect(find.text('偏好文件夹'), findsOneWidget);
    expect(find.text('最近添加'), findsOneWidget);
    expect(find.text('我喜欢'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsPage shows desktop lyrics controls when enabled', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: SettingsPage(
            onLoadSystemFonts: () async => const [],
            initialSnapshot: const SettingsSnapshot.defaults().copyWith(
              nightMode: NightMode.auto,
              nightModeStartTime: '22:00',
              nightModeEndTime: '07:00',
              notificationSend: NotificationSendMode.musicChanged,
              desktopLyricsEnabled: true,
              shuffleAfterOneRound: false,
              hideMultiSelectCommandBarAfterOperation: false,
              quitOnClose: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('字体颜色'), findsOneWidget);
    expect(find.text('锁定桌面歌词并让鼠标点击穿透'), findsNothing);
    expect(find.text('文字描边'), findsOneWidget);
    expect(find.text('字体字号'), findsOneWidget);
    expect(find.text('文字透明度'), findsOneWidget);
    expect(find.text('重置歌词偏移'), findsNothing);

    await tester.ensureVisible(find.text('恢复默认'));
    await tester.pumpAndSettle();

    final restoreButton = find.widgetWithText(SettingsActionButton, '恢复默认');
    expect(tester.getSize(restoreButton).width, lessThan(180));
  });

  testWidgets('SettingsPage searches desktop lyrics system fonts', (
    tester,
  ) async {
    AppSettingsUpdate? lastUpdate;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
          home: SettingsPage(
            initialSnapshot: const SettingsSnapshot.defaults().copyWith(
              desktopLyricsEnabled: true,
            ),
            onLoadSystemFonts:
                () async => [
                  '.SFCompactRounded-Regular',
                  'Academy Engraved LET Fonts.ttf',
                  'Aptos',
                  'Segoe UI',
                ],
            onUpdateSettings: (update) {
              lastUpdate = update;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('系统默认'));
    await tester.tap(find.text('系统默认'));
    await tester.pumpAndSettle();

    expect(find.text('搜索字体'), findsOneWidget);
    final selectPanel = find.byWidgetPredicate((widget) {
      if (widget is! Container || widget.clipBehavior != Clip.antiAlias) {
        return false;
      }
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.borderRadius == BorderRadius.circular(10);
    });
    expect(tester.getSize(selectPanel).width, 240);
    expect(tester.getSize(find.text('搜索字体')).width, lessThan(80));
    expect(
      tester.getTopLeft(find.text('搜索字体')).dx,
      tester.getTopLeft(find.text('系统默认').last).dx,
    );
    expect(find.byTooltip('Academy Engraved LET Fonts.ttf'), findsOneWidget);
    final searchFieldContext = tester.element(find.byType(EditableText).last);
    expect(MediaQuery.textScalerOf(searchFieldContext).scale(13), 13);
    expect(find.text('.SFCompactRounded'), findsNothing);
    await tester.enterText(find.byType(EditableText).last, 'seg');
    await tester.pump();

    expect(find.text('Aptos'), findsNothing);
    expect(find.text('Segoe UI'), findsOneWidget);

    await tester.tap(find.text('Segoe UI'));
    await tester.pumpAndSettle();

    expect(lastUpdate?.desktopLyricsFontFamily, 'Segoe UI');
  });

  testWidgets('SettingsPage color control accepts arbitrary hex colors', (
    tester,
  ) async {
    AppSettingsUpdate? lastUpdate;

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: SettingsPage(
            initialSnapshot: const SettingsSnapshot.defaults().copyWith(
              desktopLyricsEnabled: true,
            ),
            onLoadSystemFonts: () async => const [],
            onPickColor: (_) async => '#123456',
            onUpdateSettings: (update) {
              lastUpdate = update;
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('#4AA8FF'));
    await tester.tap(find.text('#4AA8FF'));
    await tester.pump();

    expect(lastUpdate?.desktopLyricsColor, '#123456');
  });

  testWidgets('SettingsPage color control cancel keeps current value', (
    tester,
  ) async {
    AppSettingsUpdate? lastUpdate;

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: SettingsPage(
            initialSnapshot: const SettingsSnapshot.defaults().copyWith(
              desktopLyricsEnabled: true,
            ),
            onLoadSystemFonts: () async => const [],
            onPickColor: (_) async => null,
            onUpdateSettings: (update) {
              lastUpdate = update;
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('#4AA8FF'));
    await tester.tap(find.text('#4AA8FF'));
    await tester.pumpAndSettle();

    expect(lastUpdate, isNull);
    expect(find.text('确认'), findsNothing);
  });

  testWidgets(
    'SettingsPage notification mode mirrors Electron visibility flag',
    (tester) async {
      AppSettingsUpdate? lastUpdate;

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: SettingsPage(
              onLoadSystemFonts: () async => const [],
              onUpdateSettings: (update) {
                lastUpdate = update;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('永不发送'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('音乐变更').last);
      await tester.pump();

      expect(lastUpdate?.notificationSend, NotificationSendMode.musicChanged);
      expect(lastUpdate?.showNotifications, isTrue);
    },
  );

  testWidgets(
    'SettingsPage picks a real library root instead of fallback path',
    (tester) async {
      AppSettingsUpdate? lastUpdate;
      var scanRequested = false;

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: SettingsPage(
              appVersion: '1.0.0',
              onLoadSystemFonts: () async => const [],
              onPickLibraryRoot: () async => '/Users/me/Music',
              onScanLibrary: (rootPath, {cancellation, onProgress}) {
                expect(rootPath, '/Users/me/Music');
                scanRequested = true;
                return null;
              },
              onUpdateSettings: (update) {
                lastUpdate = update;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('音乐文件夹'));
      await tester.pumpAndSettle();

      expect(lastUpdate?.rootPath, '/Users/me/Music');
      expect(scanRequested, isTrue);
    },
  );

  testWidgets('SettingsPage library root shows full path tooltip', (
    tester,
  ) async {
    const rootPath = '/Users/me/Music/Albums/Very/Long/Folder';

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: [
              ShellThemeColors.light,
              DefaultAlbumArtworkThemeColors.light,
              AppNotificationThemeColors.light,
            ],
          ),
          home: Scaffold(
            body: SettingsPage(
              initialSnapshot: SettingsSnapshot.defaults().copyWith(
                rootPath: rootPath,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip(rootPath), findsOneWidget);
  });

  testWidgets('SettingsPage folder scan shows progress and can cancel', (
    tester,
  ) async {
    final repository =
        _FakeScanRepository()
          ..holdScanOpen = true
          ..emitProgress = true;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: SettingsPage(
            initialSnapshot: const SettingsSnapshot.defaults().copyWith(
              rootPath: '/Users/me/Music',
            ),
            onLoadSystemFonts: () async => const [],
            onPickLibraryRoot: () async => '/Users/me/Music',
            libraryRepository: repository,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('音乐文件夹'));
    await tester.pump();

    expect(find.text('正在更新文件夹'), findsOneWidget);
    expect(find.text('读取音乐'), findsOneWidget);
    expect(find.text('停止更新'), findsOneWidget);

    await tester.tap(find.text('停止更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停止更新').last);
    await tester.pump();

    expect(repository.cancellation?.isCanceled, isTrue);

    repository.completeScan();
    await tester.pumpAndSettle();
  });

  testWidgets('SettingsPage analyzes and applies smart artist fixes', (
    tester,
  ) async {
    final directSplit = ArtistSplitResultItem(
      songId: 99,
      title: 'Collab Song',
      artist: 'Alpha / Beta',
      artists: const ['Alpha', 'Beta'],
    );
    final repository = _FakeLibraryRepository(
      ArtistSplitAnalysisResult(
        directSplits: [directSplit],
        possibleSplits: const [],
        mergeSuggestions: const [],
      ),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: [
              ShellThemeColors.light,
              DefaultAlbumArtworkThemeColors.light,
              AppNotificationThemeColors.light,
            ],
          ),
          home: Scaffold(
            body: SettingsPage(
              libraryRepository: repository,
              onLoadSystemFonts: () async => const [],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('智能修正歌手'));
    await tester.pumpAndSettle();

    expect(find.text('是否现在扫描音乐库并生成多歌手更新建议？'), findsOneWidget);

    await tester.tap(find.text('智能修正'));
    await tester.pumpAndSettle();

    expect(repository.analyzeRequested, isTrue);
    expect(find.text('歌手更新建议'), findsOneWidget);
    expect(find.text('Collab Song'), findsOneWidget);
    expect(find.text('Alpha / Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('更新歌手（1）'), findsOneWidget);
    expect(find.text('99'), findsNothing);

    await tester.tap(find.text('更新歌手（1）'));
    await tester.pumpAndSettle();

    expect(repository.appliedSplits, [directSplit]);
    expect(find.text('歌手更新建议'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'SettingsPage includes artist merge suggestions in review apply',
    (tester) async {
      final mergeSuggestion = ArtistSplitResultItem(
        songId: 100,
        title: 'Merge Song',
        artist: 'Jay',
        artists: const ['Jay Chou'],
      );
      final repository = _FakeLibraryRepository(
        ArtistSplitAnalysisResult(
          directSplits: const [],
          possibleSplits: const [],
          mergeSuggestions: [mergeSuggestion],
        ),
      );

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: [
                ShellThemeColors.light,
                DefaultAlbumArtworkThemeColors.light,
                AppNotificationThemeColors.light,
              ],
            ),
            home: Scaffold(
              body: SettingsPage(
                libraryRepository: repository,
                onLoadSystemFonts: () async => const [],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('智能修正歌手'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('智能修正'));
      await tester.pumpAndSettle();

      expect(find.text('可以合并的歌手'), findsOneWidget);
      expect(find.text('Merge Song'), findsOneWidget);
      expect(find.text('合并后'), findsOneWidget);
      expect(find.text('Jay Chou'), findsOneWidget);

      await tester.tap(find.text('全选'));
      await tester.pump();
      await tester.tap(find.text('更新歌手（1）'));
      await tester.pumpAndSettle();

      expect(repository.appliedSplits, [mergeSuggestion]);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('SettingsPage applies edited smart artist split values', (
    tester,
  ) async {
    final directSplit = ArtistSplitResultItem(
      songId: 101,
      title: 'Edit Split Song',
      artist: 'Alpha / Beta',
      artists: const ['Alpha', 'Beta'],
    );
    final repository = _FakeLibraryRepository(
      ArtistSplitAnalysisResult(
        directSplits: [directSplit],
        possibleSplits: const [],
        mergeSuggestions: const [],
      ),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: [
              ShellThemeColors.light,
              DefaultAlbumArtworkThemeColors.light,
              AppNotificationThemeColors.light,
            ],
          ),
          home: Scaffold(
            body: SettingsPage(
              libraryRepository: repository,
              onLoadSystemFonts: () async => const [],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('智能修正歌手'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('智能修正'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FluentIcons.edit_20_regular));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Beta'), 'Gamma');
    await tester.tap(find.byIcon(FluentIcons.checkmark_20_regular).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新歌手（1）'));
    await tester.pumpAndSettle();

    expect(repository.appliedSplits.single.songId, 101);
    expect(repository.appliedSplits.single.artists, ['Alpha', 'Gamma']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('SettingsPage import and export actions return to idle', (
    tester,
  ) async {
    var exportRequested = false;
    var importRequested = false;
    var dataImported = false;

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              appVersion: '1.0.0',
              onLoadSystemFonts: () async => const [],
              onExportData: () async {
                exportRequested = true;
                return true;
              },
              onImportData: () async {
                importRequested = true;
                return true;
              },
              onDataImported: () {
                dataImported = true;
              },
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('导出数据'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('导出数据'));
    await tester.pump();
    await tester.pump();

    expect(exportRequested, isTrue);
    expect(find.text('正在导出数据...'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('导入数据'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('导入数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pump();
    await tester.pump();

    expect(importRequested, isTrue);
    expect(dataImported, isTrue);
    expect(find.text('数据已导入，正在重新加载'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('正在导入数据...'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('SettingsPage can pause and resume lyrics batch', (tester) async {
    final repository = _FakeLyricsBatchRepository();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              libraryRepository: repository,
              lyricsBatchSongCount: 1,
              onLoadSystemFonts: () async => const [],
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('批量添加歌词'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('批量添加歌词'));
    await tester.pump();
    await tester.tap(find.text('开始'));
    await tester.pump();

    expect(repository.started, isTrue);
    expect(find.text('暂停'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    repository.releaseBeforePauseWait();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text('继续'), findsOneWidget);
    expect(repository.completed, isFalse);

    await tester.tap(find.text('继续'));
    repository.finish();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(repository.completed, isTrue);
    expect(find.text('暂停'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('SettingsPage disables lyrics batch until songs are loaded', (
    tester,
  ) async {
    final repository = _FakeLyricsBatchRepository();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              libraryRepository: repository,
              onLoadSystemFonts: () async => const [],
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('批量添加歌词'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    if (find.text('清除').evaluate().isNotEmpty) {
      await tester.tap(find.text('清除'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('批量添加歌词'));
    await tester.pump();

    expect(repository.started, isFalse);
    expect(find.text('开始'), findsNothing);
  });

  testWidgets('SettingsPage mirrors Electron canceling lyrics batch state', (
    tester,
  ) async {
    final repository = _FakeLyricsBatchRepository();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              libraryRepository: repository,
              lyricsBatchSongCount: 1,
              onLoadSystemFonts: () async => const [],
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('批量添加歌词'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    if (find.text('清除').evaluate().isNotEmpty) {
      await tester.tap(find.text('清除'));
      await tester.pumpAndSettle();
    }
    if (find.text('开始').evaluate().isEmpty) {
      await tester.tap(find.widgetWithText(SettingsActionButton, '批量添加歌词'));
      await tester.pump();
    }
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pump();

    expect(find.text('暂停'), findsNothing);
    expect(find.text('继续'), findsNothing);
    expect(find.text('批量添加歌词'), findsOneWidget);

    await tester.tap(find.text('批量添加歌词'));
    await tester.pump();

    expect(find.text('开始'), findsNothing);
    repository.releaseBeforePauseWait();
    repository.finish();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'SettingsPage lyrics batch details expand one row like Electron',
    (tester) async {
      final repository = _FakeLyricsBatchRepository(
        result: const LyricsBatchResult(
          total: 2,
          saved: 2,
          overwritten: 0,
          skipped: 0,
          missing: 0,
          failed: 0,
          backedUp: 0,
          backupBytes: 0,
          details: [
            LyricsBatchDetail(
              songId: 1,
              title: 'Track A',
              artist: 'Artist A',
              thumbnailPath: '',
              result: LyricsBatchDetailResult.saved,
              targetRawLyrics: 'Lyrics A',
            ),
            LyricsBatchDetail(
              songId: 2,
              title: 'Track B',
              artist: 'Artist B',
              thumbnailPath: '',
              result: LyricsBatchDetailResult.saved,
              targetRawLyrics: 'Lyrics B',
            ),
          ],
        ),
      );

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: Scaffold(
              body: SettingsPage(
                libraryRepository: repository,
                lyricsBatchSongCount: 2,
                onLoadSystemFonts: () async => const [],
              ),
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('批量添加歌词'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('批量添加歌词'));
      await tester.pump();
      await tester.tap(find.text('开始'));
      repository.releaseBeforePauseWait();
      repository.finish();
      await tester.pumpAndSettle();

      await tester.tap(find.text('详情'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Track A'));
      await tester.pumpAndSettle();

      expect(find.text('Lyrics A'), findsOneWidget);
      expect(find.text('Lyrics B'), findsNothing);

      await tester.tap(find.text('Track B'));
      await tester.pumpAndSettle();

      expect(find.text('Lyrics A'), findsNothing);
      expect(find.text('Lyrics B'), findsOneWidget);
    },
  );

  testWidgets('PreferenceSettingsPage updates and clears concrete sections', (
    tester,
  ) async {
    final repository = _FakePreferenceRepository(_preferenceSnapshot);
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: PreferenceSettingsPage(
            initialSnapshot: _preferenceSnapshot,
            libraryRepository: repository,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('Song A'), findsOneWidget);
    expect(find.text('Missing Song'), findsOneWidget);

    final itemSwitch = tester.widget<Switch>(find.byType(Switch).at(1));
    expect(itemSwitch.value, isTrue);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();

    final updatedItemSwitch = tester.widget<Switch>(find.byType(Switch).at(1));
    expect(updatedItemSwitch.value, isFalse);
    expect(repository.updatedItemId, 1);
    expect(repository.updatedItemEnabled, isFalse);

    await tester.tap(find.text('清理无效项'));
    await tester.pump();

    expect(find.text('Missing Song'), findsNothing);
    expect(repository.clearedInvalidType, PreferenceEntityType.song);

    await tester.tap(find.byTooltip('删除'));
    await tester.pump();

    expect(find.text('Song A'), findsNothing);
    expect(repository.removedItemId, 1);
  });
}

const _preferenceSnapshot = PreferenceSettingsSnapshot(
  enabled: {
    PreferenceSectionKey.songs: true,
    PreferenceSectionKey.artists: true,
    PreferenceSectionKey.albums: true,
    PreferenceSectionKey.playlists: true,
    PreferenceSectionKey.folders: true,
  },
  songs: [
    PreferenceItemSnapshot(
      id: 1,
      type: PreferenceEntityType.song,
      itemId: '1',
      name: 'Song A',
      tooltip: 'Song A',
      isEnabled: true,
      level: PreferenceLevel.high,
      isValid: true,
      canRemove: true,
    ),
    PreferenceItemSnapshot(
      id: 2,
      type: PreferenceEntityType.song,
      itemId: '2',
      name: 'Missing Song',
      tooltip: 'Missing Song',
      isEnabled: true,
      level: PreferenceLevel.dislike,
      isValid: false,
      canRemove: true,
    ),
  ],
  artists: [],
  albums: [],
  playlists: [],
  folders: [],
  others: [],
);

class _FakeLibraryRepository extends LibraryRepository {
  _FakeLibraryRepository(this.result);

  final ArtistSplitAnalysisResult result;
  var analyzeRequested = false;
  List<ArtistSplitResultItem> appliedSplits = const [];

  @override
  Future<ArtistSplitAnalysisResult> analyzeArtistSplits() async {
    analyzeRequested = true;
    return result;
  }

  @override
  Future<void> applyArtistSplits(List<ArtistSplitResultItem> splits) async {
    appliedSplits = splits;
  }
}

class _FakeLyricsBatchRepository extends LibraryRepository {
  _FakeLyricsBatchRepository({this.result = _defaultResult});

  static const _defaultResult = LyricsBatchResult(
    total: 1,
    saved: 1,
    overwritten: 0,
    skipped: 0,
    missing: 0,
    failed: 0,
    backedUp: 0,
    backupBytes: 0,
    details: [],
  );

  final LyricsBatchResult result;
  final _beforePauseWait = Completer<void>();
  final _finish = Completer<void>();
  var started = false;
  var completed = false;

  void releaseBeforePauseWait() {
    if (!_beforePauseWait.isCompleted) {
      _beforePauseWait.complete();
    }
  }

  void finish() {
    if (!_finish.isCompleted) {
      _finish.complete();
    }
  }

  @override
  Future<LyricsBatchResult> batchAddInternetLyrics({
    bool overwrite = false,
    void Function(LyricsBatchProgress progress)? onProgress,
    bool Function()? isCanceled,
    Future<void> Function()? waitIfPaused,
  }) async {
    started = true;
    onProgress?.call(
      const LyricsBatchProgress(
        currentIndex: 1,
        total: 1,
        currentSongTitle: 'Track',
        saved: 0,
        overwritten: 0,
        skipped: 0,
        missing: 0,
        failed: 0,
        backedUp: 0,
        backupBytes: 0,
      ),
    );
    await _beforePauseWait.future;
    await waitIfPaused?.call();
    await _finish.future;
    completed = true;
    return result;
  }
}

class _FakeScanRepository extends LibraryRepository {
  String? scannedRootPath;
  LocalFolderScanCancellation? cancellation;
  var emitProgress = false;
  var holdScanOpen = false;
  Completer<void>? _scanCompleter;

  @override
  Future<LocalFolderRefreshResult> scanAllMusicLibrary(
    String rootPath, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    scannedRootPath = rootPath;
    this.cancellation = cancellation;
    if (emitProgress) {
      onProgress?.call(
        const LocalFolderRefreshProgress(
          current: 1,
          total: 3,
          currentPath: '/Users/me/Music/song.mp3',
          stage: LocalFolderRefreshStage.reading,
          processedSongCount: 1,
          songCount: 3,
          canCancel: true,
        ),
      );
    }
    if (holdScanOpen) {
      _scanCompleter = Completer<void>();
      await _scanCompleter!.future;
    }
    return const LocalFolderRefreshResult(
      filesAdded: [],
      filesRemoved: [],
      filesMoved: [],
      artistSplitsApplied: [],
      artistSplitSuggestions: [],
      artistMergeSuggestions: [],
    );
  }

  void completeScan() {
    _scanCompleter?.complete();
  }
}

class _FakePreferenceRepository extends LibraryRepository {
  _FakePreferenceRepository(this.snapshot);

  final PreferenceSettingsSnapshot snapshot;
  Map<PreferenceSectionKey, bool>? updatedSettings;
  int? updatedItemId;
  bool? updatedItemEnabled;
  PreferenceLevel? updatedItemLevel;
  int? removedItemId;
  PreferenceEntityType? clearedInvalidType;

  @override
  Future<PreferenceSettingsSnapshot> getPreferenceSettings() async {
    return snapshot;
  }

  @override
  Future<void> updatePreferenceSettings(
    Map<PreferenceSectionKey, bool> enabled,
  ) async {
    updatedSettings = enabled;
  }

  @override
  Future<void> updatePreferenceItem(
    int itemId, {
    bool? isEnabled,
    PreferenceLevel? level,
  }) async {
    updatedItemId = itemId;
    updatedItemEnabled = isEnabled;
    updatedItemLevel = level;
  }

  @override
  Future<void> removePreferenceItemById(int itemId) async {
    removedItemId = itemId;
  }

  @override
  Future<void> clearInvalidPreferenceItems(PreferenceEntityType type) async {
    clearedInvalidType = type;
  }
}
