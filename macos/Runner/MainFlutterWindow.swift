import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var desktopFeatureChannel: FlutterMethodChannel?
  private var globalMediaEventMonitor: Any?
  private var localMediaEventMonitor: Any?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    desktopFeatureChannel = FlutterMethodChannel(
      name: "smplayer_flutter/desktop_features",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    installMediaKeyMonitor()

    super.awakeFromNib()
  }

  deinit {
    if let globalMediaEventMonitor = globalMediaEventMonitor {
      NSEvent.removeMonitor(globalMediaEventMonitor)
    }
    if let localMediaEventMonitor = localMediaEventMonitor {
      NSEvent.removeMonitor(localMediaEventMonitor)
    }
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
    default:
      break
    }
  }

  private func sendDesktopCommand(_ command: String) {
    desktopFeatureChannel?.invokeMethod("desktopCommand", arguments: command)
  }
}
