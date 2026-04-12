import Foundation

enum RawUVCControlTransfer {
    enum Direction: String, Sendable, Equatable {
        case deviceToHost
        case hostToDevice
    }

    struct Plan: Sendable, Equatable {
        let target: RawUVCTransportTarget
        let requestPlan: RawUVCBindings.RequestPlan
        let direction: Direction
        let request: UInt8
        let requestType: UInt8
        let value: UInt16
        let index: UInt16
        let expectedLength: Int

        var summary: String {
            "\(direction.rawValue) req=0x\(String(format: "%02X", request)) type=0x\(String(format: "%02X", requestType)) value=0x\(String(format: "%04X", value)) index=0x\(String(format: "%04X", index)) len=\(expectedLength) target=[\(target.summary)]"
        }

        func index(forControlInterfaceNumber interfaceNumber: UInt8) -> UInt16 {
            UInt16(interfaceNumber) << 8 | (index & 0x00FF)
        }
    }

    static func plan(
        for requestPlan: RawUVCBindings.RequestPlan,
        target: RawUVCTransportTarget
    ) -> Plan {
        let request: UInt8
        let requestType: UInt8
        let direction: Direction

        switch requestPlan.operation {
        case .getCurrent:
            request = 0x81
            requestType = 0xA1
            direction = .deviceToHost
        case .setCurrent:
            request = 0x01
            requestType = 0x21
            direction = .hostToDevice
        }

        let value = UInt16(requestPlan.selector) << 8
        let index = UInt16(requestPlan.unitID)

        return Plan(
            target: target,
            requestPlan: requestPlan,
            direction: direction,
            request: request,
            requestType: requestType,
            value: value,
            index: index,
            expectedLength: requestPlan.expectedLength
        )
    }
}
