import Foundation

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var preferences = AppPreferences()
}
