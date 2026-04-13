import Foundation

@MainActor
protocol LaunchAtLoginServicing: Sendable {
    func isEnabled() -> Bool
    func setEnabled(_ isEnabled: Bool) throws
}
