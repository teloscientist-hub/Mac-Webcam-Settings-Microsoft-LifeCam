import SwiftUI

struct PreferencesTabView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    let onSave: () -> Void

    var body: some View {
        Form {
            Toggle("Load selected profile at startup", isOn: binding(\.loadSelectedProfileAtStartup))
            Toggle("Auto-reapply on reconnect", isOn: binding(\.autoReapplyOnReconnect))
            Toggle("Auto-reapply after wake", isOn: binding(\.autoReapplyAfterWake))
            Toggle("Show unsupported controls", isOn: binding(\.showUnsupportedControls))
            Toggle("Show debug panel", isOn: binding(\.showDebugPanel))
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.preferences) { _, _ in
            onSave()
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.preferences[keyPath: keyPath] },
            set: { viewModel.preferences[keyPath: keyPath] = $0 }
        )
    }
}
