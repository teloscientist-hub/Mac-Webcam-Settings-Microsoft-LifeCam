import Foundation

struct CameraDeviceDescriptor: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let manufacturer: String?
    let model: String?
    let transportType: CameraTransportType
    let isConnected: Bool
    let avFoundationUniqueID: String?
    let backendIdentifier: String?
}

enum CameraTransportType: String, Codable, CaseIterable, Sendable {
    case builtIn
    case usb
    case virtual
    case continuity
    case unknown
}
