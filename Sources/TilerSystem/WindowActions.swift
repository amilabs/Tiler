import AppKit
import ApplicationServices
import TilerCore

/// Tiling command routed from a hotkey or a confirmed gesture.
public enum TilingCommand: Equatable, Sendable {
    case leftHalf(nextDisplay: Bool)
    case rightHalf(nextDisplay: Bool)
    case maximize
    case centerThird
    case restore
}

/// AX window manipulation layer (specs/window-actions/spec.md).
/// Every AX failure is a logged no-op — nothing here may crash or throw upward.
@MainActor
public final class WindowActions {
    /// Hashable wrapper so AXUIElement (CFEqual/CFHash semantics) can key dictionaries.
    private struct WindowKey: Hashable {
        let element: AXUIElement
        static func == (lhs: Self, rhs: Self) -> Bool { CFEqual(lhs.element, rhs.element) }
        func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
    }

    /// Frame each window had before Tiler's first action on it (AX coordinates).
    private var originalFrames: [WindowKey: CGRect] = [:]
    /// Last frame Tiler set per window — detects manual user moves in between.
    private var lastSetFrames: [WindowKey: CGRect] = [:]

    public init() {}

    /// Acts on the focused window of the frontmost application.
    /// Returns false when AX is unusable (no permission / no window) so the caller
    /// can feed PermissionMonitor.noteActionFailed().
    @discardableResult
    public func perform(_ command: TilingCommand) -> Bool {
        guard let (app, window) = frontmostFocusedWindow() else {
            NSLog("Tiler: no focused window for \(command) — ignoring")
            return false
        }
        return perform(command, app: app, window: window)
    }

    /// Testable entry point with an explicit target (integration tests resolve
    /// the window by pid instead of relying on frontmost focus).
    @discardableResult
    public func perform(_ command: TilingCommand, app: AXUIElement, window: AXUIElement) -> Bool {
        trimStoresIfNeeded()
        guard let currentAX = frame(of: window) else {
            NSLog("Tiler: cannot read window frame — ignoring \(command)")
            return false
        }
        let key = WindowKey(element: window)

        if command == .restore {
            guard let original = originalFrames[key] else {
                NSLog("Tiler: no restore history for this window")
                return true // defined no-op, not an AX failure
            }
            setFrame(original, window: window, app: app)
            lastSetFrames[key] = original
            return true
        }

        // Capture the pre-Tiler frame; re-capture if the user moved the window
        // manually since our last action.
        if originalFrames[key] == nil || lastSetFrames[key] != currentAX {
            originalFrames[key] = currentAX
        }

        guard let targetCocoa = targetRect(for: command, currentAXFrame: currentAX) else {
            NSLog("Tiler: no screen geometry for \(command) — ignoring")
            return true
        }
        let targetAX = cocoaToAX(targetCocoa)
        setFrame(targetAX, window: window, app: app)
        lastSetFrames[key] = targetAX
        return true
    }

    // MARK: - Geometry

    private func targetRect(for command: TilingCommand, currentAXFrame: CGRect) -> CGRect? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let cocoaFrame = axToCocoa(currentAXFrame)
        let current = screens.max(by: { area($0.frame.intersection(cocoaFrame)) < area($1.frame.intersection(cocoaFrame)) })
            ?? screens[0]

        func half(of screen: NSScreen, left: Bool) -> CGRect {
            let vf = screen.visibleFrame
            return CGRect(x: left ? vf.minX : vf.minX + vf.width / 2, y: vf.minY,
                          width: vf.width / 2, height: vf.height)
        }

        switch command {
        case .maximize:
            return current.visibleFrame
        case .centerThird:
            let vf = current.visibleFrame
            return CGRect(x: vf.minX + vf.width / 3, y: vf.minY, width: vf.width / 3, height: vf.height)
        case .leftHalf(let nextDisplay):
            return half(of: nextDisplay ? next(after: current, in: screens) : current, left: true)
        case .rightHalf(let nextDisplay):
            return half(of: nextDisplay ? next(after: current, in: screens) : current, left: false)
        case .restore:
            return nil
        }
    }

    private func next(after screen: NSScreen, in screens: [NSScreen]) -> NSScreen {
        guard let idx = screens.firstIndex(of: screen) else { return screen }
        return screens[(idx + 1) % screens.count]
    }

    private func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }

    /// Cocoa global coords (origin bottom-left of primary, +y up) ↔ AX/CG coords
    /// (origin top-left of primary, +y down).
    private var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    private func cocoaToAX(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private func axToCocoa(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    // MARK: - AX plumbing

    private func frontmostFocusedWindow() -> (AXUIElement, AXUIElement)? {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return nil }
        let app = AXUIElementCreateApplication(frontmost.processIdentifier)
        guard let window = copyElement(app, kAXFocusedWindowAttribute as String) else { return nil }
        return (app, window)
    }

    public func frame(of window: AXUIElement) -> CGRect? {
        guard let position: CGPoint = copyValue(window, kAXPositionAttribute as String, .cgPoint),
              let size: CGSize = copyValue(window, kAXSizeAttribute as String, .cgSize) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    /// Applies a target frame robustly across displays of different sizes.
    ///
    /// macOS clamps a window's size to the display it currently occupies, and the
    /// window server reassociates a window with its new display only after the move
    /// is processed. So we **position first** (move onto the target display, where
    /// position is not size-clamped), then size (now bounded by the target display),
    /// then re-assert both (an AX size change grows from the top-left and can nudge
    /// the origin). Finally we read back and, if the result is off — which happens
    /// when the target display is larger than the source and the first size still got
    /// clamped — retry the position→size pair once. Clears AXEnhancedUserInterface
    /// first (Chrome/Electron animated-move bug).
    private func setFrame(_ axRect: CGRect, window: AXUIElement, app: AXUIElement) {
        let enhancedAttr = "AXEnhancedUserInterface"
        let wasEnhanced = boolAttribute(app, enhancedAttr) == true
        if wasEnhanced { setBoolAttribute(app, enhancedAttr, false) }
        defer { if wasEnhanced { setBoolAttribute(app, enhancedAttr, true) } }

        setPosition(window, axRect.origin)
        setSize(window, axRect.size)
        setPosition(window, axRect.origin)
        setSize(window, axRect.size)

        // Verify and self-correct once (defeats the reassociation-lag size clamp).
        if let achieved = frame(of: window), !frameMatches(achieved, axRect) {
            setPosition(window, axRect.origin)
            setSize(window, axRect.size)
            setPosition(window, axRect.origin)
        }
    }

    private func frameMatches(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 3) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }

    private func setPosition(_ window: AXUIElement, _ point: CGPoint) {
        var value = point
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return }
        let err = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axValue)
        if err != .success { NSLog("Tiler: AX setPosition failed (\(err.rawValue))") }
    }

    private func setSize(_ window: AXUIElement, _ size: CGSize) {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return }
        let err = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axValue)
        if err != .success { NSLog("Tiler: AX setSize failed (\(err.rawValue))") }
    }

    private func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    private func copyValue<T>(_ element: AXUIElement, _ attribute: String, _ type: AXValueType) -> T? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let axValue = raw as! AXValue
        switch type {
        case .cgPoint:
            var point = CGPoint.zero
            guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
            return point as? T
        case .cgSize:
            var size = CGSize.zero
            guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
            return size as? T
        default:
            return nil
        }
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == CFBooleanGetTypeID() else { return nil }
        return CFBooleanGetValue((raw as! CFBoolean))
    }

    private func setBoolAttribute(_ element: AXUIElement, _ attribute: String, _ value: Bool) {
        AXUIElementSetAttributeValue(element, attribute as CFString, value ? kCFBooleanTrue : kCFBooleanFalse)
    }

    /// Drop entries for windows that no longer answer AX queries (closed windows).
    private func trimStoresIfNeeded() {
        guard originalFrames.count > 64 else { return }
        for key in originalFrames.keys {
            var raw: CFTypeRef?
            if AXUIElementCopyAttributeValue(key.element, kAXRoleAttribute as CFString, &raw) != .success {
                originalFrames.removeValue(forKey: key)
                lastSetFrames.removeValue(forKey: key)
            }
        }
    }
}
