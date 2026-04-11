import Foundation

protocol ProfileApplying: Sendable {
    func apply(profile: CameraProfile, to device: CameraDeviceDescriptor) async -> ProfileApplyResult
}

struct ProfileApplyResult: Sendable {
    struct ItemResult: Identifiable, Sendable {
        let key: CameraControlKey
        let status: Status
        let message: String

        var id: CameraControlKey { key }
    }

    enum Status: Sendable {
        case applied
        case skippedUnsupported
        case failed
    }

    let items: [ItemResult]

    var succeededCount: Int {
        items.filter { $0.status == .applied }.count
    }

    var skippedCount: Int {
        items.filter { $0.status == .skippedUnsupported }.count
    }
}
