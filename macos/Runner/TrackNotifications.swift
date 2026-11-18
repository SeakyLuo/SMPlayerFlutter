import Cocoa
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
    let request = UNNotificationRequest(
      identifier: "smplayer-track-\(payload["songId"]!)-\(UUID().uuidString)",
      content: content,
      trigger: nil)
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      if let error = error {
        self.finish(result, code: "notification_failed", error: error)
      } else if !granted {
        self.finish(result, code: "notifications_denied")
      } else {
        center.add(request) { error in
          if let error = error {
            self.finish(result, code: "notification_failed", error: error)
          } else {
            DispatchQueue.main.async { result(nil) }
          }
        }
      }
    }
  }

  private func finish(_ result: @escaping FlutterResult, code: String, error: Error? = nil) {
    DispatchQueue.main.async {
      result(FlutterError(code: code, message: error?.localizedDescription, details: nil))
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
