import Foundation

struct ProfileDeviceMatch: Codable, Hashable, Sendable {
    let deviceName: String
    let deviceIdentifier: String?
    let manufacturer: String?
    let model: String?
    let vendorID: Int?
    let productID: Int?
    let serialNumber: String?

    static func from(device: CameraDeviceDescriptor) -> ProfileDeviceMatch {
        ProfileDeviceMatch(
            deviceName: device.name,
            deviceIdentifier: device.backendIdentifier ?? device.avFoundationUniqueID,
            manufacturer: device.manufacturer,
            model: device.model,
            vendorID: device.vendorID,
            productID: device.productID,
            serialNumber: device.serialNumber
        )
    }

    func matches(_ device: CameraDeviceDescriptor) -> Bool {
        device.matchScore(for: self) > 0
    }
}
