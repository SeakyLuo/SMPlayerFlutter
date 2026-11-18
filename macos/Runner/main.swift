import Cocoa

if CommandLine.arguments.contains(BackgroundSharing.workerArgument) {
  // The worker has no debugger attached. Inheriting the UI engine switches
  // (especially start-paused) leaves its isolate suspended indefinitely.
  for key in ProcessInfo.processInfo.environment.keys
    where key == "FLUTTER_ENGINE_SWITCHES" || key.hasPrefix("FLUTTER_ENGINE_SWITCH_") {
    unsetenv(key)
  }
  let app = NSApplication.shared
  app.setActivationPolicy(.prohibited)
  let delegate = SharingWorkerDelegate()
  app.delegate = delegate
  app.run()
} else {
  _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
