import Foundation
import UserNotifications

/// Local notifications for power events (power spec): currently the battery-floor
/// auto-stop banner. Authorization is requested lazily on the first Keep Awake
/// session start (design.md), only once, tracked with a UserDefaults flag.
///
/// `UNUserNotificationCenter.current()` aborts in a process with no bundle identifier,
/// which is exactly the unbundled `.build/debug/Tiler` the acceptance script drives —
/// so every entry point guards on `Bundle.main.bundleIdentifier`. Banners only ever
/// fire from the installed, signed `.app` (bundle id pro.amilabs.tilerx).
@MainActor public final class PowerNotifier {
    private let requestedKey = "powerNotifAuthRequested"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func requestAuthOnce() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        guard !defaults.bool(forKey: requestedKey) else { return }
        defaults.set(true, forKey: requestedKey)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("Tiler: notification auth error: %@", error.localizedDescription)
            } else {
                NSLog("Tiler: notification auth %@", granted ? "granted" : "denied")
            }
        }
    }

    public func floorStop(percent: Int) {
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("Tiler: floor stop at %d%% (unbundled — no banner)", percent)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Keep Awake stopped"
        content.body = "Battery at \(percent)% — reached the floor."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "tiler.floorStop.\(UUID().uuidString)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("Tiler: floor notification failed: %@", error.localizedDescription)
            }
        }
    }
}
