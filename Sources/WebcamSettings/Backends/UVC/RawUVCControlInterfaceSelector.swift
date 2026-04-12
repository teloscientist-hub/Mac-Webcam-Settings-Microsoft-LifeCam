import Foundation

enum RawUVCControlInterfaceSelector {
    private static let videoInterfaceClass: UInt8 = 0x0E
    private static let videoControlSubClass: UInt8 = 0x01

    static func select(from interfaces: [RawUVCEnumeratedInterface]) -> RawUVCEnumeratedInterface? {
        interfaces
            .filter { $0.interfaceClass == videoInterfaceClass && $0.interfaceSubClass == videoControlSubClass }
            .sorted { lhs, rhs in
                if lhs.interfaceNumber == rhs.interfaceNumber {
                    return lhs.alternateSetting < rhs.alternateSetting
                }
                return lhs.interfaceNumber < rhs.interfaceNumber
            }
            .first
    }
}
