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

    @Test func defaultsAreEnabled() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.gesturesEnabled)
        #expect(store.hotkeysEnabled)
    }

    @Test func togglesPersistAcrossInstances() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.gesturesEnabled = false
        store.hotkeysEnabled = false

        let reloaded = SettingsStore(defaults: defaults)
        #expect(!reloaded.gesturesEnabled)
        #expect(!reloaded.hotkeysEnabled)

        reloaded.hotkeysEnabled = true
        let third = SettingsStore(defaults: defaults)
        #expect(!third.gesturesEnabled)
        #expect(third.hotkeysEnabled)
    }

    @Test func changesNotifyObserver() {
        let store = SettingsStore(defaults: freshDefaults())
        var events: [String] = []
        store.onChange = { events.append("\($0.gesturesEnabled)/\($0.hotkeysEnabled)") }
        store.gesturesEnabled = false
        store.hotkeysEnabled = false
        store.hotkeysEnabled = true
        #expect(events == ["false/true", "false/false", "false/true"])
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
}
