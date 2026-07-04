import AppKit
import SwiftUI

/// About window (app-shell spec): icon, name, version, build time, GitHub link.
struct AboutView: View {
    static let repoURL = URL(string: "https://github.com/amilabs/Tiler")!

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AppDelegate.version
    }

    private var buildDate: String {
        Bundle.main.infoDictionary?["TilerBuildDate"] as? String ?? "dev build (swift run)"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Tiler")
                .font(.title2.weight(.medium))
            Text("Move and resize windows with hotkeys\nand precise 3-finger trackpad gestures.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Divider().frame(width: 220)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Version").foregroundStyle(.secondary)
                    Text(version)
                }
                GridRow {
                    Text("Built").foregroundStyle(.secondary)
                    Text(buildDate)
                }
            }
            .font(.callout)
            Link("github.com/amilabs/Tiler", destination: Self.repoURL)
                .font(.callout)
        }
        .padding(28)
        .frame(width: 320)
    }
}

/// Reusable host for small auxiliary windows in this LSUIElement app.
@MainActor
final class AuxWindow<Content: View> {
    private var window: NSWindow?
    private let title: String
    private let content: () -> Content

    init(title: String, content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: content())
            let window = NSWindow(contentViewController: hosting)
            window.title = title
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
