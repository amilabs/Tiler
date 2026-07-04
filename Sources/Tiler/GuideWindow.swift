import AppKit
import SwiftUI
import TilerCore
import TilerSystem

/// False while the hosting window is closed or fully occluded — demo animations
/// MUST pause then (idle CPU budget: <1% whenever no fingers touch the pad).
private struct AnimationsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var animationsActive: Bool {
        get { self[AnimationsActiveKey.self] }
        set { self[AnimationsActiveKey.self] = newValue }
    }
}

@MainActor
final class WindowVisibility: ObservableObject {
    @Published var isVisible = true
}

private struct VisibilityGate<C: View>: View {
    @ObservedObject var visibility: WindowVisibility
    let content: C

    var body: some View {
        content.environment(\.animationsActive, visibility.isVisible)
    }
}

/// Single source for the cheat sheet, mirroring the hotkeys/gestures specs.
enum GuideContent {
    struct HotkeyRow: Identifiable {
        let id = UUID()
        let keys: [String]
        let action: String
    }

    struct GestureRow: Identifiable {
        let id = UUID()
        let direction: GestureDirection
        let cmd: Bool
        let action: String
    }

    struct ValueRow: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let text: String
    }

    static let tagline = "Put any window exactly where you want it — without touching the mouse."

    static let values: [ValueRow] = [
        ValueRow(symbol: "hand.raised.fill",
                 title: "A swipe you can trust",
                 text: "An action fires only when exactly three fingers move decisively in one direction. Scrolling, resting palms, and stray touches never move your windows."),
        ValueRow(symbol: "person.fill.checkmark",
                 title: "Tuned to your hand",
                 text: "Everyone swipes differently. One-minute calibration adapts the recognition angles to your strokes — within provably safe bounds."),
        ValueRow(symbol: "bolt.fill",
                 title: "Featherweight and unbreakable",
                 text: "Event-driven engine: under 1% CPU at idle, no input hooks, instant recovery when permissions change."),
    ]

    static let hotkeys: [HotkeyRow] = [
        HotkeyRow(keys: ["⌃", "⇧", "←"], action: "Left half of the current screen"),
        HotkeyRow(keys: ["⌃", "⇧", "→"], action: "Right half of the current screen"),
        HotkeyRow(keys: ["⌃", "⇧", "↑"], action: "Maximize (after a 0.3 s pause)"),
        HotkeyRow(keys: ["⌃", "⇧", "↑", "↑"], action: "Full height, centered, ⅓ width — double press"),
        HotkeyRow(keys: ["⌃", "⇧", "↓"], action: "Restore the window's previous frame"),
        HotkeyRow(keys: ["⌘", "⌃", "⇧", "←"], action: "Left half on the next display"),
        HotkeyRow(keys: ["⌘", "⌃", "⇧", "→"], action: "Right half on the next display"),
    ]

    static let gestures: [GestureRow] = [
        GestureRow(direction: .left, cmd: false, action: "Left half"),
        GestureRow(direction: .right, cmd: false, action: "Right half"),
        GestureRow(direction: .up, cmd: false, action: "Maximize"),
        GestureRow(direction: .left, cmd: true, action: "Left half on the next display"),
        GestureRow(direction: .right, cmd: true, action: "Right half on the next display"),
    ]

    static let gestureFootnote =
        "Exactly three fingers, one confident stroke. Two- and four-finger movements and swipe-down do nothing — by design."
}

@MainActor
final class GuideModel: ObservableObject {
    @Published var accessibilityGranted: Bool
    @Published var conflicts: [SystemConflict] = []

    var onOpenAccessibility: (() -> Void)?
    var onCalibrate: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    init(accessibilityGranted: Bool) {
        self.accessibilityGranted = accessibilityGranted
        refreshConflicts()
    }

    func refreshConflicts() {
        conflicts = ConflictDiagnostics().conflicts()
    }
}

/// Unified About & Guide (app-shell spec, unify-about-guide): story, live
/// permission card, full cheat sheet, troubleshooting, version footer.
struct GuideView: View {
    @ObservedObject var model: GuideModel

    // Two-column layout (owner: no vertical scrolling): story on the left,
    // the full reference on the right, header/permission/footer span both.
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            hero
            permissionCard
            HStack(alignment: .top, spacing: 30) {
                VStack(alignment: .leading, spacing: 14) {
                    valueSection
                    troubleshooting
                    Spacer(minLength: 0)
                }
                .frame(width: 340, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 14) {
                    section("Hotkeys") {
                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                            ForEach(GuideContent.hotkeys) { row in
                                GridRow {
                                    keycaps(row.keys)
                                        .gridColumnAlignment(.trailing)
                                    Text(row.action)
                                        .font(.callout)
                                }
                            }
                        }
                    }
                    section("Trackpad gestures") {
                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                            ForEach(GuideContent.gestures) { row in
                                GridRow {
                                    HStack(spacing: 6) {
                                        if row.cmd { keycaps(["⌘"]) }
                                        HoverDemo(direction: row.direction)
                                    }
                                    .gridColumnAlignment(.trailing)
                                    Text(row.action)
                                        .font(.callout)
                                }
                            }
                        }
                        Text(GuideContent.gestureFootnote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            footer
        }
        .padding(26)
        .frame(width: 880)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Hero & story

    private var hero: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text("Tiler")
                    .font(.title.weight(.medium))
                Text(GuideContent.tagline)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HeroDemoView()
                    .frame(width: 92, height: 50)
                    .background(Color.accentColor.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 12))
                Button {
                    model.onOpenSettings?()
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                        .font(.callout)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(GuideContent.values) { row in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: row.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.callout.weight(.medium))
                        Text(row.text)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Permission & troubleshooting

    @ViewBuilder
    private var permissionCard: some View {
        if model.accessibilityGranted {
            Label("Accessibility is granted — Tiler can move your windows.",
                  systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Tiler needs the Accessibility permission",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text("Without it hotkeys and gestures are recognized but windows won't move. Enable Tiler in the list — this card turns green by itself, no relaunch needed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings…") {
                    model.onOpenAccessibility?()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var troubleshooting: some View {
        section("Gestures not working well?") {
            VStack(alignment: .leading, spacing: 8) {
                if model.conflicts.isEmpty {
                    Label("No conflicting system gestures detected.", systemImage: "checkmark.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.conflicts, id: \.title) { conflict in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(conflict.title, systemImage: "exclamationmark.triangle")
                                .font(.callout)
                                .foregroundStyle(.orange)
                            Text(conflict.guidance)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    Text("Swipes are tuned to your hand in one minute:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Calibrate…") { model.onCalibrate?() }
                    Spacer()
                    Button("Settings…") { model.onOpenSettings?() }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Text("Tiler \(version)")
            Text("·").foregroundStyle(.tertiary)
            Text("built \(buildDate)")
            Text("·").foregroundStyle(.tertiary)
            Link("github.com/amilabs/Tiler", destination: URL(string: "https://github.com/amilabs/Tiler")!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AppDelegate.version
    }

    /// Build stamp is ISO8601 UTC in Info.plist; shown in the user's local time.
    private var buildDate: String {
        guard let raw = Bundle.main.infoDictionary?["TilerBuildDate"] as? String else {
            return "from source (swift run)"
        }
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Bits

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func keycaps(_ keys: [String]) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(minWidth: 22)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.secondary.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
                    )
            }
        }
    }
}

/// Hero animation: the three-finger demo cycling left → right → up.
struct HeroDemoView: View {
    var body: some View {
        // Periodic pose cycling: one redraw per 1.4 s — alive, but ~zero CPU
        // (idle budget holds even with the window open and focused).
        TimelineView(.periodic(from: .now, by: 1.4)) { context in
            let slot = Int(context.date.timeIntervalSinceReferenceDate / 1.4) % 3
            let direction: GestureDirection = [.left, .right, .up][slot]
            GestureDemoView(direction: direction, animated: false)
        }
    }
}

/// Static direction pose that comes alive under the pointer.
struct HoverDemo: View {
    let direction: GestureDirection
    @State private var hovered = false

    var body: some View {
        GestureDemoView(direction: direction, animated: hovered)
            .frame(width: 76, height: 34)
            .background(Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 8))
            .onHover { hovered = $0 }
    }
}

/// Non-generic NSWindowDelegate helper (generic NSObject subclasses can't expose
/// @objc members).
@MainActor
private final class AuxWindowDelegate: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

/// Reusable host for small auxiliary windows in this LSUIElement app.
/// CPU discipline: the window (and its SwiftUI animations) is fully RELEASED on
/// close and recreated on the next show; while open, occlusion pauses animations.
@MainActor
final class AuxWindow<Content: View> {
    private var window: NSWindow?
    private let title: String
    private let content: () -> Content
    private let visibility = WindowVisibility()
    private let delegateHelper = AuxWindowDelegate()
    private var occlusionObserver: NSObjectProtocol?

    init(title: String, content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    func show() {
        if window == nil {
            let root = VisibilityGate(visibility: visibility, content: content())
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = title
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            window.delegate = delegateHelper
            delegateHelper.onClose = { [weak self] in
                self?.releaseWindow()
            }
            occlusionObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.visibility.isVisible =
                        self.window?.occlusionState.contains(.visible) ?? false
                }
            }
            self.window = window
        }
        visibility.isVisible = true
        NSApp.activate(ignoringOtherApps: true)
        if let window, let screen = NSScreen.main {
            let maxHeight = screen.visibleFrame.height - 20
            if window.frame.height > maxHeight {
                var frame = window.frame
                frame.size.height = maxHeight
                window.setFrame(frame, display: true)
            }
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    private func releaseWindow() {
        visibility.isVisible = false
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
        occlusionObserver = nil
        window?.delegate = nil
        window = nil
    }
}
