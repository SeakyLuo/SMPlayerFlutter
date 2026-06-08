import Cocoa
import Carbon.HIToolbox
import FlutterMacOS
import MediaPlayer
import UserNotifications
import WebKit

class MainFlutterWindow: NSWindow, NSWindowDelegate, UNUserNotificationCenterDelegate {
  private static let mainWindowFrameAutosaveName = "SMPlayerMainWindowFrame"
  private static let mainWindowMinimumSize = NSSize(width: 506, height: 840)
  private static let functionPlaybackHotKeySignature: OSType = 0x534D504C
  private static let systemDefinedCGEventTypeRawValue: UInt32 = 14

  private var desktopFeatureChannel: FlutterMethodChannel?
  private var globalMediaEventMonitor: Any?
  private var localMediaEventMonitor: Any?
  private var mediaKeyEventTap: CFMachPort?
  private var mediaKeyEventTapRunLoopSource: CFRunLoopSource?
  private var functionPlaybackHotKeyHandler: EventHandlerRef?
  private var functionPlaybackHotKeyRefs: [EventHotKeyRef] = []
  private var externalOpenObserver: NSObjectProtocol?
  private var desktopLyricsPanel: NSPanel?
  private var desktopLyricsView: DesktopLyricsNativeView?
  private var nativeSplashView: NativeSplashView?
  private var mediaSessionCommandsInstalled = false
  private var externalOpenChannelReady = false
  private var securityScopedResourceUrls: [URL] = []

  override func awakeFromNib() {
    configureIntegratedTitlebar()
    acceptsMouseMovedEvents = true
    minSize = Self.mainWindowMinimumSize
    setFrameAutosaveName(Self.mainWindowFrameAutosaveName)
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    installNativeSplash(on: flutterViewController.view)

    RegisterGeneratedPlugins(registry: flutterViewController)
    desktopFeatureChannel = FlutterMethodChannel(
      name: "smplayer_flutter/desktop_features",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    desktopFeatureChannel?.setMethodCallHandler(handleDesktopFeatureMethodCall)
    UNUserNotificationCenter.current().delegate = self
    SmPlayerExternalFileAccessStore.shared.restoreAccess()
    restoreSecurityScopedDirectoryAccess()
    installMediaKeyMonitor()
    installFunctionPlaybackHotKeys()
    installExternalOpenObserver()

    super.awakeFromNib()
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      self.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private func configureIntegratedTitlebar() {
    title = ""
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
  }

  deinit {
    if let globalMediaEventMonitor = globalMediaEventMonitor {
      NSEvent.removeMonitor(globalMediaEventMonitor)
    }
    if let localMediaEventMonitor = localMediaEventMonitor {
      NSEvent.removeMonitor(localMediaEventMonitor)
    }
    if let mediaKeyEventTapRunLoopSource = mediaKeyEventTapRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), mediaKeyEventTapRunLoopSource, .commonModes)
    }
    if let mediaKeyEventTap = mediaKeyEventTap {
      CFMachPortInvalidate(mediaKeyEventTap)
    }
    for hotKeyRef in functionPlaybackHotKeyRefs {
      UnregisterEventHotKey(hotKeyRef)
    }
    if let functionPlaybackHotKeyHandler = functionPlaybackHotKeyHandler {
      RemoveEventHandler(functionPlaybackHotKeyHandler)
    }
    if let externalOpenObserver = externalOpenObserver {
      NotificationCenter.default.removeObserver(externalOpenObserver)
    }
    for url in securityScopedResourceUrls {
      url.stopAccessingSecurityScopedResource()
    }
  }

  private func installExternalOpenObserver() {
    externalOpenObserver = NotificationCenter.default.addObserver(
      forName: .smPlayerExternalOpenArguments,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.drainExternalOpenArguments()
    }
  }

  private func drainExternalOpenArguments() {
    if !externalOpenChannelReady {
      return
    }
    let arguments = SmPlayerExternalOpenArgumentsStore.shared.takePending()
    if arguments.isEmpty {
      return
    }
    desktopFeatureChannel?.invokeMethod(
      "openExternalArguments",
      arguments: arguments)
  }

  private func installMediaKeyMonitor() {
    installMediaKeyEventTap()
    globalMediaEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) {
      [weak self] event in
      _ = self?.handleSystemDefinedEvent(event)
    }
    localMediaEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) {
      [weak self] event in
      return self?.handleSystemDefinedEvent(event) == true ? nil : event
    }
  }

  private func installMediaKeyEventTap() {
    let eventMask = CGEventMask(1) << Self.systemDefinedCGEventTypeRawValue
    guard let eventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: eventMask,
      callback: { _, type, event, userInfo in
        guard let userInfo else {
          return Unmanaged.passUnretained(event)
        }
        let window = Unmanaged<MainFlutterWindow>
          .fromOpaque(userInfo)
          .takeUnretainedValue()
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
          if let mediaKeyEventTap = window.mediaKeyEventTap {
            CGEvent.tapEnable(tap: mediaKeyEventTap, enable: true)
          }
          return Unmanaged.passUnretained(event)
        }
        if type.rawValue != MainFlutterWindow.systemDefinedCGEventTypeRawValue {
          return Unmanaged.passUnretained(event)
        }
        if window.handleSystemDefinedCGEvent(event) {
          return nil
        }
        return Unmanaged.passUnretained(event)
      },
      userInfo: Unmanaged.passUnretained(self).toOpaque())
    else {
      return
    }
    mediaKeyEventTap = eventTap
    mediaKeyEventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    if let mediaKeyEventTapRunLoopSource = mediaKeyEventTapRunLoopSource {
      CFRunLoopAddSource(CFRunLoopGetMain(), mediaKeyEventTapRunLoopSource, .commonModes)
    }
    CGEvent.tapEnable(tap: eventTap, enable: true)
  }

  private func installFunctionPlaybackHotKeys() {
    var eventSpec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, userData in
        guard let event, let userData else {
          return noErr
        }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID)
        if status != noErr {
          return status
        }
        let window = Unmanaged<MainFlutterWindow>
          .fromOpaque(userData)
          .takeUnretainedValue()
        switch hotKeyID.id {
        case 1:
          window.sendDesktopCommand("previous")
        case 2:
          window.sendDesktopCommand("play-pause")
        case 3:
          window.sendDesktopCommand("next")
        default:
          break
        }
        return noErr
      },
      1,
      &eventSpec,
      Unmanaged.passUnretained(self).toOpaque(),
      &functionPlaybackHotKeyHandler)

    registerFunctionPlaybackHotKey(keyCode: UInt32(kVK_F7), id: 1)
    registerFunctionPlaybackHotKey(keyCode: UInt32(kVK_F8), id: 2)
    registerFunctionPlaybackHotKey(keyCode: UInt32(kVK_F9), id: 3)
  }

  private func registerFunctionPlaybackHotKey(keyCode: UInt32, id: UInt32) {
    var hotKeyRef: EventHotKeyRef?
    let hotKeyID = EventHotKeyID(signature: Self.functionPlaybackHotKeySignature, id: id)
    let status = RegisterEventHotKey(
      keyCode,
      0,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef)
    if status == noErr, let hotKeyRef {
      functionPlaybackHotKeyRefs.append(hotKeyRef)
    }
  }

  private func handleSystemDefinedEvent(_ event: NSEvent) -> Bool {
    if event.subtype.rawValue != 8 {
      return false
    }
    let keyCode = (event.data1 & 0xffff0000) >> 16
    let keyState = (event.data1 & 0x0000ff00) >> 8
    if keyState != 0x0a {
      return false
    }

    switch keyCode {
    case 16:
      sendDesktopCommand("play-pause")
      return true
    case 17:
      sendDesktopCommand("next")
      return true
    case 18:
      sendDesktopCommand("previous")
      return true
    case 20:
      sendDesktopCommand("stop")
      return true
    default:
      return false
    }
  }

  private func handleSystemDefinedCGEvent(_ event: CGEvent) -> Bool {
    guard let nsEvent = NSEvent(cgEvent: event) else {
      return false
    }
    return handleSystemDefinedEvent(nsEvent)
  }

  private func sendDesktopCommand(_ command: String) {
    desktopFeatureChannel?.invokeMethod("desktopCommand", arguments: command)
  }

  private func handleDesktopFeatureMethodCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    if call.method == "takeInitialExternalArguments" {
      externalOpenChannelReady = true
      result(SmPlayerExternalOpenArgumentsStore.shared.takePending())
      return
    }
    if call.method == "pickDirectory" {
      pickDirectory(arguments: call.arguments, result: result)
      return
    }
    if call.method == "dismissNativeSplash" {
      dismissNativeSplash()
      result(nil)
      return
    }
    if call.method == "updateDesktopLyricsWindow" {
      guard let state = flutterStringMap(call.arguments) else {
        result(FlutterError(
          code: "invalid_arguments",
          message: "updateDesktopLyricsWindow expects state.",
          details: nil))
        return
      }
      updateDesktopLyricsWindow(state)
      result(nil)
      return
    }
    if call.method == "updateMediaSession" {
      guard let state = flutterStringMap(call.arguments) else {
        result(FlutterError(
          code: "invalid_arguments",
          message: "updateMediaSession expects state.",
          details: nil))
        return
      }
      updateMediaSession(state)
      result(nil)
      return
    }
    if call.method == "showTrackNotification" {
      guard let payload = call.arguments as? [String: Any] else {
        result(FlutterError(
          code: "invalid_arguments",
          message: "showTrackNotification expects payload.",
          details: nil))
        return
      }
      showTrackNotification(payload)
      result(nil)
      return
    }
    result(FlutterMethodNotImplemented)
  }

  private func flutterStringMap(_ value: Any?) -> [String: Any]? {
    if let map = value as? [String: Any] {
      return map
    }
    guard let map = value as? [AnyHashable: Any] else {
      return nil
    }
    var result: [String: Any] = [:]
    for (key, item) in map {
      guard let key = key as? String else {
        return nil
      }
      result[key] = item
    }
    return result
  }

  private func pickDirectory(arguments: Any?, result: @escaping FlutterResult) {
    let arguments = flutterStringMap(arguments)
    applyPickerLanguage(arguments?["locale"] as? String)
    let panel = NSOpenPanel()
    if let title = arguments?["title"] as? String {
      panel.title = title
    }
    if let buttonLabel = arguments?["buttonLabel"] as? String {
      panel.prompt = buttonLabel
    }
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    panel.showsHiddenFiles = false
    if let defaultPath = arguments?["defaultPath"] as? String, !defaultPath.isEmpty {
      panel.directoryURL = URL(fileURLWithPath: defaultPath)
    } else {
      panel.directoryURL = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
    }
    panel.beginSheetModal(for: self) { response in
      guard response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      self.storeSecurityScopedDirectoryAccess(url)
      result(url.path)
    }
  }

  private func applyPickerLanguage(_ locale: String?) {
    guard let languages = Self.appleLanguages(for: locale) else {
      return
    }
    UserDefaults.standard.set(languages, forKey: "AppleLanguages")
    UserDefaults.standard.synchronize()
  }

  private static func appleLanguages(for locale: String?) -> [String]? {
    guard let locale, !locale.isEmpty else {
      return nil
    }
    let normalized = locale.replacingOccurrences(of: "_", with: "-").lowercased()
    if normalized == "system" {
      return nil
    }
    if normalized.hasPrefix("zh") {
      if normalized.contains("hant") ||
          normalized.contains("-tw") ||
          normalized.contains("-hk") ||
          normalized.contains("-mo") {
        return ["zh-Hant", "zh-Hant-HK", "en"]
      }
      return ["zh-Hans", "zh-Hans-CN", "en"]
    }
    if normalized.hasPrefix("pt-br") {
      return ["pt-BR", "pt", "en"]
    }
    if normalized.hasPrefix("en") {
      return ["en"]
    }
    if normalized.hasPrefix("fr") {
      return ["fr", "en"]
    }
    if normalized.hasPrefix("ru") {
      return ["ru", "en"]
    }
    if normalized.hasPrefix("ja") {
      return ["ja", "en"]
    }
    if normalized.hasPrefix("de") {
      return ["de", "en"]
    }
    if normalized.hasPrefix("es") {
      return ["es", "en"]
    }
    if normalized.hasPrefix("it") {
      return ["it", "en"]
    }
    if normalized.hasPrefix("nl") {
      return ["nl", "en"]
    }
    if normalized.hasPrefix("cs") {
      return ["cs", "en"]
    }
    if normalized.hasPrefix("uk") {
      return ["uk", "en"]
    }
    if normalized.hasPrefix("sv") {
      return ["sv", "en"]
    }
    if normalized.hasPrefix("id") {
      return ["id", "en"]
    }
    return [locale, "en"]
  }

  private func storeSecurityScopedDirectoryAccess(_ url: URL) {
    do {
      let bookmarkData = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil)
      var bookmarks = UserDefaults.standard.dictionary(
        forKey: "securityScopedDirectoryBookmarks") as? [String: String] ?? [:]
      bookmarks[url.path] = bookmarkData.base64EncodedString()
      UserDefaults.standard.set(bookmarks, forKey: "securityScopedDirectoryBookmarks")
      startSecurityScopedAccess(url)
    } catch {
      NSLog("Simple Melody Player failed to store directory bookmark: \(error)")
    }
  }

  private func restoreSecurityScopedDirectoryAccess() {
    let bookmarks = UserDefaults.standard.dictionary(
      forKey: "securityScopedDirectoryBookmarks") as? [String: String] ?? [:]
    var nextBookmarks: [String: String] = [:]
    for (path, encodedBookmark) in bookmarks {
      guard let bookmarkData = Data(base64Encoded: encodedBookmark) else {
        continue
      }
      do {
        var isStale = false
        let url = try URL(
          resolvingBookmarkData: bookmarkData,
          options: [.withSecurityScope],
          relativeTo: nil,
          bookmarkDataIsStale: &isStale)
        startSecurityScopedAccess(url)
        if isStale {
          let refreshedBookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil)
          nextBookmarks[url.path] = refreshedBookmark.base64EncodedString()
        } else {
          nextBookmarks[path] = encodedBookmark
        }
      } catch {
        NSLog("Simple Melody Player failed to restore directory bookmark: \(error)")
      }
    }
    UserDefaults.standard.set(nextBookmarks, forKey: "securityScopedDirectoryBookmarks")
  }

  private func startSecurityScopedAccess(_ url: URL) {
    if securityScopedResourceUrls.contains(url) {
      return
    }
    if url.startAccessingSecurityScopedResource() {
      securityScopedResourceUrls.append(url)
    }
  }

  private func installNativeSplash(on parentView: NSView) {
    let splashView = NativeSplashView(frame: parentView.bounds)
    splashView.autoresizingMask = [.width, .height]
    parentView.addSubview(splashView)
    nativeSplashView = splashView
  }

  private func dismissNativeSplash() {
    guard let splashView = nativeSplashView else {
      return
    }
    nativeSplashView = nil
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.18
      splashView.animator().alphaValue = 0
    } completionHandler: {
      splashView.removeFromSuperview()
    }
  }

  private func showTrackNotification(_ payload: [String: Any]) {
    let content = UNMutableNotificationContent()
    content.title = (payload["title"] as? String) ?? ""
    content.body = (payload["body"] as? String) ?? ""
    if !((payload["silent"] as? Bool) ?? false) {
      content.sound = .default
    }
    content.userInfo = ["songId": payload["songId"] ?? 0]

    let request = UNNotificationRequest(
      identifier: "smplayer-track-\(payload["songId"] ?? 0)-\(Date().timeIntervalSince1970)",
      content: content,
      trigger: nil)
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
      if !granted {
        return
      }
      UNUserNotificationCenter.current().add(request)
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if isMiniaturized {
      deminiaturize(nil)
    }
    makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    completionHandler()
  }

  private func updateMediaSession(_ state: [String: Any]) {
    installMediaSessionCommandCenter()
    guard (state["active"] as? Bool) == true else {
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      MPNowPlayingInfoCenter.default().playbackState = .stopped
      return
    }

    let playing = (state["playing"] as? Bool) ?? false
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: (state["title"] as? String) ?? "",
      MPMediaItemPropertyArtist: (state["artist"] as? String) ?? "",
      MPMediaItemPropertyAlbumTitle: (state["album"] as? String) ?? "",
      MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
      MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
      MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: (state["progressSeconds"] as? Double) ?? 0,
    ]
    let duration = (state["durationSeconds"] as? Double) ?? 0
    if duration > 0 {
      info[MPMediaItemPropertyPlaybackDuration] = duration
    }
    if let artworkPath = state["artworkPath"] as? String,
       !artworkPath.isEmpty,
       let image = NSImage(contentsOfFile: artworkPath) {
      info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
        boundsSize: image.size
      ) { _ in image }
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    MPNowPlayingInfoCenter.default().playbackState = playing ? .playing : .paused
  }

  private func installMediaSessionCommandCenter() {
    if mediaSessionCommandsInstalled {
      return
    }
    mediaSessionCommandsInstalled = true
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget { [weak self] _ in
      self?.sendDesktopCommand("play")
      return .success
    }
    commandCenter.pauseCommand.isEnabled = true
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      self?.sendDesktopCommand("pause")
      return .success
    }
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.sendDesktopCommand("play-pause")
      return .success
    }
    commandCenter.stopCommand.isEnabled = true
    commandCenter.stopCommand.addTarget { [weak self] _ in
      self?.sendDesktopCommand("stop")
      return .success
    }
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      self?.sendDesktopCommand("next")
      return .success
    }
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      self?.sendDesktopCommand("previous")
      return .success
    }
    commandCenter.changePlaybackPositionCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self?.desktopFeatureChannel?.invokeMethod(
        "desktopCommand",
        arguments: "seek-to:\(positionEvent.positionTime)")
      return .success
    }
  }

  private func updateDesktopLyricsWindow(_ state: [String: Any]) {
    guard (state["visible"] as? Bool) == true else {
      desktopLyricsPanel?.orderOut(nil)
      return
    }

    let panel = ensureDesktopLyricsPanel(bounds: state["bounds"] as? String)
    desktopLyricsView?.apply(state: state)
    panel.ignoresMouseEvents = false
    panel.isMovableByWindowBackground = (state["locked"] as? Bool) != true
    panel.orderFrontRegardless()
  }

  private func ensureDesktopLyricsPanel(bounds rawBounds: String?) -> NSPanel {
    if let panel = desktopLyricsPanel {
      return panel
    }

    let frame = resolveDesktopLyricsFrame(rawBounds)
    let panel = NSPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.hidesOnDeactivate = false
    panel.isMovableByWindowBackground = true
    panel.delegate = self
    let lyricsView = DesktopLyricsNativeView(frame: NSRect(origin: .zero, size: frame.size))
    lyricsView.onCommand = { [weak self] command in
      self?.sendDesktopCommand(command)
    }
    lyricsView.autoresizingMask = [.width, .height]
    panel.contentView = lyricsView
    desktopLyricsPanel = panel
    desktopLyricsView = lyricsView
    return panel
  }

  func windowDidMove(_ notification: Notification) {
    guard notification.object as? NSWindow === desktopLyricsPanel else {
      return
    }
    sendDesktopLyricsBounds()
  }

  private func sendDesktopLyricsBounds() {
    guard let panel = desktopLyricsPanel else {
      return
    }
    let frame = panel.frame
    let bounds = [
      "x": frame.origin.x,
      "y": frame.origin.y,
      "width": frame.size.width,
      "height": frame.size.height,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: bounds),
       let value = String(data: data, encoding: .utf8) {
      desktopFeatureChannel?.invokeMethod("desktopLyricsBoundsChanged", arguments: value)
    }
  }

  private func resolveDesktopLyricsFrame(_ rawBounds: String?) -> NSRect {
    let defaultSize = NSSize(width: 760, height: 148)
    if let rawBounds = rawBounds,
       let data = rawBounds.data(using: .utf8),
       let value = try? JSONSerialization.jsonObject(with: data) as? [String: Double],
       let x = value["x"],
       let y = value["y"] {
      return NSRect(x: x, y: y, width: defaultSize.width, height: defaultSize.height)
    }
    let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
    return NSRect(
      x: visibleFrame.midX - defaultSize.width / 2,
      y: visibleFrame.minY + 120,
      width: defaultSize.width,
      height: defaultSize.height)
  }
}

private final class NativeSplashView: NSView {
  private let iconContainer = NSView()
  private let iconView = NSImageView()
  private let titleLabel = NSTextField(labelWithString: NativeSplashView.appName)
  private let progressIndicator = NSProgressIndicator()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    setupContent()
    applyAppearance()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    wantsLayer = true
    setupContent()
    applyAppearance()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    applyAppearance()
  }

  private static var appName: String {
    if let preferredLanguage = UserDefaults.standard.string(
      forKey: "flutter.smplayer:settings:preferredLanguage"
    ), preferredLanguage != "system" {
      return appName(for: preferredLanguage)
    }
    if let preferredLanguage = UserDefaults.standard.string(
      forKey: "smplayer:settings:preferredLanguage"
    ), preferredLanguage != "system" {
      return appName(for: preferredLanguage)
    }
    for language in Locale.preferredLanguages {
      if let localizedName = appNameForChineseLocale(language) {
        return localizedName
      }
    }

    let locale = Locale.current
    if locale.languageCode == "zh" {
      if locale.scriptCode == "Hant" ||
          locale.regionCode == "TW" ||
          locale.regionCode == "HK" ||
          locale.regionCode == "MO" {
        return "簡音播放器"
      }
      return "简音播放器"
    }
    return "Simple Melody Player"
  }

  private static func appName(for language: String) -> String {
    appNameForChineseLocale(language) ?? "Simple Melody Player"
  }

  private static func appNameForChineseLocale(_ language: String) -> String? {
    let normalized = language.lowercased()
    if !normalized.hasPrefix("zh") {
      return nil
    }
    if normalized.contains("hant") ||
        normalized.contains("-tw") ||
        normalized.contains("-hk") ||
        normalized.contains("-mo") {
      return "簡音播放器"
    }
    return "简音播放器"
  }

  private var isDarkAppearance: Bool {
    if let dark = NativeSplashView.savedNightModeEnabled {
      return dark
    }
    return effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
  }

  private static var savedNightModeEnabled: Bool? {
    let defaults = UserDefaults.standard
    let nightMode = defaults.string(
      forKey: "flutter.smplayer:settings:nightMode"
    ) ?? defaults.string(forKey: "smplayer:settings:nightMode")
    return switch nightMode {
    case "on":
      true
    case "never":
      false
    case "auto":
      isCurrentTimeInSavedNightRange(defaults)
    default:
      nil
    }
  }

  private static func isCurrentTimeInSavedNightRange(_ defaults: UserDefaults) -> Bool {
    let startTime = defaults.string(
      forKey: "flutter.smplayer:settings:nightModeStartTime"
    ) ?? defaults.string(forKey: "smplayer:settings:nightModeStartTime") ?? "20:00"
    let endTime = defaults.string(
      forKey: "flutter.smplayer:settings:nightModeEndTime"
    ) ?? defaults.string(forKey: "smplayer:settings:nightModeEndTime") ?? "06:00"
    let calendar = Calendar.current
    let now = Date()
    let currentMinute =
      calendar.component(.hour, from: now) * 60 +
      calendar.component(.minute, from: now)
    return isMinuteInNightRange(
      currentMinute,
      start: minuteValue(startTime),
      end: minuteValue(endTime))
  }

  private static func minuteValue(_ value: String) -> Int {
    let parts = value.split(separator: ":").map { Int($0)! }
    return parts[0] * 60 + parts[1]
  }

  private static func isMinuteInNightRange(_ current: Int, start: Int, end: Int) -> Bool {
    if start < end {
      return current >= start && current < end
    }
    return current >= start || current < end
  }

  private func setupContent() {
    let stackView = NSStackView()
    stackView.orientation = .vertical
    stackView.alignment = .centerX
    stackView.spacing = 22
    stackView.translatesAutoresizingMaskIntoConstraints = false

    iconContainer.translatesAutoresizingMaskIntoConstraints = false
    iconContainer.wantsLayer = true
    iconContainer.layer?.cornerRadius = 32
    iconContainer.layer?.masksToBounds = false

    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.image = NativeSplashView.splashIcon
    iconView.imageScaling = .scaleProportionallyUpOrDown
    iconContainer.addSubview(iconView)

    titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
    titleLabel.alignment = .center

    progressIndicator.style = .spinning
    progressIndicator.controlSize = .regular
    progressIndicator.startAnimation(nil)

    addSubview(stackView)
    stackView.addArrangedSubview(iconContainer)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(progressIndicator)

    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: centerYAnchor),

      iconContainer.widthAnchor.constraint(equalToConstant: 132),
      iconContainer.heightAnchor.constraint(equalToConstant: 132),

      iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
      iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 86),
      iconView.heightAnchor.constraint(equalToConstant: 86),

      progressIndicator.widthAnchor.constraint(equalToConstant: 24),
      progressIndicator.heightAnchor.constraint(equalToConstant: 24),
    ])
  }

  private func applyAppearance() {
    let dark = isDarkAppearance
    layer?.backgroundColor = dark
      ? NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.11, alpha: 1).cgColor
      : NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.99, alpha: 1).cgColor
    iconContainer.layer?.backgroundColor = dark
      ? NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.18, alpha: 1).cgColor
      : NSColor.white.cgColor
    iconContainer.layer?.shadowColor = dark
      ? NSColor.black.withAlphaComponent(0.52).cgColor
      : NSColor(calibratedRed: 0, green: 0.47, blue: 0.84, alpha: 0.18).cgColor
    iconContainer.layer?.shadowOpacity = 1
    iconContainer.layer?.shadowRadius = 32
    iconContainer.layer?.shadowOffset = NSSize(width: 0, height: -18)
    titleLabel.textColor = dark
      ? NSColor(calibratedRed: 0.96, green: 0.98, blue: 1, alpha: 1)
      : NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.18, alpha: 1)
    progressIndicator.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
  }

  private static var splashIcon: NSImage {
    let flutterAssetPath = Bundle.main.bundleURL
      .appendingPathComponent("Contents")
      .appendingPathComponent("Frameworks")
      .appendingPathComponent("App.framework")
      .appendingPathComponent("Resources")
      .appendingPathComponent("flutter_assets")
      .appendingPathComponent("assets")
      .appendingPathComponent("branding")
      .appendingPathComponent("app-icon.png")
    return NSImage(contentsOf: flutterAssetPath) ?? NSApp.applicationIconImage
  }
}

private final class DesktopLyricsNativeView: NSView, WKNavigationDelegate, WKScriptMessageHandler {
  private let webView: DesktopLyricsWebView
  private var state = [String: Any]()
  private var webViewReady = false
  var onCommand: ((String) -> Void)?

  override init(frame frameRect: NSRect) {
    let contentController = WKUserContentController()
    let configuration = WKWebViewConfiguration()
    configuration.userContentController = contentController
    webView = DesktopLyricsWebView(
      frame: NSRect(origin: .zero, size: frameRect.size),
      configuration: configuration)
    super.init(frame: frameRect)
    configureWebView(contentController)
  }

  required init?(coder: NSCoder) {
    let contentController = WKUserContentController()
    let configuration = WKWebViewConfiguration()
    configuration.userContentController = contentController
    webView = DesktopLyricsWebView(frame: .zero, configuration: configuration)
    super.init(coder: coder)
    configureWebView(contentController)
  }

  deinit {
    webView.configuration.userContentController.removeScriptMessageHandler(forName: "desktopLyricsCommand")
  }

  func apply(state: [String: Any]) {
    self.state = state
    guard webViewReady else {
      return
    }
    applyCurrentState()
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    webViewReady = true
    applyCurrentState()
  }

  private func applyCurrentState() {
    let script = "window.smplayerDesktopLyricsUpdate(\(jsonLiteral(state)))"
    webView.evaluateJavaScript(script, completionHandler: nil)
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard message.name == "desktopLyricsCommand" else {
      return
    }
    if let command = message.body as? String {
      onCommand?(command)
      return
    }
    if let payload = message.body as? [String: Any],
       let command = payload["command"] as? String {
      onCommand?(command)
    }
  }

  func shouldWebViewHandleMouseDown(_ event: NSEvent) -> Bool {
    let point = convert(event.locationInWindow, from: nil)
    for rect in desktopLyricsButtonRects() where rect.contains(point) {
      return true
    }
    return false
  }

  func handleWebViewBackgroundMouseDown(_ event: NSEvent) {
    if (state["locked"] as? Bool) == true {
      return
    }
    window?.performDrag(with: event)
  }

  private func configureWebView(_ contentController: WKUserContentController) {
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    contentController.add(self, name: "desktopLyricsCommand")
    webView.desktopLyricsView = self
    webView.navigationDelegate = self
    webView.frame = bounds
    webView.autoresizingMask = [.width, .height]
    webView.setValue(false, forKey: "drawsBackground")
    webView.wantsLayer = true
    webView.layer?.backgroundColor = NSColor.clear.cgColor
    addSubview(webView)
    webView.loadHTMLString(Self.html, baseURL: nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      guard let self else {
        return
      }
      self.webViewReady = true
      self.applyCurrentState()
    }
  }

  private func desktopLyricsButtonRects() -> [NSRect] {
    let locked = (state["locked"] as? Bool) == true
    var items: [CGFloat] = [26, 26, 26, 9, 42, 42, 56, 9, 26, 26]
    if !locked {
      items.append(26)
    }
    let gap: CGFloat = 3
    let totalWidth = items.reduce(CGFloat(0), +) + gap * CGFloat(items.count - 1)
    var x = bounds.midX - totalWidth / 2
    let y = bounds.maxY - 8 - 12 - 30 + 2
    var rects = [NSRect]()
    for width in items {
      if width == 9 {
        x += width + gap
        continue
      }
      rects.append(NSRect(x: x, y: y, width: width, height: 26))
      x += width + gap
    }
    return rects
  }

  private func jsonLiteral(_ value: [String: Any]) -> String {
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value),
          let json = String(data: data, encoding: .utf8) else {
      return "{}"
    }
    return json
  }

  private static let html = """
<!doctype html>
<html class="desktop-lyrics-host">
<head>
<meta charset="utf-8">
<style>
:root.desktop-lyrics-host,
html.desktop-lyrics-host,
html.desktop-lyrics-host body,
html.desktop-lyrics-host #root,
body.desktop-lyrics-host,
html:has(.desktop-lyrics-window),
html:has(.desktop-lyrics-window) body,
html:has(.desktop-lyrics-window) #root {
  width: 100%;
  height: 100%;
  margin: 0;
  background: transparent !important;
  background-color: transparent !important;
  overflow: hidden;
}

.desktop-lyrics-window {
  width: 100%;
  height: 100%;
  display: grid;
  place-items: stretch;
  color: #17202c;
  font-family: var(--desktop-lyrics-font-family);
  user-select: none;
}

.desktop-lyrics-card {
  position: relative;
  display: grid;
  grid-template-rows: auto minmax(0, 1fr) auto;
  align-items: center;
  row-gap: 6px;
  min-width: 0;
  min-height: 0;
  margin: 8px;
  padding: 10px 18px 12px;
  border: 1px solid transparent;
  border-radius: 8px;
  background: transparent;
  overflow: hidden;
  cursor: move;
  transition: background-color 160ms ease, border-color 160ms ease, backdrop-filter 160ms ease;
}

.desktop-lyrics-card:hover,
.desktop-lyrics-card:focus-within {
  border-color: rgba(255, 255, 255, 0.22);
  background: rgba(8, 12, 18, calc(var(--desktop-lyrics-opacity) * 0.34));
  backdrop-filter: blur(36px) saturate(1.5);
  -webkit-backdrop-filter: blur(36px) saturate(1.5);
}

.desktop-lyrics-drag-region {
  position: absolute;
  inset: 0;
  border-radius: inherit;
}

.desktop-lyrics-toolbar {
  position: relative;
  z-index: 1;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 3px;
  min-width: 0;
  height: 30px;
  opacity: 0;
  transform: translateY(-3px);
  transition: opacity 160ms ease, transform 160ms ease;
  cursor: default;
}

.desktop-lyrics-card:hover .desktop-lyrics-toolbar,
.desktop-lyrics-toolbar:focus-within {
  opacity: 1;
  transform: translateY(0);
}

.desktop-lyrics-toolbar button {
  display: grid;
  place-items: center;
  min-width: 26px;
  height: 26px;
  padding: 0 6px;
  border: 0;
  border-radius: 5px;
  background: transparent;
  background: rgba(6, 10, 16, 0.16);
  color: rgba(255, 255, 255, 0.94);
  font: inherit;
  font-size: 11px;
  font-weight: 750;
  cursor: pointer;
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.42));
}

.desktop-lyrics-toolbar button:hover {
  background: rgba(6, 10, 16, 0.28);
  color: #fff;
}

.desktop-lyrics-toolbar svg {
  width: 16px;
  height: 16px;
}

.desktop-lyrics-toolbar-divider {
  width: 1px;
  height: 16px;
  margin: 0 4px;
  background: rgba(255, 255, 255, 0.28);
}

.desktop-lyrics-text {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 0;
  align-self: center;
  min-height: calc(var(--desktop-lyrics-font-size) * 1.2);
  color: var(--desktop-lyrics-color);
  font-size: var(--desktop-lyrics-font-size);
  font-weight: 800;
  line-height: 1.16;
  letter-spacing: 0;
  text-align: center;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  -webkit-text-stroke: 0.7px var(--desktop-lyrics-stroke-color);
  paint-order: stroke fill;
  text-shadow: 0 1px 2px color-mix(in srgb, var(--desktop-lyrics-stroke-color) 50%, transparent);
}

.desktop-lyrics-text span {
  display: inline-block;
  white-space: nowrap;
}

.desktop-lyrics-text[data-overflow='true'] {
  justify-content: flex-start;
}

.desktop-lyrics-text[data-overflow='true'] span {
  animation: desktop-lyrics-scroll var(--desktop-lyrics-scroll-duration) ease-in-out infinite alternate;
}

@keyframes desktop-lyrics-scroll {
  0%,
  16% {
    transform: translateX(0);
  }

  84%,
  100% {
    transform: translateX(calc(var(--desktop-lyrics-scroll-distance) * -1));
  }
}

.desktop-lyrics-meta {
  position: relative;
  z-index: 1;
  display: flex;
  justify-content: center;
  align-self: center;
  gap: 10px;
  min-width: 0;
  color: rgba(255, 255, 255, 0.7);
  font-size: 12px;
  font-weight: 650;
  line-height: 1.3;
  white-space: nowrap;
  overflow: hidden;
  opacity: 0;
  transition: opacity 160ms ease;
}

.desktop-lyrics-card:hover .desktop-lyrics-meta,
.desktop-lyrics-card:focus-within .desktop-lyrics-meta {
  opacity: 1;
}

.desktop-lyrics-meta span {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
}

.desktop-lyrics-window.is-day .desktop-lyrics-card:hover,
.desktop-lyrics-window.is-day .desktop-lyrics-card:focus-within {
  border-color: rgba(15, 23, 42, 0.08);
  background: rgba(245, 250, 255, calc(var(--desktop-lyrics-opacity) * 0.24));
}

.desktop-lyrics-window.is-day .desktop-lyrics-toolbar button {
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.38);
  color: rgba(17, 24, 39, 0.76);
  box-shadow: 0 1px 5px rgba(20, 30, 45, 0.08);
  filter: drop-shadow(0 1px 1px rgba(255, 255, 255, 0.38));
}

.desktop-lyrics-window.is-day .desktop-lyrics-toolbar button:hover {
  background: rgba(255, 255, 255, 0.58);
  color: #111827;
}

.desktop-lyrics-window.is-day .desktop-lyrics-toolbar-divider {
  background: rgba(15, 23, 42, 0.16);
}

.desktop-lyrics-window.is-day .desktop-lyrics-meta {
  color: rgba(17, 24, 39, 0.68);
}

.desktop-lyrics-window.is-locked .desktop-lyrics-card {
  cursor: default;
}
</style>
</head>
<body class="desktop-lyrics-host">
<main class="desktop-lyrics-window is-night" id="window">
  <section class="desktop-lyrics-card" id="card">
    <div class="desktop-lyrics-drag-region" aria-hidden="true"></div>
    <div class="desktop-lyrics-meta">
      <span id="songTitle"></span>
      <span id="artist"></span>
    </div>
    <div class="desktop-lyrics-text" id="lyricBox">
      <span id="lyricText"></span>
    </div>
    <div class="desktop-lyrics-toolbar" id="toolbar">
      <button type="button" data-command="previous" id="previousButton"></button>
      <button type="button" data-command="play-pause" id="playPauseButton"></button>
      <button type="button" data-command="next" id="nextButton"></button>
      <span class="desktop-lyrics-toolbar-divider" aria-hidden="true"></span>
      <button type="button" data-command="offset:-100">-0.1s</button>
      <button type="button" data-command="offset:100">+0.1s</button>
      <button type="button" data-command="reset-offset" id="offsetButton">0.0s</button>
      <span class="desktop-lyrics-toolbar-divider" aria-hidden="true"></span>
      <button type="button" data-command="toggle-lock" id="lockButton"></button>
      <button type="button" data-command="open-settings" id="settingsButton"></button>
      <button type="button" data-command="disable" id="closeButton"></button>
    </div>
  </section>
</main>
<script>
const icons = {
  previous: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 5h2v14H6V5Zm3 7 9-7v14l-9-7Z"/></svg>',
  next: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M16 5h2v14h-2V5ZM6 19V5l9 7-9 7Z"/></svg>',
  play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7L8 5Z"/></svg>',
  pause: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 5h4v14H7V5Zm6 0h4v14h-4V5Z"/></svg>',
  lock: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 10V8a5 5 0 0 1 10 0v2h1a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1h1Zm2 0h6V8a3 3 0 0 0-6 0v2Z"/></svg>',
  unlock: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17 8h-2a3 3 0 0 0-6 0v2h9a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1h1V8a5 5 0 0 1 10 0Z"/></svg>',
  settings: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="m19.4 13.5.1-1.5-.1-1.5 2-1.5-2-3.5-2.4 1a7.7 7.7 0 0 0-2.6-1.5L14 2h-4l-.4 2.5A7.7 7.7 0 0 0 7 6L4.6 5 2.6 8.5l2 1.5-.1 1.5.1 1.5-2 1.5 2 3.5 2.4-1a7.7 7.7 0 0 0 2.6 1.5L10 22h4l.4-2.5A7.7 7.7 0 0 0 17 18l2.4 1 2-3.5-2-1.5ZM12 15.5A3.5 3.5 0 1 1 12 8a3.5 3.5 0 0 1 0 7.5Z"/></svg>',
  close: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="m6.7 5.3 12 12-1.4 1.4-12-12 1.4-1.4Zm10.6 0 1.4 1.4-12 12-1.4-1.4 12-12Z"/></svg>',
};

const windowNode = document.getElementById('window');
const lyricBox = document.getElementById('lyricBox');
const lyricText = document.getElementById('lyricText');
const songTitle = document.getElementById('songTitle');
const artist = document.getElementById('artist');
const playPauseButton = document.getElementById('playPauseButton');
const previousButton = document.getElementById('previousButton');
const nextButton = document.getElementById('nextButton');
const lockButton = document.getElementById('lockButton');
const settingsButton = document.getElementById('settingsButton');
const closeButton = document.getElementById('closeButton');
const offsetButton = document.getElementById('offsetButton');

function request(command) {
  window.webkit.messageHandlers.desktopLyricsCommand.postMessage(command);
}

function fontCss(fontFamily) {
  if (!fontFamily || fontFamily === 'system') {
    return '"Segoe UI", system-ui, sans-serif';
  }
  return `"${String(fontFamily).replaceAll('\\\\', '\\\\\\\\').replaceAll('"', '\\\\"')}", "Segoe UI", system-ui, sans-serif`;
}

function updateScrollDistance() {
  const distance = Math.max(0, Math.ceil(lyricText.scrollWidth - lyricBox.clientWidth));
  windowNode.style.setProperty('--desktop-lyrics-scroll-distance', `${distance}px`);
  windowNode.style.setProperty('--desktop-lyrics-scroll-duration', `${Math.min(12, Math.max(5, Math.round(distance / 28) + 4))}s`);
  if (distance > 0) {
    lyricBox.dataset.overflow = 'true';
  } else {
    delete lyricBox.dataset.overflow;
  }
}

function updateIcon(button, name) {
  button.innerHTML = icons[name];
}

window.smplayerDesktopLyricsUpdate = function(state) {
  const offsetSeconds = Math.round((state.offsetMs || 0) / 100) / 10;
  const text = state.loading ? '...' : (state.lyricText || state.fallbackText || '');
  windowNode.className = `desktop-lyrics-window${state.nightMode ? ' is-night' : ' is-day'}${state.locked ? ' is-locked' : ''}`;
  windowNode.style.setProperty('--desktop-lyrics-opacity', (state.opacity || 88) / 100);
  windowNode.style.setProperty('--desktop-lyrics-font-size', `${state.fontSize || 28}px`);
  windowNode.style.setProperty('--desktop-lyrics-font-family', fontCss(state.fontFamily));
  windowNode.style.setProperty('--desktop-lyrics-color', state.textColor || '#4aa8ff');
  windowNode.style.setProperty('--desktop-lyrics-stroke-color', state.strokeColor || 'transparent');
  songTitle.textContent = state.songTitle || '';
  artist.textContent = state.artist || '';
  artist.hidden = !state.artist;
  lyricBox.title = text;
  lyricText.textContent = text;
  previousButton.title = state.labelPrevious || '';
  nextButton.title = state.labelNext || '';
  playPauseButton.title = state.labelPlayPause || '';
  lockButton.title = state.locked ? (state.labelUnlock || '') : (state.labelLock || '');
  settingsButton.title = state.labelSettings || '';
  closeButton.title = state.labelClose || '';
  closeButton.hidden = !!state.locked;
  offsetButton.textContent = offsetSeconds > 0 ? `+${offsetSeconds}s` : `${offsetSeconds}s`;
  updateIcon(previousButton, 'previous');
  updateIcon(nextButton, 'next');
  updateIcon(playPauseButton, state.playing ? 'pause' : 'play');
  updateIcon(lockButton, state.locked ? 'lock' : 'unlock');
  updateIcon(settingsButton, 'settings');
  updateIcon(closeButton, 'close');
  requestAnimationFrame(updateScrollDistance);
};

document.querySelectorAll('[data-command]').forEach((button) => {
  button.addEventListener('click', () => request(button.dataset.command));
});

new ResizeObserver(updateScrollDistance).observe(lyricBox);
window.smplayerDesktopLyricsUpdate({});
</script>
</body>
</html>
"""
}

private final class DesktopLyricsWebView: WKWebView {
  weak var desktopLyricsView: DesktopLyricsNativeView?

  override func mouseDown(with event: NSEvent) {
    if desktopLyricsView?.shouldWebViewHandleMouseDown(event) == true {
      super.mouseDown(with: event)
      return
    }
    desktopLyricsView?.handleWebViewBackgroundMouseDown(event)
  }
}

private extension NSColor {
  convenience init(hex: String) {
    let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var number: UInt64 = 0
    Scanner(string: value).scanHexInt64(&number)
    self.init(
      calibratedRed: CGFloat((number >> 16) & 0xff) / 255.0,
      green: CGFloat((number >> 8) & 0xff) / 255.0,
      blue: CGFloat(number & 0xff) / 255.0,
      alpha: 1)
  }
}
