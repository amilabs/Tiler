import AppKit

@main
struct TilerMain {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--mt-probe") {
            MTProbe.run(seconds: 3)
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
