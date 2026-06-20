import Cocoa
import FlutterMacOS
import XCTest

class RunnerTests: XCTestCase {

  func testDesktopLyricsPreservesVisibleSavedFrameOnSecondaryScreen() {
    let primary = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let secondary = NSRect(x: 1440, y: 0, width: 1920, height: 1080)
    let savedOnSecondary = "{\"x\":1600,\"y\":86,\"width\":760,\"height\":148}"

    let frame = DesktopLyricsWindowGeometry.resolveFrame(
      rawBounds: savedOnSecondary,
      targetVisibleFrame: primary,
      screenVisibleFrames: [primary, secondary])

    XCTAssertEqual(frame.origin.x, 1600, accuracy: 0.001)
    XCTAssertEqual(frame.origin.y, 86, accuracy: 0.001)
  }

  func testDesktopLyricsMovesSavedPrimaryFrameToTargetSecondaryScreen() {
    let primary = NSRect(x: 0, y: 0, width: 1728, height: 1083)
    let secondary = NSRect(x: 1728, y: 125, width: 1920, height: 961)
    let savedOnPrimary = "{\"x\":417,\"y\":86,\"width\":760,\"height\":148}"

    let frame = DesktopLyricsWindowGeometry.resolveFrame(
      rawBounds: savedOnPrimary,
      targetVisibleFrame: secondary,
      screenVisibleFrames: [primary, secondary])

    XCTAssertEqual(frame.origin.x, 2145, accuracy: 0.001)
    XCTAssertEqual(frame.origin.y, 211, accuracy: 0.001)
  }

  func testDesktopLyricsMovesDisconnectedSecondaryFrameToTargetScreen() {
    let primary = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let savedOnSecondary = "{\"x\":1600,\"y\":86,\"width\":760,\"height\":148}"

    let frame = DesktopLyricsWindowGeometry.resolveFrame(
      rawBounds: savedOnSecondary,
      targetVisibleFrame: primary,
      screenVisibleFrames: [primary])

    XCTAssertEqual(frame.origin.x, 340, accuracy: 0.001)
    XCTAssertEqual(frame.origin.y, 120, accuracy: 0.001)
  }

  func testDesktopLyricsDefaultFrameUsesTargetScreen() {
    let primary = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let secondary = NSRect(x: 1440, y: 0, width: 1920, height: 1080)

    let frame = DesktopLyricsWindowGeometry.resolveFrame(
      rawBounds: nil,
      targetVisibleFrame: secondary,
      screenVisibleFrames: [primary, secondary])

    XCTAssertEqual(frame.origin.x, 2020, accuracy: 0.001)
    XCTAssertEqual(frame.origin.y, 120, accuracy: 0.001)
  }

  func testDesktopLyricsRequiresMeaningfulVisibleIntersection() {
    let primary = NSRect(x: 0, y: 0, width: 1440, height: 900)

    XCTAssertFalse(
      DesktopLyricsWindowGeometry.frameIsVisible(
        NSRect(x: 1300, y: 50, width: 760, height: 148),
        screenVisibleFrames: [primary]))
    XCTAssertTrue(
      DesktopLyricsWindowGeometry.frameIsVisible(
        NSRect(x: 1280, y: 50, width: 760, height: 148),
        screenVisibleFrames: [primary]))
  }

}
