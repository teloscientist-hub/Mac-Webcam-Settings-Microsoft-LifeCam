import SwiftUI

struct AdvancedTabView: View {
    let capabilities: [CameraControlCapability]
    let currentValues: [CameraControlKey: CameraControlValue]
    let inFlightControls: Set<CameraControlKey>
    let controlErrorMessages: [CameraControlKey: String]
    let onWrite: (CameraControlKey, CameraControlValue) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ControlSection(title: "PTZ") {
                    sectionRows(for: [.zoom, .pan, .tilt])
                }

                ControlSection(title: "Exposure") {
                    sectionRows(for: [.exposureMode, .exposureTime])
                }

                ControlSection(title: "White Balance") {
                    sectionRows(for: [.whiteBalanceAuto, .whiteBalanceTemperature])
                }

                ControlSection(title: "Lighting") {
                    sectionRows(for: [.powerLineFrequency, .backlightCompensation])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func sectionRows(for keys: [CameraControlKey]) -> some View {
        ForEach(keys, id: \.self) { key in
            if let capability = capabilities.first(where: { $0.key == key }) {
                ControlRow(
                    capability: capability,
                    currentValues: currentValues,
                    isWriting: inFlightControls.contains(capability.key),
                    errorMessage: controlErrorMessages[capability.key],
                    onWrite: onWrite
                )
            }
        }
    }
}
