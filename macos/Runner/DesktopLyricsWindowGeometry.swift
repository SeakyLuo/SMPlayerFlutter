import AppKit
import Foundation

enum DesktopLyricsWindowGeometry {
  static let defaultSize = NSSize(width: 760, height: 148)

  private static let minimumVisibleSize = NSSize(width: 160, height: 40)

  static func resolveFrame(
    rawBounds: String?,
    targetVisibleFrame: NSRect,
    screenVisibleFrames: [NSRect]
  ) -> NSRect {
    if let rawBounds = rawBounds,
       let data = rawBounds.data(using: .utf8),
       let value = try? JSONSerialization.jsonObject(with: data) as? [String: Double],
       let x = value["x"],
       let y = value["y"] {
      let candidate = NSRect(
        x: x,
        y: y,
        width: defaultSize.width,
        height: defaultSize.height)
      if frameIsVisible(candidate, screenVisibleFrames: [targetVisibleFrame]) {
        return candidate
      }
      if let sourceFrame = screenVisibleFrames.first(where: { screenFrame in
        frameIsVisible(candidate, screenVisibleFrames: [screenFrame])
      }) {
        return translateFrame(candidate, from: sourceFrame, to: targetVisibleFrame)
      }
    }

    return NSRect(
      x: targetVisibleFrame.midX - defaultSize.width / 2,
      y: targetVisibleFrame.minY + 120,
      width: defaultSize.width,
      height: defaultSize.height)
  }

  static func frameIsVisible(
    _ frame: NSRect,
    screenVisibleFrames: [NSRect]
  ) -> Bool {
    for screenFrame in screenVisibleFrames {
      let intersection = screenFrame.intersection(frame)
      if !intersection.isNull &&
          intersection.width >= minimumVisibleSize.width &&
          intersection.height >= minimumVisibleSize.height {
        return true
      }
    }
    return false
  }

  private static func translateFrame(
    _ frame: NSRect,
    from sourceFrame: NSRect,
    to targetFrame: NSRect
  ) -> NSRect {
    let maxXOffset = max(0, targetFrame.width - frame.width)
    let maxYOffset = max(0, targetFrame.height - frame.height)
    let xOffset = min(max(0, frame.minX - sourceFrame.minX), maxXOffset)
    let yOffset = min(max(0, frame.minY - sourceFrame.minY), maxYOffset)
    return NSRect(
      x: targetFrame.minX + xOffset,
      y: targetFrame.minY + yOffset,
      width: frame.width,
      height: frame.height)
  }
}
