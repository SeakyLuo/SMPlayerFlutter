import Cocoa
import ImageIO
import FlutterMacOS
import UserNotifications

final class TrackNotifications: NSObject, UNUserNotificationCenterDelegate {
  private weak var window: NSWindow?

  init(window: NSWindow) {
    self.window = window
    super.init()
  }

  func show(_ payload: [String: Any], result: @escaping FlutterResult) {
    let content = UNMutableNotificationContent()
    content.title = payload["title"] as! String
    content.body = payload["body"] as! String
    if !(payload["silent"] as! Bool) {
      content.sound = .default
    }
    content.userInfo = ["songId": payload["songId"]!]
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      if let error = error {
        self.finish(result, code: "notification_failed", error: error)
      } else if !granted {
        self.finish(result, code: "notifications_denied")
      } else {
        let artworkPath = payload["artworkPath"] as! String
        let attachmentURL = artworkPath.isEmpty ? nil : FileManager.default.temporaryDirectory
          .appendingPathComponent("smplayer-notification-\(UUID().uuidString).img")
        do {
          if let attachmentURL = attachmentURL {
            content.attachments = [try self.artworkAttachment(path: artworkPath, copyURL: attachmentURL)]
          }
          let request = UNNotificationRequest(
            identifier: "smplayer-track-\(payload["songId"]!)-\(UUID().uuidString)",
            content: content,
            trigger: nil)
          center.add(request) { error in
            self.removeAttachmentCopy(attachmentURL)
            if let error = error {
              self.finish(result, code: "notification_failed", error: error)
            } else {
              DispatchQueue.main.async { result(nil) }
            }
          }
        } catch {
          self.removeAttachmentCopy(attachmentURL)
          self.finish(result, code: "notification_failed", error: error)
        }
      }
    }
  }

  private func artworkAttachment(path: String, copyURL: URL) throws -> UNNotificationAttachment {
    let originalURL = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(originalURL as CFURL, nil),
          let type = CGImageSourceGetType(source) else {
      throw CocoaError(.fileReadCorruptFile)
    }
    // Notifications move attachments into their store; retain the shared artwork cache.
    try FileManager.default.copyItem(at: originalURL, to: copyURL)
    return try UNNotificationAttachment(
      identifier: "album-cover", url: copyURL,
      options: [UNNotificationAttachmentOptionsTypeHintKey: type as String,
                UNNotificationAttachmentOptionsThumbnailHiddenKey: false])
  }

  private func removeAttachmentCopy(_ url: URL?) {
    guard let url = url, FileManager.default.fileExists(atPath: url.path) else { return }
    do { try FileManager.default.removeItem(at: url) }
    catch { NSLog("Notification attachment cleanup failed: %@", error.localizedDescription) }
  }

  private func finish(_ result: @escaping FlutterResult, code: String, error: Error? = nil) {
    let details = error.map { error -> [String: Any] in
      let nativeError = error as NSError
      return ["domain": nativeError.domain, "code": nativeError.code,
              "description": nativeError.localizedDescription]
    }
    if let details = details {
      NSLog("System notification failed: %@", String(describing: details))
    }
    let resultCode: String
    if let nativeError = error as NSError?,
       nativeError.domain == UNErrorDomain,
       nativeError.code == UNError.Code.notificationsNotAllowed.rawValue {
      resultCode = "notifications_denied"
    } else {
      resultCode = code
    }
    DispatchQueue.main.async {
      result(FlutterError(code: resultCode, message: error?.localizedDescription, details: details))
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .list])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    DispatchQueue.main.async {
      if self.window?.isMiniaturized == true {
        self.window?.deminiaturize(nil)
      }
      self.window?.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      completionHandler()
    }
  }
}
