import Foundation

protocol ProfileStore: Sendable {
    func loadProfiles() async throws -> [CameraProfile]
    func saveProfiles(_ profiles: [CameraProfile]) async throws
}
