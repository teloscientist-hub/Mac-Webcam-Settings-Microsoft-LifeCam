import Foundation

actor ProfileService: ProfileServicing {
    private let store: JSONProfileStore
    private let logger: AppLogger
    private let debugStore: DebugStore

    init(store: JSONProfileStore, logger: AppLogger, debugStore: DebugStore) {
        self.store = store
        self.logger = logger
        self.debugStore = debugStore
    }

    func listProfiles() async throws -> [CameraProfile] {
        let profiles = try await store.loadProfiles()
        await debugStore.record(category: "profiles", message: "Loaded \(profiles.count) profiles")
        return profiles
    }

    func saveProfile(_ profile: CameraProfile) async throws {
        var profiles = try await store.loadProfiles()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        try await store.saveProfiles(profiles)
        logger.info("Saved profile \(profile.name)")
        await debugStore.record(category: "profiles", message: "Saved profile \(profile.name)")
    }

    func deleteProfile(id: UUID) async throws {
        let filtered = try await store.loadProfiles().filter { $0.id != id }
        try await store.saveProfiles(filtered)
        logger.info("Deleted profile \(id.uuidString)")
        await debugStore.record(category: "profiles", message: "Deleted profile \(id.uuidString)")
    }
}
