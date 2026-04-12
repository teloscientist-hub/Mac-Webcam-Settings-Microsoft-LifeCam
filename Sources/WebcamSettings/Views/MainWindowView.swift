import SwiftUI

struct MainWindowView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 14) {
            header

            HStack(alignment: .top, spacing: 16) {
                previewColumn
                controlsColumn
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            ProfileManagerBar(
                profiles: viewModel.displayedProfiles,
                selectedProfileID: Binding(
                    get: { viewModel.selectedProfileID },
                    set: { viewModel.selectProfile(id: $0) }
                ),
                draftName: $viewModel.profileDraftName,
                loadAtStart: Binding(
                    get: { viewModel.selectedProfile?.loadAtStart ?? false },
                    set: { viewModel.toggleLoadAtStart($0) }
                ),
                matchDescription: viewModel.selectedProfileMatchDescription,
                canUpdate: viewModel.canUpdateSelectedProfile,
                canLoad: viewModel.canLoadSelectedProfile,
                onSaveNew: { viewModel.saveNewProfile() },
                onUpdate: { viewModel.updateSelectedProfile() },
                onLoad: { viewModel.loadSelectedProfile() },
                onDelete: { viewModel.requestDeleteSelectedProfile() }
            )

            StatusBanner(
                message: viewModel.statusMessage,
                errorMessage: viewModel.lastErrorMessage
            )

            if viewModel.preferences.showDebugPanel {
                DebugPanel(
                    selectedDevice: viewModel.selectedDevice,
                    connectionState: viewModel.connectionState,
                    previewSummary: viewModel.debugPreviewSummary,
                    controlsSummary: viewModel.debugControlsSummary,
                    backendSummary: viewModel.debugBackendSummary,
                    capabilitySourceSummary: viewModel.debugCapabilitySourceSummary,
                    rawMappingSummary: viewModel.debugRawMappingSummary,
                    pipelineSummary: viewModel.debugPipelineSummary,
                    rawTargetSummary: viewModel.debugRawTargetSummary,
                    capabilities: viewModel.visibleCapabilities,
                    currentValues: viewModel.currentValues,
                    entries: viewModel.debugEntries
                )
            }
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 650)
        .confirmationDialog(
            "Delete selected profile?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Profile", role: .destructive) {
                viewModel.confirmDeleteSelectedProfile()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved profile but does not change the camera's current settings.")
        }
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

            HStack(spacing: 10) {
                Picker("Camera", selection: Binding(
                    get: { viewModel.selectedDeviceID ?? "" },
                    set: { viewModel.selectDevice(id: $0) }
                )) {
                    ForEach(viewModel.availableDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .frame(width: 280)

                ConnectionBadge(state: viewModel.connectionState)

                Button("Refresh") {
                    viewModel.refreshAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isRefreshingSelection)
            }
        }
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.headline)

            ZStack(alignment: .bottomLeading) {
                PreviewSurfaceView(session: viewModel.previewSession)

                if viewModel.previewSession == nil {
                    VStack(spacing: 8) {
                        Text(viewModel.previewPlaceholderTitle)
                            .font(.headline)
                        Text(viewModel.previewPlaceholderMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if viewModel.shouldOfferOpenCameraSettings {
                            Button("Open Camera Settings") {
                                viewModel.openCameraPrivacySettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectedDevice?.name ?? "No camera selected")
                        .font(.subheadline.weight(.medium))
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(12)
            }
            .frame(minHeight: 320)
            .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity)
    }

    private var controlsColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Section", selection: $viewModel.selectedTab) {
                Text("Basic").tag(AppViewModel.Tab.basic)
                Text("Advanced").tag(AppViewModel.Tab.advanced)
                Text("Preferences").tag(AppViewModel.Tab.preferences)
            }
            .pickerStyle(.segmented)

            Group {
                switch viewModel.selectedTab {
                case .basic:
                    BasicTabView(
                        viewModel: viewModel.basicTabViewModel,
                        inFlightControls: viewModel.inFlightControls,
                        controlErrorMessages: viewModel.controlErrorMessages
                    ) { key, value in
                        viewModel.writeControl(value, key: key)
                    }
                case .advanced:
                    AdvancedTabView(
                        viewModel: viewModel.advancedTabViewModel,
                        inFlightControls: viewModel.inFlightControls,
                        controlErrorMessages: viewModel.controlErrorMessages
                    ) { key, value in
                        viewModel.writeControl(value, key: key)
                    }
                case .preferences:
                    PreferencesTabView(viewModel: viewModel.preferencesViewModel) {
                        viewModel.savePreferences()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .disabled(viewModel.selectedDevice == nil && viewModel.selectedTab != .preferences)
        }
        .frame(maxWidth: .infinity)
    }
}
