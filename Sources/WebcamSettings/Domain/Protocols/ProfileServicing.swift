import Foundation

protocol ProfileServicing: Sendable {
    func listProfiles() async throws -> [CameraProfile]
    func saveProfile(_ profile: CameraProfile) async throws
    func deleteProfile(id: UUID) async throws
}
