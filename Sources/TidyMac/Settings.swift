// TidyMac — by M.Alshmmari
//
// Everything TidyMac remembers between launches, in one place.

import Foundation

enum Settings {
    private static let store = UserDefaults.standard

    static var isPaused: Bool {
        get { store.bool(forKey: "isPaused") }
        set { store.set(newValue, forKey: "isPaused") }
    }

    static var screenshotsToFolder: Bool {
        get { store.object(forKey: "screenshotsToFolder") as? Bool ?? true }
        set { store.set(newValue, forKey: "screenshotsToFolder") }
    }

    /// "en" or "ar". English unless the user picks Arabic in Settings.
    static var language: String {
        get { store.string(forKey: "language") ?? "en" }
        set { store.set(newValue, forKey: "language") }
    }

    /// True only on the very first launch, so first-run setup happens once.
    static func isFirstLaunch() -> Bool {
        guard !store.bool(forKey: "hasLaunched") else { return false }
        store.set(true, forKey: "hasLaunched")
        return true
    }
}
