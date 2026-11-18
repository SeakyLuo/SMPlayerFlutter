import Cocoa
import FlutterMacOS
import ServiceManagement
import flutter_secure_storage_macos
import package_info_plus
import sqlite3_flutter_libs

final class BackgroundSharing {
  static let workerArgument = "--sharing-worker"
  static let plistName = "com.seaky.smplayer.sharing.plist"
  private var channel: FlutterMethodChannel?
  private var process: Process?

  func register(with engine: FlutterEngine) {
    channel = FlutterMethodChannel(
      name: "smplayer_flutter/background_sharing", binaryMessenger: engine.binaryMessenger)
    channel?.setMethodCallHandler { call, result in
      switch call.method {
      case "directoryBookmark":
        let bookmarks = UserDefaults.standard.dictionary(forKey: "securityScopedDirectoryBookmarks") as? [String: String] ?? [:]
        result(bookmarks[call.arguments as! String])
      case "supported": result(ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13)
      case "start":
        do {
          let process = Process()
          process.executableURL = Bundle.main.executableURL!
          process.arguments = [Self.workerArgument]
          process.standardInput = FileHandle.nullDevice
          process.standardOutput = FileHandle.nullDevice
          process.standardError = FileHandle.nullDevice
          try process.run()
          self.process = process
          result(nil)
        } catch { result(FlutterError(code: "background_start_failed", message: error.localizedDescription, details: nil)) }
      case "stop":
        if let process = self.process, process.isRunning {
          process.terminate()
          process.waitUntilExit()
        }
        self.process = nil
        result(nil)
      case "setLoginEnabled":
        guard #available(macOS 13.0, *) else {
          result(FlutterError(code: "background_unsupported", message: nil, details: nil)); return
        }
        let service = SMAppService.agent(plistName: Self.plistName)
        do {
          if call.arguments as! Bool {
            if service.status == .requiresApproval {
              result(FlutterError(code: "background_approval_required", message: nil, details: nil)); return
            }
            if service.status != .enabled { try service.register() }
            guard service.status == .enabled else {
              result(FlutterError(code: "background_approval_required", message: nil, details: nil)); return
            }
          } else if service.status != .notRegistered { try service.unregister() }
          result(nil)
        } catch { result(FlutterError(code: "background_registration_failed", message: error.localizedDescription, details: nil)) }
      case "openSettings":
        if #available(macOS 13.0, *) { SMAppService.openSystemSettingsLoginItems() }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}

final class SharingWorkerDelegate: NSObject, NSApplicationDelegate {
  private var engine: FlutterEngine?
  private var directoryAccess: [URL] = []
  private var channel: FlutterMethodChannel?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // The worker has no window; it restores the same sandbox grants as the UI.
    SmPlayerExternalFileAccessStore.shared.restoreAccess()
    let bookmarks = UserDefaults.standard.dictionary(forKey: "securityScopedDirectoryBookmarks") as? [String: String] ?? [:]
    for encoded in bookmarks.values {
      do { try restoreDirectoryAccess(encoded) }
      catch { NSLog("Background sharing directory access failed: \(error)") }
    }
    let engine = FlutterEngine(name: "SMPlayerSharing", project: nil, allowHeadlessExecution: true)
    self.engine = engine
    engine.run(withEntrypoint: "backgroundSharingMain")
    FlutterSecureStoragePlugin.register(with: engine.registrar(forPlugin: "FlutterSecureStoragePlugin"))
    FPPPackageInfoPlusPlugin.register(with: engine.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
    Sqlite3FlutterLibsPlugin.register(with: engine.registrar(forPlugin: "Sqlite3FlutterLibsPlugin"))
    channel = FlutterMethodChannel(name: "smplayer_flutter/background_sharing", binaryMessenger: engine.binaryMessenger)
    channel?.setMethodCallHandler { call, result in
      guard call.method == "updateFileAccess" else { result(FlutterMethodNotImplemented); return }
      do {
        try self.restoreDirectoryAccess(call.arguments as! String)
        result(nil)
      } catch {
        result(FlutterError(code: "background_directory_access_failed", message: error.localizedDescription, details: nil))
      }
    }
  }
  private func restoreDirectoryAccess(_ encoded: String) throws {
    var stale = false
    let url = try URL(resolvingBookmarkData: Data(base64Encoded: encoded)!,
      options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
    if directoryAccess.contains(url) { return }
    guard url.startAccessingSecurityScopedResource() else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
    }
    directoryAccess.append(url)
  }

}
