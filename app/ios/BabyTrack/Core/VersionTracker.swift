import Foundation

struct VersionTracker {
    private let key = "last.seen.app.version"

    func shouldShowWhatsNew(for currentVersion: String) -> Bool {
        let last = UserDefaults.standard.string(forKey: key)
        return last != currentVersion
    }

    func markShown(version: String) {
        UserDefaults.standard.set(version, forKey: key)
    }
}
