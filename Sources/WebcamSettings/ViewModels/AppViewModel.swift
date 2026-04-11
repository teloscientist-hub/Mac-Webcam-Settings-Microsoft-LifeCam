import AVFoundation
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    enum ConnectionState {
        case loading
        case connected
        case disconnected
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

    let basicTabViewModel: BasicTabViewModel
    let advancedTabViewModel: AdvancedTabViewModel
    let profilesViewModel = ProfilesViewModel()
    let preferencesViewModel = PreferencesViewModel()

    private let dependencies: AppDependencies
    private var deviceUpdatesTask: Task<Void, Never>?
    private var lifecycleEventsTask: Task<Void, Never>?
    private let writeCoordinator: ControlWriteCoordinator
    private var hasAttemptedStartupProfileLoad = false

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
        await dependencies.lifecycleCoordinator.start()
        await dependencies.deviceDiscoveryService.startMonitoring()
        observeDeviceUpdates()
        observeLifecycleEvents()
        preferences = await dependencies.preferencesService.loadPreferences()
        preferencesViewModel.preferences = preferences
        await refreshDevices()
        await refreshProfiles()
        await attemptStartupProfileLoadIfNeeded()
    }

    func refreshDevices() async {
        availableDevices = await dependencies.deviceDiscoveryService.currentDevices()
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
                        self.currentValues = refreshedValues
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
                    self.controlErrorMessages[key] = error.localizedDescription
                    self.lastErrorMessage = error.localizedDescription
                    self.statusMessage = "Failed to update \(key.displayName)"
                    self.syncTabViewModels()
                }
            }
        }
    }

    func savePreferences() {
        let updated = preferencesViewModel.preferences
        preferences = updated
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
            let result = await dependencies.profileApplyingService.apply(profile: selectedProfile, to: selectedDevice)
            await MainActor.run {
                self.statusMessage = result.items.contains(where: { $0.status == .failed })
                    ? "Profile applied with issues"
                    : "Applied \(result.succeededCount) control(s) from \(selectedProfile.name)"
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
            syncTabViewModels()
            return
        }

        connectionState = .loading

        do {
            let preview = try await dependencies.previewService.startPreview(for: selectedDevice)
            async let fetchedCapabilities = dependencies.cameraControlService.fetchCapabilities(for: selectedDevice)
            async let fetchedValues = dependencies.cameraControlService.readCurrentValues(for: selectedDevice)

            previewSession = preview
            let resolvedCapabilities = try await fetchedCapabilities
            capabilities = preferences.showUnsupportedControls
                ? resolvedCapabilities
                : resolvedCapabilities.filter(\.isSupported)
            currentValues = try await fetchedValues
            syncTabViewModels()
            preferencesViewModel.preferences = preferences
            statusMessage = "Loaded \(selectedDevice.name)"
            lastErrorMessage = nil
            connectionState = .connected
            await attemptStartupProfileLoadIfNeeded()
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Selection loaded with backend placeholders."
            connectionState = .partialControlAccess
            syncTabViewModels()
        }
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
        availableDevices = devices

        if let selectedDeviceID, devices.contains(where: { $0.id == selectedDeviceID }) == false {
            self.selectedDeviceID = devices.first?.id
        } else if selectedDeviceID == nil {
            selectedDeviceID = devices.first?.id
        }

        Task {
            await loadSelection()
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

    private func syncTabViewModels() {
        basicTabViewModel.update(capabilities: capabilities, currentValues: currentValues)
        advancedTabViewModel.update(capabilities: capabilities, currentValues: currentValues)
    }

    private func attemptStartupProfileLoadIfNeeded() async {
        guard hasAttemptedStartupProfileLoad == false else { return }
        guard preferences.loadSelectedProfileAtStartup, let startupProfileID = preferences.startupProfileID else { return }
        guard let selectedDevice, let startupProfile = profiles.first(where: { $0.id == startupProfileID }) else { return }

        hasAttemptedStartupProfileLoad = true
        let result = await dependencies.profileApplyingService.apply(profile: startupProfile, to: selectedDevice)
        await MainActor.run {
            self.selectedProfileID = startupProfile.id
            self.profileDraftName = startupProfile.name
            self.statusMessage = result.items.contains(where: { $0.status == .failed })
                ? "Startup profile applied with issues"
                : "Startup profile loaded"
        }
    }

    private func profileMatchScore(_ profile: CameraProfile) -> Int {
        guard let selectedDevice else { return 0 }
        var score = 0
        if profile.deviceMatch.deviceIdentifier == selectedDevice.backendIdentifier || profile.deviceMatch.deviceIdentifier == selectedDevice.avFoundationUniqueID {
            score += 4
        }
        if profile.deviceMatch.model == selectedDevice.model, profile.deviceMatch.model != nil {
            score += 2
        }
        if profile.deviceMatch.deviceName == selectedDevice.name {
            score += 1
        }
        return score
    }
}
