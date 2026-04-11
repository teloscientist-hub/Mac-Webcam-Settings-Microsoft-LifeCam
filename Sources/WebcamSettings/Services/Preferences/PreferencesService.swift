import Foundation

actor PreferencesService: PreferencesServicing {
    private let logger: AppLogger
    private let debugStore: DebugStore
    private let defaults = UserDefaults.standard
    private let key = "WebcamSettings.AppPreferences"

    init(logger: AppLogger, debugStore: DebugStore) {
        self.logger = logger
        self.debugStore = debugStore
    }

    func loadPreferences() async -> AppPreferences {
        guard
            let data = defaults.data(forKey: key),
            let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data)
        else {
            return AppPreferences()
        }

        await debugStore.record(category: "preferences", message: "Loaded app preferences")
        return preferences
    }

    func savePreferences(_ preferences: AppPreferences) async {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: key)
        }
        logger.info("Saved app preferences")
        await debugStore.record(category: "preferences", message: "Saved app preferences")
    }
}
