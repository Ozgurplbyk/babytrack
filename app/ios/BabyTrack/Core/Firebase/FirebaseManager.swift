import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

final class FirebaseManager {
    static let shared = FirebaseManager()
    private init() {}

    func configureIfNeeded() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }
}
