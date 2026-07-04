import AppKit
import ApplicationServices

@main
struct TilerMain {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--mt-probe") {
            MTProbe.run(seconds: 3)
            return
        }
        // Diagnostic: write AXIsProcessTrusted() + pid/ppid to a file and exit.
        // Lets us read the *own-permission* state regardless of stdout/log routing.
        if let i = args.firstIndex(of: "--ax-report"), args.indices.contains(i + 1) {
            let trusted = AXIsProcessTrusted()
            let report = "trusted=\(trusted) pid=\(getpid()) ppid=\(getppid())\n"
            try? report.write(toFile: args[i + 1], atomically: true, encoding: .utf8)
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
