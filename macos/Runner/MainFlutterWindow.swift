import Cocoa
import Carbon.HIToolbox
import FlutterMacOS
import MediaPlayer
import UserNotifications

class MainFlutterWindow: NSWindow, NSWindowDelegate, UNUserNotificationCenterDelegate {
  private static let mainWindowFrameAutosaveName = "SMPlayerMainWindowFrame"
  private static let mainWindowMinimumSize = NSSize(width: 506, height: 698)
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
      hideDesktopLyricsPanel()
      return
    }

    let panel = ensureDesktopLyricsPanel(bounds: state["bounds"] as? String)
    configureDesktopLyricsPanel(panel)
    desktopLyricsView?.apply(state: state)
    panel.isMovableByWindowBackground = false
    panel.orderFront(nil)
    desktopLyricsView?.refreshMouseInteraction()
  }

  private func ensureDesktopLyricsPanel(bounds rawBounds: String?) -> NSPanel {
    let frame = resolveDesktopLyricsFrame(rawBounds)
    if let panel = desktopLyricsPanel {
      if !desktopLyricsFrameIsVisibleOnTargetScreen(panel.frame) {
        panel.setFrame(frame, display: true)
        sendDesktopLyricsBounds()
      }
      return panel
    }

    let panel = NSPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false)
    configureDesktopLyricsPanel(panel)
    let lyricsView = DesktopLyricsNativeView(frame: NSRect(origin: .zero, size: frame.size))
    lyricsView.onCommand = { [weak self] command in
      self?.sendDesktopCommand(command)
    }
    lyricsView.autoresizingMask = [.width, .height]
    panel.contentView = lyricsView
    desktopLyricsPanel = panel
    desktopLyricsView = lyricsView
    sendDesktopLyricsBounds()
    return panel
  }

  private func configureDesktopLyricsPanel(_ panel: NSPanel) {
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .floating
    panel.collectionBehavior = [.managed, .fullScreenNone]
    panel.hidesOnDeactivate = false
    panel.isMovableByWindowBackground = false
    panel.acceptsMouseMovedEvents = true
    panel.delegate = self
  }

  private func hideDesktopLyricsPanel() {
    guard let panel = desktopLyricsPanel else {
      return
    }
    desktopLyricsView?.resetMouseInteraction()
    panel.ignoresMouseEvents = true
    panel.orderOut(nil)
  }

  func windowDidMove(_ notification: Notification) {
    if notification.object as? NSWindow === desktopLyricsPanel {
      sendDesktopLyricsBounds()
      return
    }
    if notification.object as? NSWindow === self {
      repositionDesktopLyricsPanelIfNeeded()
    }
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

  private func repositionDesktopLyricsPanelIfNeeded() {
    guard let panel = desktopLyricsPanel,
          !desktopLyricsFrameIsVisibleOnTargetScreen(panel.frame) else {
      return
    }
    panel.setFrame(resolveDesktopLyricsFrame(nil), display: true)
    sendDesktopLyricsBounds()
    desktopLyricsView?.refreshMouseInteraction()
  }

  private func resolveDesktopLyricsFrame(_ rawBounds: String?) -> NSRect {
    let targetVisibleFrame =
      desktopLyricsTargetScreen()?.visibleFrame ??
      NSScreen.main?.visibleFrame ??
      NSScreen.screens[0].visibleFrame
    return DesktopLyricsWindowGeometry.resolveFrame(
      rawBounds: rawBounds,
      targetVisibleFrame: targetVisibleFrame,
      screenVisibleFrames: desktopLyricsVisibleFrames())
  }

  private func desktopLyricsTargetScreen() -> NSScreen? {
    return screen ?? NSScreen.main ?? NSScreen.screens.first
  }

  private func desktopLyricsFrameIsVisibleOnTargetScreen(_ frame: NSRect) -> Bool {
    let targetVisibleFrame =
      desktopLyricsTargetScreen()?.visibleFrame ??
      NSScreen.screens[0].visibleFrame
    return DesktopLyricsWindowGeometry.frameIsVisible(
      frame,
      screenVisibleFrames: [targetVisibleFrame])
  }

  private func desktopLyricsVisibleFrames() -> [NSRect] {
    return NSScreen.screens.map { $0.visibleFrame }
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

private final class DesktopLyricsNativeView: NSView {
  private let glassView = NSVisualEffectView()
  private var state = [String: Any]()
  private var isPanelVisible = false
  private var hoveredButtonCommand: String?
  private var trackingArea: NSTrackingArea?
  private var lyricsTextStartedAt = Date()
  private var previousLyricsText = ""
  private var scrollTimer: Timer?
  private var globalMouseMonitor: Any?
  private var localMouseMonitor: Any?
  var onCommand: ((String) -> Void)?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configureView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configureView()
  }

  deinit {
    scrollTimer?.invalidate()
    if let globalMouseMonitor {
      NSEvent.removeMonitor(globalMouseMonitor)
    }
    if let localMouseMonitor {
      NSEvent.removeMonitor(localMouseMonitor)
    }
  }

  override var isOpaque: Bool {
    return false
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    return bounds.contains(point) ? self : nil
  }

  override func updateTrackingAreas() {
    if let trackingArea {
      removeTrackingArea(trackingArea)
    }
    let options: NSTrackingArea.Options = [
      .activeAlways,
      .inVisibleRect,
      .mouseEnteredAndExited,
      .mouseMoved,
    ]
    let nextArea = NSTrackingArea(rect: bounds, options: options, owner: self)
    trackingArea = nextArea
    addTrackingArea(nextArea)
    super.updateTrackingAreas()
  }

  func apply(state: [String: Any]) {
    let nextLyricsText = DesktopLyricsNativeView.lyricsText(from: state)
    if previousLyricsText != nextLyricsText {
      previousLyricsText = nextLyricsText
      lyricsTextStartedAt = Date()
    }
    self.state = state
    startScrollTimer()
    needsDisplay = true
  }

  func refreshMouseInteraction() {
    guard let window, window.isVisible else {
      return
    }
    let point = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
    updatePanelVisibility(at: point)
    updateButtonHover(at: point)
  }

  func resetMouseInteraction() {
    setPanelVisible(false)
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard !bounds.isEmpty else {
      return
    }
    if isPanelVisible {
      drawCard()
      drawMeta()
    }
    drawLyricsText()
    if isPanelVisible {
      drawToolbar()
    }
  }

  override func mouseEntered(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    updatePanelVisibility(at: point)
    updateButtonHover(at: point)
  }

  override func mouseExited(with event: NSEvent) {
    setPanelVisible(false)
  }

  override func mouseMoved(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    updatePanelVisibility(at: point)
    updateButtonHover(at: point)
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    if isPanelVisible {
      for button in desktopLyricsButtons() where button.rect.contains(point) {
        onCommand?(button.command)
        return
      }
    }
    if (state["locked"] as? Bool) != true && draggableRect().contains(point) {
      window?.performDrag(with: event)
      refreshMouseInteraction()
    }
  }

  private func configureView() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    glassView.blendingMode = .behindWindow
    glassView.state = .active
    glassView.material = .hudWindow
    glassView.isHidden = true
    glassView.wantsLayer = true
    glassView.layer?.cornerRadius = 8
    glassView.layer?.masksToBounds = true
    glassView.layer?.zPosition = -1
    addSubview(glassView, positioned: .below, relativeTo: nil)
    installMouseMonitors()
  }

  private func installMouseMonitors() {
    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) {
      [weak self] _ in
      DispatchQueue.main.async {
        self?.refreshMouseInteraction()
      }
    }
    localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) {
      [weak self] event in
      self?.refreshMouseInteraction()
      return event
    }
  }

  private func updatePanelVisibility(at point: NSPoint) {
    let nextPanelVisible =
      isPanelVisible
      ? cardRect().contains(point)
      : lyricHitRect().contains(point)
    setPanelVisible(nextPanelVisible)
  }

  private func setPanelVisible(_ visible: Bool) {
    window?.ignoresMouseEvents = !visible
    if isPanelVisible == visible {
      return
    }
    isPanelVisible = visible
    if !visible {
      hoveredButtonCommand = nil
    }
    updateGlassSurface()
    needsDisplay = true
  }

  private func updateButtonHover(at point: NSPoint) {
    let nextCommand =
      isPanelVisible
      ? desktopLyricsButtons().first(where: {
        !$0.command.isEmpty && $0.rect.contains(point)
      })?.command
      : nil
    if hoveredButtonCommand == nextCommand {
      return
    }
    hoveredButtonCommand = nextCommand
    needsDisplay = true
  }

  private func startScrollTimer() {
    if scrollTimer != nil {
      return
    }
    scrollTimer = Timer.scheduledTimer(
      withTimeInterval: 1.0 / 30.0,
      repeats: true
    ) { [weak self] _ in
      self?.needsDisplay = true
    }
  }

  private func cardRect() -> NSRect {
    bounds.insetBy(dx: 8, dy: 8)
  }

  private func lyricsTextRect() -> NSRect {
    let cardRect = cardRect()
    let contentTop = cardRect.maxY - 1 - 10
    let contentBottom = cardRect.minY + 1 + 12
    let metaHeight: CGFloat = 16
    let toolbarHeight: CGFloat = 30
    let rowGap: CGFloat = 6
    let toolbarTop = contentBottom
    let lyricBottom = toolbarTop + toolbarHeight + rowGap
    let lyricTop = contentTop - metaHeight - rowGap
    let fontSize = CGFloat(numberValue("fontSize", defaultValue: 28))
    return NSRect(
      x: cardRect.minX + 1 + 18,
      y: lyricBottom,
      width: max(0, cardRect.width - 2 - 36),
      height: max(fontSize * 1.42, lyricTop - lyricBottom))
  }

  private func lyricHitRect() -> NSRect {
    let rect = lyricsTextRect()
    let fontSize = CGFloat(numberValue("fontSize", defaultValue: 28))
    let text = lyricsText()
    if text.isEmpty {
      return .zero
    }
    let attributes: [NSAttributedString.Key: Any] = [
      .font: lyricsFont(size: fontSize),
    ]
    let measuredWidth = ceil(
      NSAttributedString(string: text, attributes: attributes).size().width)
    let hitWidth: CGFloat
    if measuredWidth > rect.width {
      hitWidth = rect.width
    } else {
      hitWidth = min(rect.width, measuredWidth + fontSize * 0.28)
    }
    let hitHeight = min(rect.height, fontSize * 1.24)
    return NSRect(
      x: rect.midX - hitWidth / 2,
      y: rect.midY - hitHeight / 2,
      width: hitWidth,
      height: hitHeight)
  }

  private func draggableRect() -> NSRect {
    isPanelVisible ? cardRect() : lyricHitRect()
  }

  private func drawCard() {
    updateGlassSurface()
    let cardRect = cardRect()
    let path = NSBezierPath(roundedRect: cardRect, xRadius: 8, yRadius: 8)
    let opacity = CGFloat(numberValue("opacity", defaultValue: 88)) / 100.0
    if (state["nightMode"] as? Bool) == false {
      NSColor(
        calibratedRed: 0.90,
        green: 0.88,
        blue: 0.82,
        alpha: opacity * 0.070
      ).setFill()
      NSColor(
        calibratedRed: 0.06,
        green: 0.09,
        blue: 0.16,
        alpha: 0.13
      ).setStroke()
    } else {
      NSColor.white.withAlphaComponent(opacity * 0.045).setFill()
      NSColor.white.withAlphaComponent(0.24).setStroke()
    }
    path.fill()
    path.lineWidth = 1
    path.stroke()

    let innerRect = cardRect.insetBy(dx: 1, dy: 1)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 7, yRadius: 7)
    if (state["nightMode"] as? Bool) == false {
      NSColor.white.withAlphaComponent(0.22).setStroke()
    } else {
      NSColor.white.withAlphaComponent(0.16).setStroke()
    }
    innerPath.lineWidth = 1
    innerPath.stroke()
  }

  private func updateGlassSurface() {
    glassView.isHidden = !isPanelVisible
    glassView.frame = cardRect()
    if (state["nightMode"] as? Bool) == false {
      glassView.material = .hudWindow
      glassView.alphaValue = 0.62
    } else {
      glassView.material = .hudWindow
      glassView.alphaValue = 0.78
    }
  }

  private func drawMeta() {
    let cardRect = cardRect()
    let title = (state["songTitle"] as? String) ?? ""
    let artist = (state["artist"] as? String) ?? ""
    var metaText = title
    if !artist.isEmpty {
      metaText += "     "
      metaText += artist
    }
    if metaText.isEmpty {
      return
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byTruncatingTail
    let color: NSColor
    if (state["nightMode"] as? Bool) == false {
      color = NSColor(
        calibratedRed: 0.07,
        green: 0.09,
        blue: 0.15,
        alpha: 0.68)
    } else {
      color = NSColor.white.withAlphaComponent(0.70)
    }
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
      .paragraphStyle: paragraph,
      .foregroundColor: color,
    ]
    let rect = NSRect(
      x: cardRect.minX + 18,
      y: cardRect.maxY - 28,
      width: max(0, cardRect.width - 36),
      height: 18)
    drawString(metaText, in: rect, attributes: attributes)
  }

  private func drawLyricsText() {
    let text = lyricsText()
    if text.isEmpty {
      return
    }
    let fontSize = CGFloat(numberValue("fontSize", defaultValue: 28))
    let font = lyricsFont(size: fontSize)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byTruncatingTail
    let textColor = desktopLyricsColor("textColor", defaultHex: "#4aa8ff", opacity: 1)
    let strokeColor = desktopLyricsColor("strokeColor", defaultHex: "#111111", opacity: 1)
    let rect = lyricsTextRect()
    let baseAttributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .paragraphStyle: paragraph,
      .foregroundColor: textColor,
    ]
    let measuredWidth = ceil(
      NSAttributedString(string: text, attributes: baseAttributes).size().width)
    if measuredWidth > rect.width {
      drawScrollingLyrics(
        text,
        in: rect,
        measuredWidth: measuredWidth,
        font: font,
        textColor: textColor,
        strokeColor: strokeColor)
      return
    }
    if strokeColor.alphaComponent > 0 {
      drawString(
        text,
        in: rect,
        attributes: [
          .font: font,
          .paragraphStyle: paragraph,
          .foregroundColor: strokeColor,
          .strokeColor: strokeColor,
          .strokeWidth: 2,
        ])
    }
    drawString(
      text,
      in: rect,
      attributes: [
        .font: font,
        .paragraphStyle: paragraph,
        .foregroundColor: textColor,
      ])
  }

  private func drawScrollingLyrics(
    _ text: String,
    in rect: NSRect,
    measuredWidth: CGFloat,
    font: NSFont,
    textColor: NSColor,
    strokeColor: NSColor
  ) {
    let distance = max(0, measuredWidth - rect.width)
    let duration = min(12.0, max(5.0, Double(Int((distance / 28).rounded())) + 4.0))
    let elapsed = Date().timeIntervalSince(lyricsTextStartedAt)
    let cycle = duration * 2
    let phase = elapsed.truncatingRemainder(dividingBy: cycle)
    let rawProgress: Double
    if phase <= duration {
      rawProgress = phase / duration
    } else {
      rawProgress = 1.0 - ((phase - duration) / duration)
    }
    let easedProgress = rawProgress * rawProgress * (3.0 - 2.0 * rawProgress)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineBreakMode = .byClipping
    var textRect = rect
    textRect.origin.x -= distance * easedProgress
    textRect.size.width = measuredWidth

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: rect).addClip()
    if strokeColor.alphaComponent > 0 {
      drawString(
        text,
        in: textRect,
        attributes: [
          .font: font,
          .paragraphStyle: paragraph,
          .foregroundColor: strokeColor,
          .strokeColor: strokeColor,
          .strokeWidth: 2,
        ])
    }
    drawString(
      text,
      in: textRect,
      attributes: [
        .font: font,
        .paragraphStyle: paragraph,
        .foregroundColor: textColor,
      ])
    NSGraphicsContext.restoreGraphicsState()
  }

  private func drawToolbar() {
    let buttons = desktopLyricsButtons()
    for button in buttons {
      if button.command.isEmpty {
        continue
      }
      let iconButton = button.symbolName != nil
      let radius: CGFloat = iconButton ? 7 : 5
      let path = NSBezierPath(
        roundedRect: button.rect,
        xRadius: radius,
        yRadius: radius)
      let hovered = hoveredButtonCommand == button.command
      if (state["nightMode"] as? Bool) == false {
        let fillAlpha: CGFloat =
          iconButton ? (hovered ? 0.60 : 0.24) : (hovered ? 0.68 : 0.38)
        let strokeAlpha: CGFloat =
          hovered ? (iconButton ? 0.14 : 0.18) : 0
        NSColor.white.withAlphaComponent(fillAlpha).setFill()
        NSColor(calibratedWhite: 0, alpha: strokeAlpha).setStroke()
      } else {
        let fillAlpha: CGFloat =
          iconButton ? (hovered ? 0.58 : 0.12) : (hovered ? 0.76 : 0.22)
        NSColor(
          calibratedRed: hovered ? 0.16 : 0.02,
          green: hovered ? 0.20 : 0.04,
          blue: hovered ? 0.25 : 0.06,
          alpha: fillAlpha
        ).setFill()
        NSColor.clear.setStroke()
      }
      path.fill()
      path.lineWidth = 1
      path.stroke()
      drawButtonContent(button)
    }
  }

  private func drawButtonContent(_ button: DesktopLyricsButton) {
    let iconButton = button.symbolName != nil
    let color =
      (state["nightMode"] as? Bool) == false
      ? NSColor(calibratedWhite: 0.12, alpha: iconButton ? 0.68 : 0.76)
      : NSColor.white.withAlphaComponent(iconButton ? 0.86 : 0.94)
    if let symbolName = button.symbolName {
      let weight: NSFont.Weight =
        button.command == "previous" ||
        button.command == "next" ||
        button.command == "disable"
        ? .regular
        : .medium
      guard let image = systemSymbol(
        named: symbolName,
        color: color,
        weight: weight
      ) else {
        return
      }
      let side: CGFloat = button.command == "disable" ? 11 : 15
      let imageRect = NSRect(
        x: button.rect.midX - side / 2,
        y: button.rect.midY - side / 2,
        width: side,
        height: side)
      image.draw(in: imageRect)
      return
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byClipping
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 11, weight: .bold),
      .paragraphStyle: paragraph,
      .foregroundColor: color,
    ]
    let attributedLabel = NSAttributedString(
      string: button.label,
      attributes: attributes)
    let labelHeight = ceil(attributedLabel.size().height)
    let labelRect = NSRect(
      x: button.rect.minX + 2,
      y: button.rect.midY - labelHeight / 2,
      width: button.rect.width - 4,
      height: labelHeight)
    attributedLabel.draw(in: labelRect)
  }

  private func desktopLyricsButtons() -> [DesktopLyricsButton] {
    let locked = (state["locked"] as? Bool) == true
    let playing = (state["playing"] as? Bool) == true
    let offsetSeconds = (numberValue("offsetMs", defaultValue: 0) / 100.0).rounded() / 10.0
    let offsetLabel =
      offsetSeconds > 0
      ? String(format: "+%.1fs", offsetSeconds)
      : offsetSeconds < 0 ? String(format: "%.1fs", offsetSeconds) : "0s"
    var specs = [
      DesktopLyricsButton(command: "previous", label: "", symbolName: "backward.end", width: 26, rect: .zero),
      DesktopLyricsButton(
        command: "play-pause",
        label: "",
        symbolName: playing ? "pause" : "play",
        width: 26,
        rect: .zero),
      DesktopLyricsButton(command: "next", label: "", symbolName: "forward.end", width: 26, rect: .zero),
      DesktopLyricsButton(command: "", label: "", symbolName: nil, width: 9, rect: .zero),
      DesktopLyricsButton(command: "offset:-100", label: "-0.1s", symbolName: nil, width: 42, rect: .zero),
      DesktopLyricsButton(command: "offset:100", label: "+0.1s", symbolName: nil, width: 42, rect: .zero),
      DesktopLyricsButton(command: "reset-offset", label: offsetLabel, symbolName: nil, width: 56, rect: .zero),
      DesktopLyricsButton(command: "", label: "", symbolName: nil, width: 9, rect: .zero),
      DesktopLyricsButton(
        command: "toggle-lock",
        label: "",
        symbolName: locked ? "lock" : "lock.open",
        width: 26,
        rect: .zero),
      DesktopLyricsButton(command: "open-settings", label: "", symbolName: "gearshape", width: 26, rect: .zero),
    ]
    if !locked {
      specs.append(DesktopLyricsButton(command: "disable", label: "", symbolName: "xmark", width: 26, rect: .zero))
    }
    let gap: CGFloat = 3
    let totalWidth = specs.reduce(CGFloat(0)) { $0 + $1.width } + gap * CGFloat(specs.count - 1)
    var x = bounds.midX - totalWidth / 2
    let cardRect = cardRect()
    let toolbarHeight: CGFloat = 30
    let buttonHeight: CGFloat = 26
    let y = cardRect.minY + 1 + 12 + (toolbarHeight - buttonHeight) / 2
    for index in specs.indices {
      specs[index].rect = NSRect(x: x, y: y, width: specs[index].width, height: buttonHeight)
      x += specs[index].width + gap
    }
    return specs
  }

  private func lyricsText() -> String {
    if (state["loading"] as? Bool) == true {
      return "..."
    }
    if let lyricText = state["lyricText"] as? String, !lyricText.isEmpty {
      return lyricText
    }
    return (state["fallbackText"] as? String) ?? ""
  }

  private func lyricsFont(size: CGFloat) -> NSFont {
    if let family = state["fontFamily"] as? String,
       !family.isEmpty,
       family != "system",
       let font = NSFontManager.shared.font(
        withFamily: family,
        traits: [],
       weight: 8,
       size: size) {
      return font
    }
    return NSFont.systemFont(ofSize: size, weight: .heavy)
  }

  private func desktopLyricsColor(
    _ key: String,
    defaultHex: String,
    opacity: CGFloat
  ) -> NSColor {
    if key == "strokeColor",
       let rawValue = state[key] as? String,
       rawValue.isEmpty {
      return .clear
    }
    let rawValue = (state[key] as? String) ?? defaultHex
    return NSColor(hex: rawValue).withAlphaComponent(opacity)
  }

  private func drawString(
    _ text: String,
    in rect: NSRect,
    attributes: [NSAttributedString.Key: Any]
  ) {
    NSAttributedString(string: text, attributes: attributes).draw(in: rect)
  }

  private static func lyricsText(from state: [String: Any]) -> String {
    if (state["loading"] as? Bool) == true {
      return "..."
    }
    if let lyricText = state["lyricText"] as? String, !lyricText.isEmpty {
      return lyricText
    }
    return (state["fallbackText"] as? String) ?? ""
  }

  private func numberValue(_ key: String, defaultValue: Double) -> Double {
    if let number = state[key] as? NSNumber {
      return number.doubleValue
    }
    return defaultValue
  }

  private func systemSymbol(
    named name: String,
    color: NSColor,
    weight: NSFont.Weight
  ) -> NSImage? {
    if #available(macOS 11.0, *) {
      let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: weight)
      return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)?
        .tint(color: color)
    }
    return nil
  }
}

private struct DesktopLyricsButton {
  let command: String
  let label: String
  let symbolName: String?
  let width: CGFloat
  var rect: NSRect
}

private extension NSImage {
  func tint(color: NSColor) -> NSImage {
    let image = copy() as! NSImage
    image.lockFocus()
    color.set()
    NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
    image.unlockFocus()
    return image
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
