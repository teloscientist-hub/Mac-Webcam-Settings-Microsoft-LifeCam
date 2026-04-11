import Foundation

struct ProfileDeviceMatch: Codable, Hashable, Sendable {
    let deviceName: String
    let deviceIdentifier: String?
    let manufacturer: String?
    let model: String?

    static func from(device: CameraDeviceDescriptor) -> ProfileDeviceMatch {
        ProfileDeviceMatch(
            deviceName: device.name,
            deviceIdentifier: device.backendIdentifier ?? device.avFoundationUniqueID,
            manufacturer: device.manufacturer,
            model: device.model
        )
    }
}
