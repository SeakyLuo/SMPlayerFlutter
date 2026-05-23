import Cocoa
import FlutterMacOS
import MediaPlayer
import UserNotifications

class MainFlutterWindow: NSWindow, NSWindowDelegate, UNUserNotificationCenterDelegate {
  private var desktopFeatureChannel: FlutterMethodChannel?
  private var globalMediaEventMonitor: Any?
  private var localMediaEventMonitor: Any?
  private var externalOpenObserver: NSObjectProtocol?
  private var desktopLyricsPanel: NSPanel?
  private var desktopLyricsView: DesktopLyricsNativeView?
  private var mediaSessionCommandsInstalled = false
  private var externalOpenChannelReady = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    desktopFeatureChannel = FlutterMethodChannel(
      name: "smplayer_flutter/desktop_features",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    desktopFeatureChannel?.setMethodCallHandler(handleDesktopFeatureMethodCall)
    UNUserNotificationCenter.current().delegate = self
    installMediaKeyMonitor()
    installExternalOpenObserver()

    super.awakeFromNib()
  }

  deinit {
    if let globalMediaEventMonitor = globalMediaEventMonitor {
      NSEvent.removeMonitor(globalMediaEventMonitor)
    }
    if let localMediaEventMonitor = localMediaEventMonitor {
      NSEvent.removeMonitor(localMediaEventMonitor)
    }
    if let externalOpenObserver = externalOpenObserver {
      NotificationCenter.default.removeObserver(externalOpenObserver)
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
    globalMediaEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) {
      [weak self] event in
      self?.handleSystemDefinedEvent(event)
    }
    localMediaEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) {
      [weak self] event in
      self?.handleSystemDefinedEvent(event)
      return event
    }
  }

  private func handleSystemDefinedEvent(_ event: NSEvent) {
    if event.subtype.rawValue != 8 {
      return
    }
    let keyCode = (event.data1 & 0xffff0000) >> 16
    let keyState = (event.data1 & 0x0000ff00) >> 8
    if keyState != 0x0a {
      return
    }

    switch keyCode {
    case 16:
      sendDesktopCommand("play-pause")
    case 17:
      sendDesktopCommand("next")
    case 18:
      sendDesktopCommand("previous")
    case 20:
      sendDesktopCommand("stop")
    default:
      break
    }
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
    if call.method == "updateDesktopLyricsWindow" {
      guard let state = call.arguments as? [String: Any] else {
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
      guard let state = call.arguments as? [String: Any] else {
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
      return
    }

    var info: [String: Any] = [
      MPMediaItemPropertyTitle: (state["title"] as? String) ?? "",
      MPMediaItemPropertyArtist: (state["artist"] as? String) ?? "",
      MPMediaItemPropertyAlbumTitle: (state["album"] as? String) ?? "",
      MPNowPlayingInfoPropertyPlaybackRate: ((state["playing"] as? Bool) ?? false) ? 1.0 : 0.0,
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
  }

  private func installMediaSessionCommandCenter() {
    if mediaSessionCommandsInstalled {
      return
    }
    mediaSessionCommandsInstalled = true
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.playCommand.addTarget { [weak self] _ in
      self?.sendDesktopCommand("play-pause")
      return .success
    }
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      self?.sendDesktopCommand("play-pause")
      return .success
    }
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      self?.sendDesktopCommand("next")
      return .success
    }
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      self?.sendDesktopCommand("previous")
      return .success
    }
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
    panel.ignoresMouseEvents = (state["locked"] as? Bool) == true
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

private final class DesktopLyricsNativeView: NSView {
  private var lyricText = ""
  private var nextLyricText = ""
  private var fontFamily = "system"
  private var fontSize = 28
  private var textColor = NSColor(calibratedRed: 0.29, green: 0.66, blue: 1.0, alpha: 1)
  private var opacity = 0.88
  private var loading = false
  private var locked = false
  private var nightMode = true
  private var labelPlayPause = "Play/Pause"
  private var offsetLabel = "0.0s"
  private var labelLock = "Lock"
  private var labelUnlock = "Unlock"
  private var labelSettings = "Settings"
  private var labelClose = "Close"
  private var buttonRects: [(rect: NSRect, command: String, label: String)] = []
  private var lyricScrollStart = Date()
  private var lyricScrollTimer: Timer?
  var onCommand: ((String) -> Void)?

  override var isFlipped: Bool { true }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window == nil {
      lyricScrollTimer?.invalidate()
      lyricScrollTimer = nil
    } else if lyricScrollTimer == nil {
      lyricScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
        self?.needsDisplay = true
      }
    }
  }

  deinit {
    lyricScrollTimer?.invalidate()
  }

  func apply(state: [String: Any]) {
    let lyric = (state["lyricText"] as? String) ?? ""
    let fallback = (state["fallbackText"] as? String) ?? ""
    loading = (state["loading"] as? Bool) ?? false
    let nextLyricTextValue = loading ? "..." : lyric.isEmpty ? fallback : lyric
    let nextFontFamily = (state["fontFamily"] as? String) ?? "system"
    let nextFontSize = (state["fontSize"] as? Int) ?? 28
    if lyricText != nextLyricTextValue || fontFamily != nextFontFamily || fontSize != nextFontSize {
      lyricScrollStart = Date()
    }
    lyricText = nextLyricTextValue
    nextLyricText = (state["nextLyricText"] as? String) ?? ""
    fontFamily = nextFontFamily
    fontSize = nextFontSize
    locked = (state["locked"] as? Bool) ?? false
    nightMode = (state["nightMode"] as? Bool) ?? true
    let offsetMs = Double((state["offsetMs"] as? Int) ?? 0)
    offsetLabel = String(format: "%+.1fs", offsetMs / 1000.0)
    opacity = Double((state["opacity"] as? Int) ?? 88) / 100.0
    labelPlayPause = (state["labelPlayPause"] as? String) ?? "Play/Pause"
    labelLock = (state["labelLock"] as? String) ?? "Lock"
    labelUnlock = (state["labelUnlock"] as? String) ?? "Unlock"
    labelSettings = (state["labelSettings"] as? String) ?? "Settings"
    labelClose = (state["labelClose"] as? String) ?? "Close"
    textColor = NSColor(hex: (state["textColor"] as? String) ?? "#4aa8ff")
      .withAlphaComponent(opacity)
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.clear.setFill()
    bounds.fill()
    let card = bounds.insetBy(dx: 10, dy: 10)
    let cardColor = nightMode
      ? NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.13, alpha: 0.72)
      : NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 0.76)
    cardColor.setFill()
    NSBezierPath(roundedRect: card, xRadius: 8, yRadius: 8).fill()
    buttonRects.removeAll()

    if !locked {
      let buttons: [(CGFloat, CGFloat, String, String)] = [
        (card.minX + 10, 38, "previous", "<<"),
        (card.minX + 52, 60, "play-pause", labelPlayPause),
        (card.minX + 116, 38, "next", ">>"),
        (card.minX + 166, 48, "offset:-100", "-0.1"),
        (card.minX + 218, 48, "offset:100", "+0.1"),
        (card.minX + 270, 56, "reset-offset", offsetLabel),
        (card.maxX - 238, 54, "toggle-lock", locked ? labelUnlock : labelLock),
        (card.maxX - 180, 78, "open-settings", labelSettings),
        (card.maxX - 98, 58, "disable", labelClose),
      ]
      for (x, width, command, label) in buttons {
        let rect = NSRect(x: x, y: card.minY + 8, width: width, height: 26)
        buttonRects.append((rect, command, label))
        let buttonColor = nightMode
          ? NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.25, alpha: 0.88)
          : NSColor(calibratedRed: 0.87, green: 0.91, blue: 0.95, alpha: 0.92)
        buttonColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
        drawCentered(
          label,
          in: rect.insetBy(dx: 4, dy: 3),
          font: NSFont.systemFont(ofSize: 12, weight: .semibold),
          color: nightMode
            ? NSColor(calibratedWhite: 0.92, alpha: 1)
            : NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.21, alpha: 1))
      }
    }

    let fontName = fontFamily == "system" ? nil : fontFamily
    let lyricFont = fontName.flatMap { NSFont(name: $0, size: CGFloat(fontSize)) }
      ?? NSFont.systemFont(ofSize: CGFloat(fontSize), weight: .bold)
    let topInset: CGFloat = locked ? 28 : 42
    drawScrollingCentered(
      lyricText,
      in: card.insetBy(dx: 18, dy: nextLyricText.isEmpty ? topInset : max(topInset, 34)),
      font: lyricFont,
      color: textColor)

    if !nextLyricText.isEmpty {
      let nextFont = fontName.flatMap { NSFont(name: $0, size: CGFloat(max(13, fontSize - 8))) }
        ?? NSFont.systemFont(ofSize: CGFloat(max(13, fontSize - 8)), weight: .semibold)
      var nextRect = card.insetBy(dx: 18, dy: 0)
      nextRect.origin.y = card.maxY - 40
      nextRect.size.height = 28
      drawCentered(
        nextLyricText,
        in: nextRect,
        font: nextFont,
        color: textColor.withAlphaComponent(opacity * 0.74))
    }
  }

  private func drawCentered(_ text: String, in rect: NSRect, font: NSFont, color: NSColor) {
    drawAttributed(text, in: rect, font: font, color: color, scrollOverflow: false)
  }

  private func drawScrollingCentered(_ text: String, in rect: NSRect, font: NSFont, color: NSColor) {
    drawAttributed(text, in: rect, font: font, color: color, scrollOverflow: true)
  }

  private func drawAttributed(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, scrollOverflow: Bool) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = scrollOverflow ? .byClipping : .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
      .paragraphStyle: paragraph,
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let size = attributed.size()
    if scrollOverflow && size.width > rect.width {
      let distance = size.width - rect.width
      let duration = min(12.0, max(5.0, round(Double(distance / 28.0)) + 4.0))
      let cycle = duration * 2.0
      let elapsed = Date().timeIntervalSince(lyricScrollStart).truncatingRemainder(dividingBy: cycle)
      let rawProgress = elapsed <= duration ? elapsed / duration : 1.0 - (elapsed - duration) / duration
      let progress = rawProgress * rawProgress * (3.0 - 2.0 * rawProgress)
      let drawRect = NSRect(
        x: rect.minX - distance * CGFloat(progress),
        y: rect.midY - size.height / 2,
        width: size.width,
        height: size.height)
      NSGraphicsContext.saveGraphicsState()
      rect.clip()
      attributed.draw(with: drawRect, options: [.usesLineFragmentOrigin])
      NSGraphicsContext.restoreGraphicsState()
      return
    }
    let drawRect = NSRect(
      x: rect.minX,
      y: rect.midY - size.height / 2,
      width: rect.width,
      height: size.height)
    attributed.draw(in: drawRect)
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    for button in buttonRects where button.rect.contains(point) {
      onCommand?(button.command)
      return
    }
    window?.performDrag(with: event)
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
