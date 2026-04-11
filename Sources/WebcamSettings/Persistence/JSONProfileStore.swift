import Foundation

actor JSONProfileStore: ProfileStore {
    private let logger: AppLogger
    private let debugStore: DebugStore
    private let profilesURL: URL

    init(logger: AppLogger, debugStore: DebugStore) {
        self.logger = logger
        self.debugStore = debugStore
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.profilesURL = baseURL.appendingPathComponent("WebcamSettings/profiles.json")
    }

    func loadProfiles() async throws -> [CameraProfile] {
        guard FileManager.default.fileExists(atPath: profilesURL.path) else {
            return []
        }
        let data = try Data(contentsOf: profilesURL)
        return try JSONDecoder().decode([CameraProfile].self, from: data)
    }

    func saveProfiles(_ profiles: [CameraProfile]) async throws {
        let directory = profilesURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(profiles)
        try data.write(to: profilesURL, options: .atomic)
        logger.info("Persisted \(profiles.count) profile(s)")
        await debugStore.record(category: "profiles", message: "Persisted \(profiles.count) profile(s)")
    }
}
