import Foundation

protocol PreferencesServicing: Sendable {
    func loadPreferences() async -> AppPreferences
    func savePreferences(_ preferences: AppPreferences) async
}

struct AppPreferences: Codable, Equatable, Sendable {
    var loadSelectedProfileAtStartup: Bool = false
    var startupProfileID: UUID?
    var autoReapplyOnReconnect: Bool = true
    var autoReapplyAfterWake: Bool = true
    var controlTestMode: Bool = false
    var showUnsupportedControls: Bool = false
    var showDebugPanel: Bool = true
}
