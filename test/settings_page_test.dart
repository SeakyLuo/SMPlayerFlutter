import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
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
      'common.folders': '音乐文件夹',
      'settings.autoPlay': '打开应用后自动播放歌曲',
      'settings.batchAddLyrics': '批量添加歌词',
      'settings.batchAddLyricsCopy': '为所有歌曲搜索并添加歌词。已有歌词不会重复写入。',
      'settings.dataImported': '数据已导入，正在重新加载',
      'settings.desktopLyrics': '桌面歌词',
      'settings.desktopLyricsColor': '字体颜色',
      'settings.desktopLyricsFontFamily': '字体',
      'settings.desktopLyricsFontSize': '字体字号',
      'settings.desktopLyricsFontSystem': '系统默认',
      'settings.desktopLyricsOpacity': '文字透明度',
      'settings.desktopLyricsRestoreDefaults': '恢复默认',
      'settings.desktopLyricsStroke': '文字描边',
      'settings.desktopLyricsStrokeColor': '描边颜色',
      'settings.display': '显示',
      'settings.exportData': '导出数据',
      'settings.exportingData': '正在导出数据...',
      'settings.feedback': '提供反馈',
      'settings.hideMultiSelectCommandBar': '在操作后隐藏多选命令栏',
      'settings.importData': '导入数据',
      'settings.importDataConfirm': '导入数据会替换当前本地数据库并重新加载应用。继续吗？',
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
      'settings.lyricsBatchStarting': '正在准备歌词任务',
      'settings.musicFolderPlaceholder': '音乐库根目录路径',
      'settings.nightMode': '夜间模式',
      'settings.nightModeAuto': '自动',
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
      'settings.preferenceSettings': '偏好设置',
      'settings.quitOnClose': '关闭窗口时退出应用',
      'settings.releaseNotes': '更新日志',
      'settings.releaseNotesIntro': '版本历史',
      'settings.rescan': '正在刷新',
      'settings.saveProgress': '退出时保存播放进度',
      'settings.shuffleAfterOneRound': '播放一轮后重新随机排序',
      'settings.showCounts': '显示计数',
      'settings.smartMultiArtistFix': '智能修正歌手',
      'settings.smartMultiArtistFixPending': '正在分析...',
      'settings.smartMultiArtistRecognition': '智能识别多歌手',
      'settings.smartMultiArtistRecognitionHint':
          '更新文件夹时，如果音乐库中已有足够证据，会按支持的分隔符拆分歌曲歌手。',
      'settings.systemLog': '系统日志',
      'settings.viaEmail': '通过邮件',
      'settings.viaWebBrowser': '通过浏览器',
      'preferences.albums': '偏好专辑',
      'preferences.artists': '偏好歌手',
      'preferences.collapse': '收起列表',
      'preferences.expand': '展开列表',
      'preferences.folders': '偏好文件夹',
      'preferences.info': '偏好的项目会根据偏好程度以更高或更低的概率出现在「随机播放」->「快速播放」中。',
      'preferences.invalid': '无效',
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
    },
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
      const SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(home: SettingsPage()),
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
    expect(find.text('文字描边'), findsOneWidget);
    expect(find.text('字体字号'), findsOneWidget);
    expect(find.text('文字透明度'), findsOneWidget);
  });
}
