import AppKit
import Carbon.HIToolbox
import TilerCore

/// Global fixed hotkeys via Carbon `RegisterEventHotKey` (hotkeys spec): needs no
/// TCC permission, is event-driven, and cannot stall or disable system input —
/// registration is deliberately independent of the Accessibility permission.
/// Double Ctrl+Shift+↑ is disambiguated by the pure `DoublePressResolver`.
@MainActor
public final class HotkeyController {
    public var handler: ((TilingCommand) -> Void)?

    private enum Key: UInt32, CaseIterable {
        case left = 1, right, up, down, cmdLeft, cmdRight

        var keyCode: UInt32 {
            switch self {
            case .left, .cmdLeft: UInt32(kVK_LeftArrow)
            case .right, .cmdRight: UInt32(kVK_RightArrow)
            case .up: UInt32(kVK_UpArrow)
            case .down: UInt32(kVK_DownArrow)
            }
        }

        var modifiers: UInt32 {
            switch self {
            case .left, .right, .up, .down: UInt32(controlKey | shiftKey)
            case .cmdLeft, .cmdRight: UInt32(cmdKey | controlKey | shiftKey)
            }
        }
    }

    private let signature: OSType = 0x54494C52 // 'TILR'
    private var resolver: DoublePressResolver
    private var registered: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    private var expiryTimer: DispatchSourceTimer?

    public init(tunables: Tunables = .default) {
        resolver = DoublePressResolver(window: tunables.doublePressWindow)
    }

    /// Registers all bindings. Failures are logged per key; the app stays alive.
    public func registerAll() {
        installEventHandlerIfNeeded()
        for key in Key.allCases {
            var ref: EventHotKeyRef?
            let hotkeyID = EventHotKeyID(signature: signature, id: key.rawValue)
            let status = RegisterEventHotKey(key.keyCode, key.modifiers, hotkeyID,
                                             GetApplicationEventTarget(), 0, &ref)
            if status != noErr {
                NSLog("Tiler: RegisterEventHotKey failed for \(key) (status \(status))")
            }
            registered.append(ref)
        }
        NSLog("Tiler: hotkeys registered")
    }

    public func unregisterAll() {
        for ref in registered {
            if let ref { UnregisterEventHotKey(ref) }
        }
        registered = []
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            guard status == noErr else { return status }
            let controller = Unmanaged<HotkeyController>.fromOpaque(userData).takeUnretainedValue()
            // Carbon dispatches on the main thread.
            MainActor.assumeIsolated {
                controller.handlePress(id: hotkeyID.id)
            }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType,
                            Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }

    private func handlePress(id: UInt32) {
        guard let key = Key(rawValue: id) else { return }
        NSLog("Tiler: hotkey pressed: \(key)")
        switch key {
        case .left:
            emit(.leftHalf(nextDisplay: false))
        case .right:
            emit(.rightHalf(nextDisplay: false))
        case .down:
            emit(.restore)
        case .cmdLeft:
            emit(.leftHalf(nextDisplay: true))
        case .cmdRight:
            emit(.rightHalf(nextDisplay: true))
        case .up:
            let now = ProcessInfo.processInfo.systemUptime
            if let decision = resolver.registerPress(at: now) {
                cancelExpiryTimer()
                emit(decision == .centerThird ? .centerThird : .maximize)
            } else {
                scheduleExpiryTimer()
            }
        }
    }

    private func scheduleExpiryTimer() {
        cancelExpiryTimer()
        guard let deadline = resolver.deadline else { return }
        let delay = max(0, deadline - ProcessInfo.processInfo.systemUptime) + 0.005
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.expiryTimer = nil
                let now = ProcessInfo.processInfo.systemUptime
                if let decision = self.resolver.resolveExpired(now: now) {
                    self.emit(decision == .maximize ? .maximize : .centerThird)
                }
            }
        }
        timer.resume()
        expiryTimer = timer
    }

    private func cancelExpiryTimer() {
        expiryTimer?.cancel()
        expiryTimer = nil
    }

    private func emit(_ command: TilingCommand) {
        handler?(command)
    }
}
