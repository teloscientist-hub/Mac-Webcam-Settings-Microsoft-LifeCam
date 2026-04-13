import SwiftUI

struct MainWindowView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 14) {
            header

            if let compatibilityNotice = viewModel.compatibilityNotice {
                compatibilityBanner(compatibilityNotice)
            }

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
                    ownershipSummary: viewModel.debugOwnershipSummary,
                    compatibilitySummary: viewModel.debugCompatibilitySummary,
                    capabilities: viewModel.visibleCapabilities,
                    currentValues: viewModel.currentValues,
                    entries: viewModel.debugEntries
                )
            }
        }
        .padding(20)
        .frame(minWidth: 980, minHeight: 650)
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
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                headerTitle
                Spacer(minLength: 12)
                headerControls
            }

            VStack(alignment: .leading, spacing: 12) {
                headerTitle
                headerControls
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Webcam Settings")
                .font(.title.bold())
            Text("Capability-driven control and preview for UVC webcams")
                .foregroundStyle(.secondary)
        }
    }

    private var headerControls: some View {
        HStack(spacing: 10) {
            Picker("Camera", selection: Binding(
                get: { viewModel.selectedDeviceID ?? "" },
                set: { viewModel.selectDevice(id: $0) }
            )) {
                ForEach(viewModel.availableDevices) { device in
                    Text(device.name).tag(device.id)
                }
            }
            .frame(minWidth: 220, idealWidth: 280, maxWidth: 320)

            ConnectionBadge(state: viewModel.connectionState)

            Button("Refresh") {
                viewModel.refreshAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isRefreshingSelection)
        }
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.headline)

            ZStack {
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
                        capabilities: viewModel.visibleCapabilities,
                        currentValues: viewModel.currentValues,
                        inFlightControls: viewModel.inFlightControls,
                        controlErrorMessages: viewModel.controlErrorMessages
                    ) { key, value in
                        viewModel.writeControl(value, key: key)
                    }
                case .advanced:
                    AdvancedTabView(
                        capabilities: viewModel.visibleCapabilities,
                        currentValues: viewModel.currentValues,
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

    private func compatibilityBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wrench.and.screwdriver")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
    }
}
