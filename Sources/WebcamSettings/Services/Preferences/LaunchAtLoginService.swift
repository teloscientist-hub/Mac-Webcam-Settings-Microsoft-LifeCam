import Foundation

#if canImport(ServiceManagement)
import ServiceManagement
#endif

@MainActor
final class LaunchAtLoginService: LaunchAtLoginServicing {
    private let logger: AppLogger
    private let debugStore: DebugStore

    init(logger: AppLogger, debugStore: DebugStore) {
        self.logger = logger
        self.debugStore = debugStore
    }

    func isEnabled() -> Bool {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        #endif
        return false
    }

    func setEnabled(_ isEnabled: Bool) throws {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            do {
                if isEnabled {
                    try SMAppService.mainApp.register()
                    logger.info("Registered launch at login")
                    Task { debugStore.record(category: "preferences", message: "Registered launch at login") }
                } else {
                    try SMAppService.mainApp.unregister()
                    logger.info("Unregistered launch at login")
                    Task { debugStore.record(category: "preferences", message: "Unregistered launch at login") }
                }
                return
            } catch {
                logger.error("Launch-at-login update failed: \(error.localizedDescription)")
                Task { debugStore.record(category: "preferences", message: "Launch-at-login update failed: \(error.localizedDescription)") }
                throw error
            }
        }
        #endif

        let error = NSError(
            domain: "WebcamSettings.LaunchAtLogin",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Launch at login is unavailable in this build."]
        )
        logger.error(error.localizedDescription)
        Task { debugStore.record(category: "preferences", message: error.localizedDescription) }
        throw error
    }
}
