import SwiftUI

struct AdvancedTabView: View {
    @ObservedObject var viewModel: AdvancedTabViewModel
    let inFlightControls: Set<CameraControlKey>
    let controlErrorMessages: [CameraControlKey: String]
    let onWrite: (CameraControlKey, CameraControlValue) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ControlSection(title: "Lighting") {
                    sectionRows(for: [.powerLineFrequency, .backlightCompensation])
                }

                ControlSection(title: "Focus") {
                    sectionRows(for: [.focusAuto, .focus])
                }

                ControlSection(title: "PTZ") {
                    sectionRows(for: [.zoom, .pan, .tilt])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func sectionRows(for keys: [CameraControlKey]) -> some View {
        ForEach(keys, id: \.self) { key in
            if let capability = viewModel.capabilities.first(where: { $0.key == key }) {
                ControlRow(
                    capability: capability,
                    currentValues: viewModel.currentValues,
                    isWriting: inFlightControls.contains(capability.key),
                    errorMessage: controlErrorMessages[capability.key],
                    onWrite: onWrite
                )
            }
        }
    }
}
