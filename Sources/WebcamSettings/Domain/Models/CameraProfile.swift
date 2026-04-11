import Foundation

struct CameraProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var deviceMatch: ProfileDeviceMatch
    var values: [CameraControlKey: CameraControlValue]
    let createdAt: Date
    var updatedAt: Date
    var loadAtStart: Bool

    init(
        id: UUID = UUID(),
        name: String,
        deviceMatch: ProfileDeviceMatch,
        values: [CameraControlKey: CameraControlValue],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        loadAtStart: Bool = false
    ) {
        self.id = id
        self.name = name
        self.deviceMatch = deviceMatch
        self.values = values
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.loadAtStart = loadAtStart
    }
}
