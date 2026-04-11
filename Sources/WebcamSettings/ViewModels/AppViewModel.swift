import AVFoundation
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
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
    @Published var preferences = AppPreferences()
    @Published var selectedTab: Tab = .basic
    @Published var statusMessage = "Scaffold ready. Select a device to begin."
    @Published var lastErrorMessage: String?
    @Published var previewSession: AVCaptureSession?

    let basicTabViewModel: BasicTabViewModel
    let advancedTabViewModel: AdvancedTabViewModel
    let profilesViewModel = ProfilesViewModel()
    let preferencesViewModel = PreferencesViewModel()

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
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

    func bootstrap() async {
        await dependencies.lifecycleCoordinator.start()
        await dependencies.deviceDiscoveryService.startMonitoring()
        preferences = await dependencies.preferencesService.loadPreferences()
        await refreshDevices()
        await refreshProfiles()
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
        currentValues[key] = value
        Task {
            let writer = ControlWriteCoordinator(
                controlService: dependencies.cameraControlService,
                logger: dependencies.logger,
                debugStore: dependencies.debugStore
            )
            let result = await writer.write(value, key: key, device: selectedDevice)
            if case let .failure(error) = result {
                await MainActor.run {
                    self.lastErrorMessage = error.localizedDescription
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

    private func loadSelection() async {
        guard let selectedDevice else {
            capabilities = []
            currentValues = [:]
            previewSession = nil
            statusMessage = "No camera detected."
            return
        }

        do {
            let preview = try await dependencies.previewService.startPreview(for: selectedDevice)
            async let fetchedCapabilities = dependencies.cameraControlService.fetchCapabilities(for: selectedDevice)
            async let fetchedValues = dependencies.cameraControlService.readCurrentValues(for: selectedDevice)

            previewSession = preview
            capabilities = try await fetchedCapabilities
            currentValues = try await fetchedValues
            basicTabViewModel.update(capabilities: capabilities, currentValues: currentValues)
            advancedTabViewModel.update(capabilities: capabilities, currentValues: currentValues)
            preferencesViewModel.preferences = preferences
            statusMessage = "Loaded \(selectedDevice.name)"
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Selection loaded with backend placeholders."
        }
    }
}
