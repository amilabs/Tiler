import AppKit
import SwiftUI

/// About window (app-shell spec): icon, name, version, build time, GitHub link.
struct AboutView: View {
    static let repoURL = URL(string: "https://github.com/amilabs/Tiler")!

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AppDelegate.version
    }

    /// Build stamp is ISO8601 UTC in Info.plist; shown in the user's local time.
    private var buildDate: String {
        guard let raw = Bundle.main.infoDictionary?["TilerBuildDate"] as? String else {
            return "dev build (swift run)"
        }
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Tiler")
                .font(.title2.weight(.medium))
            Text("""
            Tiler snaps the active window into halves, maximized, or a centered \
            third — on any of your displays — driven by fixed hotkeys and precise \
            three-finger trackpad swipes. It is built reliability-first: a swipe \
            counts only when exactly three fingers move decisively, so ordinary \
            scrolling never touches your windows, and swipe thresholds can be \
            calibrated to your hand. See Shortcuts & Help in the menu for the full \
            reference.
            """)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
        .frame(width: 380)
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
