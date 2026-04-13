import Foundation

actor ControlWriteCoordinator {
    struct WriteResult: Sendable {
        let refreshedValues: [CameraControlKey: CameraControlValue]?
    }

    private let controlService: any CameraControlServicing
    private let logger: AppLogger
    private let debugStore: DebugStore

    init(controlService: any CameraControlServicing, logger: AppLogger, debugStore: DebugStore) {
        self.controlService = controlService
        self.logger = logger
        self.debugStore = debugStore
    }

    func write(
        _ value: CameraControlValue,
        key: CameraControlKey,
        capability: CameraControlCapability?,
        device: CameraDeviceDescriptor
    ) async -> Result<WriteResult, CameraControlError> {
        do {
            try validate(value: value, for: key, capability: capability)
            try await controlService.writeValue(value, for: key, device: device)
            let refreshedValues: [CameraControlKey: CameraControlValue]?
            if RawUVCBindings.canAttemptDirectAccess(for: device) {
                refreshedValues = nil
            } else {
                refreshedValues = try? await controlService.refreshCurrentState(for: device)
            }
            logger.info("Wrote control \(key.rawValue)")
            await debugStore.record(category: "write", message: "Wrote control \(key.rawValue)")
            return .success(WriteResult(refreshedValues: refreshedValues))
        } catch let error as CameraControlError {
            logger.error("Write failed for \(key.rawValue): \(error.localizedDescription)")
            await debugStore.record(category: "write", message: "Write failed for \(key.rawValue): \(error.localizedDescription)")
            return .failure(error)
        } catch {
            logger.error("Write failed for \(key.rawValue): \(error.localizedDescription)")
            await debugStore.record(category: "write", message: "Write failed for \(key.rawValue): \(error.localizedDescription)")
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    private func validate(value: CameraControlValue, for key: CameraControlKey, capability: CameraControlCapability?) throws {
        guard let capability else { return }

        if capability.isSupported == false || capability.isWritable == false {
            throw CameraControlError.controlUnsupported(key)
        }

        switch capability.type {
        case .boolean:
            guard case .bool = value else { throw CameraControlError.invalidValue(key) }
        case .enumSelection:
            guard case let .enumCase(rawValue) = value else {
                throw CameraControlError.invalidValue(key)
            }
            if capability.enumOptions.isEmpty == false && capability.enumOptions.contains(where: { $0.value == rawValue }) == false {
                throw CameraControlError.invalidValue(key)
            }
        case .integerRange:
            let resolved: Double
            switch value {
            case let .int(intValue):
                resolved = Double(intValue)
            case let .double(doubleValue):
                resolved = doubleValue
            default:
                throw CameraControlError.invalidValue(key)
            }
            try validateNumeric(resolved, key: key, capability: capability)
        case .floatRange:
            let resolved: Double
            switch value {
            case let .int(intValue):
                resolved = Double(intValue)
            case let .double(doubleValue):
                resolved = doubleValue
            default:
                throw CameraControlError.invalidValue(key)
            }
            try validateNumeric(resolved, key: key, capability: capability)
        }
    }

    private func validateNumeric(_ value: Double, key: CameraControlKey, capability: CameraControlCapability) throws {
        let minValue = numericValue(from: capability.minValue) ?? value
        let maxValue = numericValue(from: capability.maxValue) ?? value
        guard value >= minValue && value <= maxValue else {
            throw CameraControlError.invalidValue(key)
        }
    }

    private func numericValue(from value: CameraControlValue?) -> Double? {
        switch value {
        case let .int(intValue):
            Double(intValue)
        case let .double(doubleValue):
            doubleValue
        default:
            nil
        }
    }
}
