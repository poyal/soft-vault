import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(name: "soft_vault/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard let path = call.arguments as? String else { result(FlutterMethodNotImplemented); return }
      let url = URL(fileURLWithPath: path)
      switch call.method {
      case "reveal":
        NSWorkspace.shared.activateFileViewerSelecting([url]); result(nil)
      case "trash":
        do { try FileManager.default.trashItem(at: url, resultingItemURL: nil); result(nil) }
        catch { result(FlutterError(code: "file_operation", message: error.localizedDescription, details: nil)) }
      default: result(FlutterMethodNotImplemented)
      }
    }
    super.awakeFromNib()
  }
}
