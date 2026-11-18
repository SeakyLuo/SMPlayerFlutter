import Cocoa

if CommandLine.arguments.contains(BackgroundSharing.workerArgument) {
  let app = NSApplication.shared
  app.setActivationPolicy(.prohibited)
  let delegate = SharingWorkerDelegate()
  app.delegate = delegate
  app.run()
} else {
  _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
