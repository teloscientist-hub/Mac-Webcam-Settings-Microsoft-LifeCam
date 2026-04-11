import Foundation
import Testing
@testable import WebcamSettings

actor MockCameraControlService: CameraControlServicing {
    private(set) var writeCalls: [(CameraControlKey, CameraControlValue)] = []
    var refreshedValues: [CameraControlKey: CameraControlValue] = [:]

    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [CameraControlCapability] {
        _ = device
        return []
    }

    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        _ = device
        return refreshedValues
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        _ = device
        writeCalls.append((key, value))
    }

    func refreshCurrentState(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        _ = device
        return refreshedValues
    }
}

@Test
func writeCoordinatorRejectsOutOfRangeIntegerValues() async {
    let service = MockCameraControlService()
    let coordinator = ControlWriteCoordinator(
        controlService: service,
        logger: AppLogger(subsystem: "Tests", category: "write"),
        debugStore: await MainActor.run { DebugStore() }
    )
    let capability = CameraControlCapability(
        key: .brightness,
        displayName: "Brightness",
        type: .integerRange,
        isSupported: true,
        isReadable: true,
        isWritable: true,
        minValue: .int(0),
        maxValue: .int(100),
        stepValue: .int(1),
        defaultValue: .int(50),
        currentValue: .int(50),
        enumOptions: [],
        dependency: nil
    )

    let result = await coordinator.write(
        .int(101),
        key: .brightness,
        capability: capability,
        device: makeDevice()
    )

    switch result {
    case .success:
        Issue.record("Expected validation failure")
    case let .failure(error):
        #expect(error == .invalidValue(.brightness))
    }
}

@Test
func writeCoordinatorRejectsUnknownEnumOptions() async {
    let service = MockCameraControlService()
    let coordinator = ControlWriteCoordinator(
        controlService: service,
        logger: AppLogger(subsystem: "Tests", category: "write"),
        debugStore: await MainActor.run { DebugStore() }
    )
    let capability = CameraControlCapability(
        key: .powerLineFrequency,
        displayName: "Power Line Frequency",
        type: .enumSelection,
        isSupported: true,
        isReadable: true,
        isWritable: true,
        minValue: nil,
        maxValue: nil,
        stepValue: nil,
        defaultValue: .enumCase("auto"),
        currentValue: .enumCase("auto"),
        enumOptions: [
            .init(id: "50hz", title: "50 Hz", value: "50hz"),
            .init(id: "60hz", title: "60 Hz", value: "60hz")
        ],
        dependency: nil
    )

    let result = await coordinator.write(
        .enumCase("invalid"),
        key: .powerLineFrequency,
        capability: capability,
        device: makeDevice()
    )

    switch result {
    case .success:
        Issue.record("Expected validation failure")
    case let .failure(error):
        #expect(error == .invalidValue(.powerLineFrequency))
    }
}

@Test
func writeCoordinatorReturnsRefreshedValuesOnSuccess() async throws {
    let service = MockCameraControlService()
    await service.setRefreshedValues([.brightness: .int(42)])
    let coordinator = ControlWriteCoordinator(
        controlService: service,
        logger: AppLogger(subsystem: "Tests", category: "write"),
        debugStore: await MainActor.run { DebugStore() }
    )
    let capability = CameraControlCapability(
        key: .brightness,
        displayName: "Brightness",
        type: .integerRange,
        isSupported: true,
        isReadable: true,
        isWritable: true,
        minValue: .int(0),
        maxValue: .int(100),
        stepValue: .int(1),
        defaultValue: .int(50),
        currentValue: .int(50),
        enumOptions: [],
        dependency: nil
    )

    let result = await coordinator.write(
        .int(42),
        key: .brightness,
        capability: capability,
        device: makeDevice()
    )

    switch result {
    case let .success(writeResult):
        #expect(writeResult.refreshedValues?[.brightness] == .int(42))
    case let .failure(error):
        Issue.record("Expected success, got \(error)")
    }
}

private func makeDevice() -> CameraDeviceDescriptor {
    CameraDeviceDescriptor(
        id: "camera-1",
        name: "LifeCam Studio",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123",
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "avf-1",
        backendIdentifier: "backend-1"
    )
}

private extension MockCameraControlService {
    func setRefreshedValues(_ values: [CameraControlKey: CameraControlValue]) {
        self.refreshedValues = values
    }
}
