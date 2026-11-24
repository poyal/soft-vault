import AppKit
import Darwin

@_silgen_name("run_standalone_trial")
func runTrial(_ argc: Int32, _ argv: UnsafePointer<UnsafePointer<CChar>?>) -> Int32

let application = NSApplication.shared
application.setActivationPolicy(.regular)
DispatchQueue.global().async {
    let arguments = CommandLine.arguments.map { strdup($0) }
    defer { arguments.forEach { free($0) } }
    let pointers = arguments.map { UnsafePointer<CChar>($0) }
    let status = pointers.withUnsafeBufferPointer {
        runTrial(Int32($0.count), $0.baseAddress!)
    }
    exit(status)
}
application.run()
