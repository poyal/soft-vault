import Cocoa
import FlutterMacOS

@objc(SoftVaultApplication)
class SoftVaultApplication: NSApplication {
  var exitChannel: FlutterMethodChannel?
  private var preparingToQuit = false

  override func terminate(_ sender: Any?) {
    guard !preparingToQuit else { return }
    guard let channel = exitChannel else {
      super.terminate(sender)
      return
    }

    // Keep AppKit's normal event loop running while Flutter drains seeks and
    // releases video textures. Enter native termination only after that work.
    preparingToQuit = true
    channel.invokeMethod("System.requestAppExit", arguments: nil) { reply in
      if (reply as? [String: Any])?["response"] as? String == "exit" {
        super.terminate(sender)
      }
      self.preparingToQuit = false
    }
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    // SoftVaultApplication has already consulted Flutter before entering AppKit.
    return .terminateNow
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
