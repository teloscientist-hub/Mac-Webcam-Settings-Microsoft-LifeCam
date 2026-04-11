import SwiftUI

struct MainWindowView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 16) {
            header

            TabView(selection: $viewModel.selectedTab) {
                BasicTabView(viewModel: viewModel.basicTabViewModel) { key, value in
                    viewModel.writeControl(value, key: key)
                }
                .tabItem { Text("Basic") }
                .tag(AppViewModel.Tab.basic)

                AdvancedTabView(viewModel: viewModel.advancedTabViewModel) { key, value in
                    viewModel.writeControl(value, key: key)
                }
                .tabItem { Text("Advanced") }
                .tag(AppViewModel.Tab.advanced)

                PreferencesTabView(viewModel: viewModel.preferencesViewModel) {
                    viewModel.savePreferences()
                }
                .tabItem { Text("Preferences") }
                .tag(AppViewModel.Tab.preferences)
            }

            ProfileManagerBar(profiles: viewModel.profiles)

            StatusBanner(
                message: viewModel.statusMessage,
                errorMessage: viewModel.lastErrorMessage
            )

            if viewModel.preferences.showDebugPanel {
                DebugPanel(entries: viewModel.debugEntries)
            }
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 650)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Webcam Settings")
                    .font(.title.bold())
                Text("Capability-driven LifeCam Studio replacement")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Camera", selection: Binding(
                get: { viewModel.selectedDeviceID ?? "" },
                set: { viewModel.selectDevice(id: $0) }
            )) {
                ForEach(viewModel.availableDevices) { device in
                    Text(device.name).tag(device.id)
                }
            }
            .frame(width: 280)
        }
    }
}
