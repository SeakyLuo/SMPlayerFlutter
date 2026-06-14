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

final class SmPlayerExternalFileAccessStore {
  static let shared = SmPlayerExternalFileAccessStore()

  private let bookmarkDefaultsKey = "securityScopedExternalFileBookmarks"
  private var securityScopedFileUrls: [URL] = []

  private init() {}

  func storeAccess(for url: URL) {
    do {
      let bookmarkData = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil)
      var bookmarks = UserDefaults.standard.dictionary(
        forKey: bookmarkDefaultsKey) as? [String: String] ?? [:]
      bookmarks[url.path] = bookmarkData.base64EncodedString()
      UserDefaults.standard.set(bookmarks, forKey: bookmarkDefaultsKey)
      startAccessing(url)
    } catch {
      NSLog("Simple Melody Player failed to store external file bookmark: \(error)")
    }
  }

  func restoreAccess() {
    let bookmarks = UserDefaults.standard.dictionary(
      forKey: bookmarkDefaultsKey) as? [String: String] ?? [:]
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
        startAccessing(url)
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
        NSLog("Simple Melody Player failed to restore external file bookmark: \(error)")
      }
    }
    UserDefaults.standard.set(nextBookmarks, forKey: bookmarkDefaultsKey)
  }

  func stopAccessingAll() {
    for url in securityScopedFileUrls {
      url.stopAccessingSecurityScopedResource()
    }
    securityScopedFileUrls.removeAll()
  }

  private func startAccessing(_ url: URL) {
    if securityScopedFileUrls.contains(url) {
      return
    }
    if url.startAccessingSecurityScopedResource() {
      securityScopedFileUrls.append(url)
    }
  }
}

private enum SmPlayerPrivacyUsageDescriptions {
  private static let microphone =
    "Simple Melody Player uses the microphone for voice assistant commands."
  private static let speechRecognition =
    "Simple Melody Player uses speech recognition to run voice assistant commands."

  static func install() {
    let infoDictionary = unsafeBitCast(
      CFBundleGetInfoDictionary(CFBundleGetMainBundle()),
      to: NSMutableDictionary.self)
    infoDictionary["NSMicrophoneUsageDescription"] = microphone
    infoDictionary["NSSpeechRecognitionUsageDescription"] = speechRecognition
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override init() {
    SmPlayerPrivacyUsageDescriptions.install()
    super.init()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for filename in filenames {
      SmPlayerExternalFileAccessStore.shared.storeAccess(
        for: URL(fileURLWithPath: filename))
    }
    SmPlayerExternalOpenArgumentsStore.shared.enqueue(filenames)
    NotificationCenter.default.post(
      name: .smPlayerExternalOpenArguments,
      object: nil)
    sender.reply(toOpenOrPrint: .success)
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where url.isFileURL {
      SmPlayerExternalFileAccessStore.shared.storeAccess(for: url)
    }
    let arguments = urls.map { url in
      url.isFileURL ? url.path : url.absoluteString
    }
    SmPlayerExternalOpenArgumentsStore.shared.enqueue(arguments)
    NotificationCenter.default.post(
      name: .smPlayerExternalOpenArguments,
      object: nil)
  }

  override func applicationWillTerminate(_ notification: Notification) {
    SmPlayerExternalFileAccessStore.shared.stopAccessingAll()
  }
}
