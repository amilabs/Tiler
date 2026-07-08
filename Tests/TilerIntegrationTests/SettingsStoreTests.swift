import Foundation
import Testing
import TilerCore
@testable import TilerSystem

// Persisted app settings (settings spec): defaults, persistence, change notifications.
@MainActor
@Suite("Settings store") struct SettingsStoreTests {

    private func freshDefaults() -> UserDefaults {
        let name = "tiler-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsSplitByGroup() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.gesturesEnabled)
        #expect(!store.windowHotkeysEnabled, "window tiling hotkeys are OFF by default")
        #expect(store.utilityHotkeysEnabled, "utility hotkeys (lock screen) are ON by default")
    }

    @Test func togglesPersistAcrossInstances() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.gesturesEnabled = false
        store.windowHotkeysEnabled = true
        store.utilityHotkeysEnabled = false

        let reloaded = SettingsStore(defaults: defaults)
        #expect(!reloaded.gesturesEnabled)
        #expect(reloaded.windowHotkeysEnabled)
        #expect(!reloaded.utilityHotkeysEnabled)
    }

    @Test func changesNotifyObserver() {
        let store = SettingsStore(defaults: freshDefaults())
        var events: [String] = []
        store.onChange = { events.append("\($0.windowHotkeysEnabled)/\($0.utilityHotkeysEnabled)") }
        store.windowHotkeysEnabled = true
        store.utilityHotkeysEnabled = false
        store.utilityHotkeysEnabled = true
        #expect(events == ["true/true", "true/false", "true/true"])
    }

    @Test func settingSameValueDoesNotNotify() {
        let store = SettingsStore(defaults: freshDefaults())
        var count = 0
        store.onChange = { _ in count += 1 }
        store.gesturesEnabled = true   // already true
        #expect(count == 0)
    }

    @Test func tunablesOverridePersistsAndClears() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        #expect(store.tunablesOverride == nil)

        var custom = Tunables()
        custom.horizontalDominance = 1.42
        custom.verticalDominance = 1.9
        store.tunablesOverride = custom

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.tunablesOverride == custom)

        reloaded.tunablesOverride = nil
        #expect(SettingsStore(defaults: defaults).tunablesOverride == nil)
    }

    @Test func hasSeenGuideDefaultsFalseAndPersists() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        var notified = 0
        store.onChange = { _ in notified += 1 }
        #expect(!store.hasSeenGuide)
        store.hasSeenGuide = true
        #expect(SettingsStore(defaults: defaults).hasSeenGuide)
        #expect(notified == 0, "UX flag must not re-trigger engine wiring")
    }

    @Test func tunablesOverrideNotifies() {
        let store = SettingsStore(defaults: freshDefaults())
        var count = 0
        store.onChange = { _ in count += 1 }
        store.tunablesOverride = Tunables()
        store.tunablesOverride = nil
        #expect(count == 2)
    }

    // MARK: power keys (add-power-control)

    @Test func powerKeysDefault() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(!store.keepDisplayAwake)
        #expect(store.batteryFloorPercent == 20)
        #expect(!store.deepSleepOnBattery)
        #expect(store.powerSnapshot == nil)
    }

    @Test func powerKeysPersistAcrossInstances() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.keepDisplayAwake = true
        store.batteryFloorPercent = 10
        store.deepSleepOnBattery = true
        store.powerSnapshot = ["hibernatemode": "3", "powernap": "1"]

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.keepDisplayAwake)
        #expect(reloaded.batteryFloorPercent == 10)
        #expect(reloaded.deepSleepOnBattery)
        #expect(reloaded.powerSnapshot == ["hibernatemode": "3", "powernap": "1"])
    }

    @Test func powerSnapshotClears() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.powerSnapshot = ["hibernatemode": "25"]
        #expect(SettingsStore(defaults: defaults).powerSnapshot == ["hibernatemode": "25"])
        store.powerSnapshot = nil
        #expect(SettingsStore(defaults: defaults).powerSnapshot == nil)
    }

    @Test func powerTogglesNotifyExceptSnapshot() {
        let store = SettingsStore(defaults: freshDefaults())
        var count = 0
        store.onChange = { _ in count += 1 }
        store.keepDisplayAwake = true       // notify
        store.batteryFloorPercent = 30      // notify
        store.deepSleepOnBattery = true     // notify
        store.powerSnapshot = ["a": "b"]    // bookkeeping only — no notify
        #expect(count == 3)
    }

    @Test func powerSettingSameValueDoesNotNotify() {
        let store = SettingsStore(defaults: freshDefaults())
        var count = 0
        store.onChange = { _ in count += 1 }
        store.keepDisplayAwake = false      // already false
        store.batteryFloorPercent = 20      // already 20
        store.deepSleepOnBattery = false    // already false
        #expect(count == 0)
    }
}
