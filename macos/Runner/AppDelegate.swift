import Cocoa
import FlutterMacOS

extension Notification.Name {
  static let smPlayerExternalOpenArguments = Notification.Name(
    "smplayer.externalOpenArguments")
}

final class SmPlayerExternalOpenArgumentsStore {
  static let shared = SmPlayerExternalOpenArgumentsStore()

  private var pendingArguments: [String] = []

  private init() {}

  func enqueue(_ arguments: [String]) {
    pendingArguments.append(contentsOf: arguments)
  }

  func takePending() -> [String] {
    let arguments = pendingArguments
    pendingArguments.removeAll()
    return arguments
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    SmPlayerExternalOpenArgumentsStore.shared.enqueue(filenames)
    NotificationCenter.default.post(
      name: .smPlayerExternalOpenArguments,
      object: nil)
    sender.reply(toOpenOrPrint: .success)
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    let arguments = urls.map { url in
      url.isFileURL ? url.path : url.absoluteString
    }
    SmPlayerExternalOpenArgumentsStore.shared.enqueue(arguments)
    NotificationCenter.default.post(
      name: .smPlayerExternalOpenArguments,
      object: nil)
  }
}
