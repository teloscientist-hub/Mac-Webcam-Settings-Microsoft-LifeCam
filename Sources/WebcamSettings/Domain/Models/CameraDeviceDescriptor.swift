import Foundation

struct CameraDeviceDescriptor: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let manufacturer: String?
    let model: String?
    let vendorID: Int?
    let productID: Int?
    let serialNumber: String?
    let transportType: CameraTransportType
    let isConnected: Bool
    let avFoundationUniqueID: String?
    let backendIdentifier: String?

    func matchScore(for match: ProfileDeviceMatch) -> Int {
        var score = 0

        if let deviceIdentifier = match.deviceIdentifier,
           deviceIdentifier == backendIdentifier || deviceIdentifier == avFoundationUniqueID || deviceIdentifier == id {
            score += 6
        }

        if let model, let matchModel = match.model, model.caseInsensitiveCompare(matchModel) == .orderedSame {
            score += 3
        }

        if let manufacturer, let matchManufacturer = match.manufacturer, manufacturer.caseInsensitiveCompare(matchManufacturer) == .orderedSame {
            score += 2
        }

        if let vendorID, let matchVendorID = match.vendorID, vendorID == matchVendorID {
            score += 3
        }

        if let productID, let matchProductID = match.productID, productID == matchProductID {
            score += 3
        }

        if let serialNumber, let matchSerialNumber = match.serialNumber, serialNumber.caseInsensitiveCompare(matchSerialNumber) == .orderedSame {
            score += 4
        }

        if name.caseInsensitiveCompare(match.deviceName) == .orderedSame {
            score += 1
        }

        return score
    }

    var usbIdentitySummary: String? {
        guard vendorID != nil || productID != nil else {
            return nil
        }

        let vendor = vendorID.map { String(format: "0x%04X", $0) } ?? "n/a"
        let product = productID.map { String(format: "0x%04X", $0) } ?? "n/a"
        return "VID \(vendor) • PID \(product)"
    }
}

enum CameraTransportType: String, Codable, CaseIterable, Sendable {
    case builtIn
    case usb
    case virtual
    case continuity
    case unknown
}
