import Foundation

@available(iOS 17.2, *)
internal final class InstallationIDStore {
    
    static let shared = InstallationIDStore()
    
    private static let storageKey = "PPGInstallationId"
    private static let legacyStorageKey = "PPGLiveActivities_InstallationID"
    private var defaults: UserDefaults = .standard
    
    private init() {}

    func configure(appGroupId: String) {
        guard !appGroupId.isEmpty,
              let sharedDefaults = UserDefaults(suiteName: appGroupId) else {
            defaults = .standard
            return
        }

        defaults = sharedDefaults
    }
    
    var installationId: String {
        if let legacy = UserDefaults.standard.string(forKey: Self.legacyStorageKey),
              !legacy.isEmpty {

            if defaults.string(forKey: Self.storageKey) == nil {
                defaults.set(legacy, forKey: Self.storageKey)
            }

            UserDefaults.standard.removeObject(forKey: Self.legacyStorageKey)
        }

        if let existing = defaults.string(forKey: Self.storageKey),
           !existing.isEmpty {
            return existing
        }

        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: Self.storageKey)

        LiveActivityLogger.shared.debug("Generated installationId: \(fresh)")

        return fresh
    }
}
