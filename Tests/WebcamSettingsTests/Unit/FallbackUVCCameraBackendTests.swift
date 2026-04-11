import Foundation
import Testing
@testable import WebcamSettings

private actor RecordingBackend: UVCCameraBackend {
    enum Mode {
        case fail
        case succeed
    }

    let mode: Mode
    private(set) var fetchCount = 0
    private(set) var readCount = 0
    private(set) var writeCount = 0

    init(mode: Mode) {
        self.mode = mode
    }

    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [BackendControlCapability] {
        _ = device
        fetchCount += 1
        guard mode == .succeed else {
            throw CameraControlError.backendFailure("preferred fetch failed")
        }
        return []
    }

    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey : CameraControlValue] {
        _ = device
        readCount += 1
        guard mode == .succeed else {
            throw CameraControlError.backendFailure("preferred read failed")
        }
        return [.brightness: .int(42)]
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        _ = value
        _ = key
        _ = device
        writeCount += 1
        guard mode == .succeed else {
            throw CameraControlError.backendFailure("preferred write failed")
        }
    }
}

@Test
func fallbackBackendUsesFallbackWhenPreferredFetchFails() async throws {
    let preferred = RecordingBackend(mode: .fail)
    let fallback = RecordingBackend(mode: .succeed)
    let backend = FallbackUVCCameraBackend(preferred: preferred, fallback: fallback)

    _ = try await backend.fetchCapabilities(for: makeFallbackDevice())

    let preferredFetches = await preferred.fetchCount
    let fallbackFetches = await fallback.fetchCount
    #expect(preferredFetches == 1)
    #expect(fallbackFetches == 1)
}

@Test
func fallbackBackendUsesFallbackWhenPreferredReadFails() async throws {
    let preferred = RecordingBackend(mode: .fail)
    let fallback = RecordingBackend(mode: .succeed)
    let backend = FallbackUVCCameraBackend(preferred: preferred, fallback: fallback)

    let values = try await backend.readCurrentValues(for: makeFallbackDevice())

    #expect(values[.brightness] == .int(42))
    let preferredReads = await preferred.readCount
    let fallbackReads = await fallback.readCount
    #expect(preferredReads == 1)
    #expect(fallbackReads == 1)
}

@Test
func fallbackBackendUsesFallbackWhenPreferredWriteFails() async throws {
    let preferred = RecordingBackend(mode: .fail)
    let fallback = RecordingBackend(mode: .succeed)
    let backend = FallbackUVCCameraBackend(preferred: preferred, fallback: fallback)

    try await backend.writeValue(.int(55), for: .brightness, device: makeFallbackDevice())

    let preferredWrites = await preferred.writeCount
    let fallbackWrites = await fallback.writeCount
    #expect(preferredWrites == 1)
    #expect(fallbackWrites == 1)
}

private func makeFallbackDevice() -> CameraDeviceDescriptor {
    CameraDeviceDescriptor(
        id: "fallback-cam-1",
        name: "Microsoft LifeCam Studio",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123",
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "avf-fallback-1",
        backendIdentifier: "backend-fallback-1"
    )
}
