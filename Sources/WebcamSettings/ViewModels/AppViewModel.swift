import AppKit
import AVFoundation
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    enum ConnectionState {
        case loading
        case connected
        case disconnected
        case deviceBusy
        case partialControlAccess
    }

    enum Tab: String, CaseIterable, Identifiable {
        case basic
        case advanced
        case preferences

        var id: String { rawValue }
    }

    @Published var availableDevices: [CameraDeviceDescriptor] = []
    @Published var selectedDeviceID: String?
    @Published var capabilities: [CameraControlCapability] = []
    @Published var currentValues: [CameraControlKey: CameraControlValue] = [:]
    @Published var profiles: [CameraProfile] = []
    @Published var selectedProfileID: UUID?
    @Published var profileDraftName = ""
    @Published var preferences = AppPreferences()
    @Published var selectedTab: Tab = .basic
    @Published var statusMessage = "Scaffold ready. Select a device to begin."
    @Published var lastErrorMessage: String?
    @Published var previewSession: AVCaptureSession?
    @Published var connectionState: ConnectionState = .loading
    @Published var inFlightControls: Set<CameraControlKey> = []
    @Published var controlErrorMessages: [CameraControlKey: String] = [:]
    @Published var showDeleteConfirmation = false
    @Published var isRefreshingSelection = false
    @Published private(set) var lastPreviewError: CameraControlError?
    @Published private(set) var lastControlsError: CameraControlError?

    let basicTabViewModel: BasicTabViewModel
    let advancedTabViewModel: AdvancedTabViewModel
    let profilesViewModel = ProfilesViewModel()
    let preferencesViewModel = PreferencesViewModel()

    private let dependencies: AppDependencies
    private var deviceUpdatesTask: Task<Void, Never>?
    private var lifecycleEventsTask: Task<Void, Never>?
    private let writeCoordinator: ControlWriteCoordinator
    private var hasAttemptedStartupProfileLoad = false
    private var lastConnectedDeviceIDs: Set<String> = []

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.writeCoordinator = ControlWriteCoordinator(
            controlService: dependencies.cameraControlService,
            logger: dependencies.logger,
            debugStore: dependencies.debugStore
        )
        self.basicTabViewModel = BasicTabViewModel()
        self.advancedTabViewModel = AdvancedTabViewModel()

        Task {
            await bootstrap()
        }
    }

    var selectedDevice: CameraDeviceDescriptor? {
        availableDevices.first(where: { $0.id == selectedDeviceID })
    }

    var debugEntries: [DebugStore.Entry] {
        dependencies.debugStore.entries
    }

    var selectedProfile: CameraProfile? {
        profiles.first(where: { $0.id == selectedProfileID })
    }

    var visibleCapabilities: [CameraControlCapability] {
        capabilities.sorted { $0.displayName < $1.displayName }
    }

    var debugBackendSummary: String {
        RawUVCBindings.backendSummary(for: selectedDevice)
    }

    var debugPreviewSummary: String {
        if previewSession != nil {
            return "Active"
        }
        if let lastPreviewError {
            return "Failed: \(lastPreviewError.localizedDescription)"
        }
        return "Inactive"
    }

    var debugControlsSummary: String {
        if let lastControlsError {
            return "Limited: \(lastControlsError.localizedDescription)"
        }
        return capabilities.isEmpty ? "No capabilities loaded" : "Loaded \(capabilities.count) capabilities"
    }

    var debugCapabilitySourceSummary: String {
        guard capabilities.isEmpty == false else {
            return "No capability provenance available"
        }

        let rawCount = capabilities.filter { $0.source == .rawCatalog }.count
        let fallbackCount = capabilities.filter { $0.source == .simulatedFallback }.count
        return "\(rawCount) raw-catalog, \(fallbackCount) simulated-fallback"
    }

    var debugRawMappingSummary: String {
        RawUVCBindings.mappingSummary(for: selectedDevice)
    }

    var debugPipelineSummary: String {
        RawUVCBindings.pipelineSummary(for: selectedDevice)
    }

    var debugRawTargetSummary: String {
        RawUVCDeviceLocatorSupport.resolvedTargetSummary(for: selectedDevice)
    }

    var debugOwnershipSummary: String {
        guard let selectedDevice else {
            return "No ownership warning"
        }
        guard selectedDevice.cameraAssistantOwnsControlInterface else {
            return "No camera-assistant ownership detected"
        }
        return "Control interface owner: \(selectedDevice.controlInterfaceOwner ?? "UVCAssistant"). Direct writes are blocked by macOS Camera Assistant on this Tahoe system."
    }

    var selectedProfileMatchDescription: String {
        guard let selectedProfile, let selectedDevice else {
            return "No profile selected"
        }

        let score = selectedDevice.matchScore(for: selectedProfile.deviceMatch)
        switch score {
        case 6...:
            return "Exact device match"
        case 3...5:
            return "Likely device match"
        case 1...2:
            return "Partial device match"
        default:
            return "Different device"
        }
    }

    var canUpdateSelectedProfile: Bool {
        selectedProfile != nil && selectedDevice != nil
    }

    var canLoadSelectedProfile: Bool {
        selectedProfile != nil && selectedDevice != nil
    }

    var shouldOfferOpenCameraSettings: Bool {
        lastPreviewError == .permissionDenied
    }

    var previewPlaceholderTitle: String {
        if lastPreviewError == .permissionDenied {
            return "Camera permission needed"
        }

        if connectionState == .deviceBusy {
            return "Camera busy"
        }

        switch connectionState {
        case .loading:
            return "Loading camera"
        case .connected:
            return "Preview unavailable"
        case .disconnected:
            return "No camera selected"
        case .deviceBusy:
            return "Camera busy"
        case .partialControlAccess:
            return previewSession == nil ? "Preview unavailable" : "Preview active, controls limited"
        }
    }

    var previewPlaceholderMessage: String {
        if lastPreviewError == .permissionDenied {
            return "Grant camera access in System Settings, then refresh the selected camera."
        }

        if connectionState == .deviceBusy {
            return "Another app or process may still be using the selected camera."
        }

        switch connectionState {
        case .loading:
            return "Fetching device details and preparing the preview."
        case .connected:
            return "The camera is selected, but a preview session is not available yet."
        case .disconnected:
            return "Connect a webcam or pick an available device to begin."
        case .deviceBusy:
            return "Another app or process may still be using the selected camera."
        case .partialControlAccess:
            if previewSession == nil {
                return "Preview could not start, but device discovery and control services may still be available."
            }
            return "Some camera features are unavailable right now, but the preview is still active."
        }
    }

    var displayedProfiles: [CameraProfile] {
        profiles.sorted { lhs, rhs in
            let lhsScore = profileMatchScore(lhs)
            let rhsScore = profileMatchScore(rhs)
            if lhsScore == rhsScore {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhsScore > rhsScore
        }
    }

    func bootstrap() async {
        dependencies.logger.info("App bootstrap started")
        await dependencies.lifecycleCoordinator.start()
        await dependencies.deviceDiscoveryService.startMonitoring()
        observeDeviceUpdates()
        observeLifecycleEvents()
        preferences = await dependencies.preferencesService.loadPreferences()
        preferencesViewModel.preferences = preferences
        await refreshDevices()
        await refreshProfiles()
        await attemptStartupProfileLoadIfNeeded()
        dependencies.logger.info("App bootstrap finished")
    }

    func refreshDevices() async {
        let devices = await dependencies.deviceDiscoveryService.currentDevices()
        availableDevices = devices
        lastConnectedDeviceIDs = Set(devices.map(\.id))
        dependencies.logger.info("Refresh devices loaded \(devices.count) entries")
        if selectedDeviceID == nil {
            selectedDeviceID = availableDevices.first?.id
        }
        await loadSelection()
    }

    func refreshProfiles() async {
        do {
            profiles = try await dependencies.profileService.listProfiles()
            profilesViewModel.profiles = profiles
            if let selectedProfileID, profiles.contains(where: { $0.id == selectedProfileID }) == false {
                self.selectedProfileID = nil
            }
            if self.selectedProfileID == nil {
                self.selectedProfileID = displayedProfiles.first?.id
            }
            profileDraftName = selectedProfile?.name ?? profileDraftName
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func selectDevice(id: String) {
        selectedDeviceID = id
        Task {
            await loadSelection()
        }
    }

    func writeControl(_ value: CameraControlValue, key: CameraControlKey) {
        guard let selectedDevice else { return }
        let previousValue = currentValues[key]
        let capability = capabilities.first(where: { $0.key == key })
        currentValues[key] = value
        inFlightControls.insert(key)
        controlErrorMessages[key] = nil

        Task {
            let result = await writeCoordinator.write(value, key: key, capability: capability, device: selectedDevice)

            await MainActor.run {
                self.inFlightControls.remove(key)
                switch result {
                case let .success(writeResult):
                    if let refreshedValues = writeResult.refreshedValues {
                        self.currentValues = self.mergedCurrentValues(
                            existing: self.currentValues,
                            refreshed: refreshedValues,
                            capabilities: self.capabilities,
                            lastWrittenKey: key,
                            lastWrittenValue: value
                        )
                    }
                    self.controlErrorMessages[key] = nil
                    self.lastErrorMessage = nil
                    self.statusMessage = "Updated \(key.displayName)"
                    self.syncTabViewModels()
                case let .failure(error):
                    if let previousValue {
                        self.currentValues[key] = previousValue
                    } else {
                        self.currentValues.removeValue(forKey: key)
                    }
                    let renderedError = self.renderedControlWriteError(error, key: key, device: selectedDevice)
                    self.controlErrorMessages[key] = renderedError
                    self.lastErrorMessage = renderedError
                    self.statusMessage = self.renderedControlWriteStatus(error, key: key, device: selectedDevice)
                    self.syncTabViewModels()
                }
            }
        }
    }

    private func renderedControlWriteError(
        _ error: CameraControlError,
        key: CameraControlKey,
        device: CameraDeviceDescriptor
    ) -> String {
        if isTahoeCameraAssistantOwnershipFailure(error, device: device) {
            return "macOS Tahoe is currently holding the \(device.name) UVC control interface through Camera Assistant, so direct \(key.displayName) writes are blocked."
        }
        return error.localizedDescription
    }

    private func renderedControlWriteStatus(
        _ error: CameraControlError,
        key: CameraControlKey,
        device: CameraDeviceDescriptor
    ) -> String {
        if isTahoeCameraAssistantOwnershipFailure(error, device: device) {
            return "\(key.displayName) is blocked by macOS Camera Assistant ownership"
        }
        return "Failed to update \(key.displayName)"
    }

    private func isTahoeCameraAssistantOwnershipFailure(
        _ error: CameraControlError,
        device: CameraDeviceDescriptor
    ) -> Bool {
        guard RawUVCBindings.canAttemptDirectAccess(for: device) else {
            return false
        }

        switch error {
        case .deviceBusy:
            return true
        case let .backendFailure(message):
            let normalized = message.lowercased()
            return normalized.contains("uvcassistant")
                || normalized.contains("camera assistant")
                || normalized.contains("uvcservice")
                || normalized.contains("0xe00002c5")
                || normalized.contains("selected camera is busy")
        default:
            return false
        }
    }

    private func restorePreviewAfterControlWrite(for device: CameraDeviceDescriptor) async {
        guard selectedDeviceID == device.id else { return }

        do {
            let session = try await dependencies.previewService.startPreview(for: device)
            previewSession = session
            lastPreviewError = nil
        } catch let error as CameraControlError {
            previewSession = nil
            lastPreviewError = error
            dependencies.logger.error("Preview restart failed for \(device.name): \(error.localizedDescription)")
        } catch {
            previewSession = nil
            lastPreviewError = .backendFailure(error.localizedDescription)
            dependencies.logger.error("Preview restart failed for \(device.name): \(error.localizedDescription)")
        }
    }

    func savePreferences() {
        let previousPreferences = preferences
        var updated = preferencesViewModel.preferences
        updated.controlTestMode = false
        preferences = updated
        preferencesViewModel.preferences = updated

        if previousPreferences.showUnsupportedControls != updated.showUnsupportedControls {
            Task {
                await loadSelection()
            }
        }

        Task {
            await dependencies.preferencesService.savePreferences(updated)
        }
    }

    func selectProfile(id: UUID?) {
        selectedProfileID = id
        profileDraftName = selectedProfile?.name ?? ""
    }

    func saveNewProfile() {
        guard let selectedDevice else {
            lastErrorMessage = "Select a device before saving a profile."
            return
        }

        let name = profileDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = name.isEmpty ? "Profile \(Date.now.formatted(date: .abbreviated, time: .shortened))" : name
        let profile = CameraProfile(
            id: UUID(),
            name: resolvedName,
            deviceMatch: .from(device: selectedDevice),
            values: currentValues,
            createdAt: .now,
            updatedAt: .now,
            loadAtStart: false
        )
        persistProfile(profile, successMessage: "Saved new profile \(profile.name)")
    }

    func updateSelectedProfile() {
        guard let selectedDevice, let selectedProfile else {
            lastErrorMessage = "Select a profile before updating."
            return
        }

        let name = profileDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedProfile = CameraProfile(
            id: selectedProfile.id,
            name: name.isEmpty ? selectedProfile.name : name,
            deviceMatch: .from(device: selectedDevice),
            values: currentValues,
            createdAt: selectedProfile.createdAt,
            updatedAt: .now,
            loadAtStart: selectedProfile.loadAtStart
        )
        persistProfile(updatedProfile, successMessage: "Updated profile \(updatedProfile.name)")
    }

    func toggleLoadAtStart(_ isEnabled: Bool) {
        guard let selectedProfile else { return }
        preferences.loadSelectedProfileAtStartup = isEnabled
        preferences.startupProfileID = isEnabled ? selectedProfile.id : nil
        preferencesViewModel.preferences = preferences
        savePreferences()

        let updatedProfile = CameraProfile(
            id: selectedProfile.id,
            name: selectedProfile.name,
            deviceMatch: selectedProfile.deviceMatch,
            values: selectedProfile.values,
            createdAt: selectedProfile.createdAt,
            updatedAt: .now,
            loadAtStart: isEnabled
        )
        persistProfile(updatedProfile, successMessage: isEnabled ? "Marked profile to load at start" : "Removed startup profile")
    }

    func refreshSelection() {
        Task {
            await loadSelection()
        }
    }

    func refreshAll() {
        Task {
            await refreshDevices()
            await refreshProfiles()
        }
    }

    private func persistProfile(_ profile: CameraProfile, successMessage: String) {
        
        Task {
            do {
                try await dependencies.profileService.saveProfile(profile)
                await refreshProfiles()
                await MainActor.run {
                    self.selectedProfileID = profile.id
                    self.profileDraftName = profile.name
                    self.statusMessage = successMessage
                }
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func loadSelectedProfile() {
        guard let selectedDevice, let selectedProfile else {
            lastErrorMessage = "Select a device and profile before loading."
            return
        }

        Task {
            let matchScore = selectedDevice.matchScore(for: selectedProfile.deviceMatch)
            let result = await dependencies.profileApplyingService.apply(profile: selectedProfile, to: selectedDevice)
            await MainActor.run {
                if result.items.contains(where: { $0.status == .failed }) {
                    self.statusMessage = "Profile applied with issues"
                } else if result.skippedCount > 0 {
                    self.statusMessage = "Applied \(result.succeededCount) control(s), skipped \(result.skippedCount)"
                } else if matchScore == 0 {
                    self.statusMessage = "Applied profile to a non-matching device"
                } else {
                    self.statusMessage = "Applied \(result.succeededCount) control(s) from \(selectedProfile.name)"
                }
                if let failure = result.items.first(where: { $0.status == .failed }) {
                    self.lastErrorMessage = failure.message
                } else {
                    self.lastErrorMessage = nil
                }
            }
        }
    }

    func requestDeleteSelectedProfile() {
        guard selectedProfileID != nil else {
            lastErrorMessage = "Select a profile before deleting."
            return
        }
        showDeleteConfirmation = true
    }

    func confirmDeleteSelectedProfile() {
        guard let selectedProfileID else {
            lastErrorMessage = "Select a profile before deleting."
            return
        }

        Task {
            do {
                try await dependencies.profileService.deleteProfile(id: selectedProfileID)
                await refreshProfiles()
                await MainActor.run {
                    self.showDeleteConfirmation = false
                    self.selectedProfileID = self.displayedProfiles.first?.id
                    self.profileDraftName = self.selectedProfile?.name ?? ""
                    self.statusMessage = "Deleted profile"
                }
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadSelection() async {
        guard let selectedDevice else {
            capabilities = []
            currentValues = [:]
            previewSession = nil
            statusMessage = "No camera detected."
            connectionState = .disconnected
            lastPreviewError = nil
            lastControlsError = nil
            syncTabViewModels()
            dependencies.logger.info("No selected device available during loadSelection")
            return
        }

        isRefreshingSelection = true
        connectionState = .loading
        dependencies.logger.info("Loading selection for \(selectedDevice.name)")
        lastPreviewError = nil
        lastControlsError = nil

        do {
            previewSession = try await dependencies.previewService.startPreview(for: selectedDevice)
        } catch let error as CameraControlError {
            previewSession = nil
            lastPreviewError = error
            dependencies.logger.error("Preview failed for \(selectedDevice.name): \(error.localizedDescription)")
        } catch {
            previewSession = nil
            lastPreviewError = .backendFailure(error.localizedDescription)
            dependencies.logger.error("Preview failed for \(selectedDevice.name): \(error.localizedDescription)")
        }

        do {
            let resolvedCapabilities = try await dependencies.cameraControlService.fetchCapabilities(for: selectedDevice)
            capabilities = preferences.showUnsupportedControls
                ? resolvedCapabilities
                : resolvedCapabilities.filter(\.isSupported)
            currentValues = seededCurrentValues(from: capabilities)
            syncTabViewModels()

            if RawUVCBindings.canAttemptDirectAccess(for: selectedDevice) == false {
                do {
                    let refreshedValues = try await dependencies.cameraControlService.readCurrentValues(for: selectedDevice)
                    currentValues = mergedCurrentValues(
                        existing: currentValues,
                        refreshed: refreshedValues,
                        capabilities: capabilities,
                        lastWrittenKey: nil,
                        lastWrittenValue: nil
                    )
                } catch let error as CameraControlError {
                    currentValues = mergedCurrentValues(
                        existing: currentValues,
                        refreshed: [:],
                        capabilities: capabilities,
                        lastWrittenKey: nil,
                        lastWrittenValue: nil
                    )
                    lastControlsError = error
                    dependencies.logger.error("Controls failed for \(selectedDevice.name): \(error.localizedDescription)")
                } catch {
                    currentValues = mergedCurrentValues(
                        existing: currentValues,
                        refreshed: [:],
                        capabilities: capabilities,
                        lastWrittenKey: nil,
                        lastWrittenValue: nil
                    )
                    lastControlsError = .backendFailure(error.localizedDescription)
                    dependencies.logger.error("Controls failed for \(selectedDevice.name): \(error.localizedDescription)")
                }
            }
        } catch let error as CameraControlError {
            capabilities = []
            currentValues = [:]
            lastControlsError = error
            dependencies.logger.error("Controls failed for \(selectedDevice.name): \(error.localizedDescription)")
        } catch {
            capabilities = []
            currentValues = [:]
            lastControlsError = .backendFailure(error.localizedDescription)
            dependencies.logger.error("Controls failed for \(selectedDevice.name): \(error.localizedDescription)")
        }

        syncTabViewModels()
        preferencesViewModel.preferences = preferences

        let outcome = SelectionLoadStateResolver.resolve(
            deviceName: selectedDevice.name,
            previewError: lastPreviewError,
            controlsError: lastControlsError
        )
        statusMessage = outcome.statusMessage
        lastErrorMessage = outcome.lastErrorMessage
        connectionState = outcome.connectionState

        if outcome.connectionState == .connected {
            dependencies.logger.info("Selection loaded for \(selectedDevice.name) with \(capabilities.count) capabilities")
            await attemptStartupProfileLoadIfNeeded()
        }

        isRefreshingSelection = false
    }

    func openCameraPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func observeDeviceUpdates() {
        deviceUpdatesTask?.cancel()
        deviceUpdatesTask = Task { [weak self] in
            guard let self else { return }
            let updates = await dependencies.deviceDiscoveryService.deviceUpdates()
            for await devices in updates {
                await MainActor.run {
                    self.handleDeviceListUpdate(devices)
                }
            }
        }
    }

    private func observeLifecycleEvents() {
        lifecycleEventsTask?.cancel()
        lifecycleEventsTask = Task { [weak self] in
            guard let self else { return }
            let events = await dependencies.lifecycleCoordinator.events()
            for await event in events {
                await MainActor.run {
                    self.handleLifecycleEvent(event)
                }
            }
        }
    }

    private func handleDeviceListUpdate(_ devices: [CameraDeviceDescriptor]) {
        if devices == availableDevices {
            return
        }

        let newDeviceIDs = Set(devices.map(\.id))
        let reconnectedSelectedDevice = selectedDeviceID.map { newDeviceIDs.contains($0) && !lastConnectedDeviceIDs.contains($0) } ?? false
        let lostSelectedDevice = selectedDeviceID.map { !newDeviceIDs.contains($0) && lastConnectedDeviceIDs.contains($0) } ?? false

        availableDevices = devices
        lastConnectedDeviceIDs = newDeviceIDs

        if let selectedDeviceID, devices.contains(where: { $0.id == selectedDeviceID }) == false {
            self.selectedDeviceID = devices.first?.id
        } else if selectedDeviceID == nil {
            selectedDeviceID = devices.first?.id
        }

        if lostSelectedDevice {
            previewSession = nil
            connectionState = .disconnected
            statusMessage = "Selected camera disconnected"
        }

        Task {
            await loadSelection()
            if reconnectedSelectedDevice {
                await handleReconnectRecovery()
            }
        }
    }

    private func handleLifecycleEvent(_ event: LifecycleCoordinator.Event) {
        switch event {
        case .willSleep:
            statusMessage = "Mac is going to sleep"
        case .didWake:
            statusMessage = "Recovering camera state after wake"
            guard preferences.autoReapplyAfterWake else { return }
            Task {
                await loadSelection()
                if let selectedProfile, let selectedDevice {
                    let result = await dependencies.profileApplyingService.apply(profile: selectedProfile, to: selectedDevice)
                    await MainActor.run {
                        if result.items.contains(where: { $0.status == .failed }) {
                            self.lastErrorMessage = "Wake recovery reapplied with issues"
                        } else {
                            self.lastErrorMessage = nil
                            self.statusMessage = "Recovered camera state after wake"
                        }
                    }
                }
            }
        }
    }

    private func handleReconnectRecovery() async {
        await MainActor.run {
            self.statusMessage = "Camera reconnected, restoring state"
        }

        guard preferences.autoReapplyOnReconnect, let selectedProfile, let selectedDevice else { return }
        let result = await dependencies.profileApplyingService.apply(profile: selectedProfile, to: selectedDevice)
        await MainActor.run {
            if result.items.contains(where: { $0.status == .failed }) {
                self.lastErrorMessage = "Reconnect recovery reapplied with issues"
                self.statusMessage = "Camera reconnected with partial recovery"
            } else if result.skippedCount > 0 {
                self.lastErrorMessage = nil
                self.statusMessage = "Camera reconnected, unsupported controls skipped"
            } else {
                self.lastErrorMessage = nil
                self.statusMessage = "Camera reconnected and profile restored"
            }
        }
    }

    private func syncTabViewModels() {
        basicTabViewModel.update(capabilities: capabilities, currentValues: currentValues)
        advancedTabViewModel.update(capabilities: capabilities, currentValues: currentValues)
    }

    private func attemptStartupProfileLoadIfNeeded() async {
        guard hasAttemptedStartupProfileLoad == false else { return }
        guard preferences.loadSelectedProfileAtStartup, let startupProfileID = preferences.startupProfileID else { return }
        guard let selectedDevice, let startupProfile = profiles.first(where: { $0.id == startupProfileID }) else { return }
        guard selectedDevice.matchScore(for: startupProfile.deviceMatch) > 0 else {
            await MainActor.run {
                self.statusMessage = "Startup profile skipped because the selected device does not match"
                self.lastErrorMessage = nil
            }
            hasAttemptedStartupProfileLoad = true
            return
        }

        hasAttemptedStartupProfileLoad = true
        let result = await dependencies.profileApplyingService.apply(profile: startupProfile, to: selectedDevice)
        await MainActor.run {
            self.selectedProfileID = startupProfile.id
            self.profileDraftName = startupProfile.name
            if result.items.contains(where: { $0.status == .failed }) {
                self.statusMessage = "Startup profile applied with issues"
            } else if result.skippedCount > 0 {
                self.statusMessage = "Startup profile loaded with unsupported controls skipped"
            } else {
                self.statusMessage = "Startup profile loaded"
            }
        }
    }

    private func profileMatchScore(_ profile: CameraProfile) -> Int {
        guard let selectedDevice else { return 0 }
        return selectedDevice.matchScore(for: profile.deviceMatch)
    }

    private func mergedCurrentValues(
        existing: [CameraControlKey: CameraControlValue],
        refreshed: [CameraControlKey: CameraControlValue],
        capabilities: [CameraControlCapability],
        lastWrittenKey: CameraControlKey?,
        lastWrittenValue: CameraControlValue?
    ) -> [CameraControlKey: CameraControlValue] {
        var merged: [CameraControlKey: CameraControlValue] = Dictionary(
            uniqueKeysWithValues: capabilities.compactMap { capability in
                guard let value = capability.currentValue else { return nil }
                return (capability.key, value)
            }
        )

        for (key, value) in existing {
            merged[key] = value
        }

        for (key, value) in refreshed {
            merged[key] = value
        }

        if let lastWrittenKey, let lastWrittenValue, refreshed[lastWrittenKey] == nil {
            merged[lastWrittenKey] = lastWrittenValue
        }

        return merged
    }

    private func seededCurrentValues(from capabilities: [CameraControlCapability]) -> [CameraControlKey: CameraControlValue] {
        Dictionary(
            uniqueKeysWithValues: capabilities.compactMap { capability in
                guard let value = capability.currentValue ?? capability.defaultValue else {
                    return nil
                }
                return (capability.key, value)
            }
        )
    }
}
