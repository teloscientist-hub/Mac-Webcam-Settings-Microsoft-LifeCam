import Foundation

struct SelectionLoadOutcome: Equatable {
    let connectionState: AppViewModel.ConnectionState
    let statusMessage: String
    let lastErrorMessage: String?
}

enum SelectionLoadStateResolver {
    static func resolve(
        deviceName: String,
        previewError: CameraControlError?,
        controlsError: CameraControlError?
    ) -> SelectionLoadOutcome {
        if previewError == nil, controlsError == nil {
            return SelectionLoadOutcome(
                connectionState: .connected,
                statusMessage: "Loaded \(deviceName)",
                lastErrorMessage: nil
            )
        }

        if previewError == .deviceBusy || controlsError == .deviceBusy {
            return SelectionLoadOutcome(
                connectionState: .deviceBusy,
                statusMessage: "Camera is busy",
                lastErrorMessage: (previewError ?? controlsError)?.localizedDescription
            )
        }

        if previewError == .permissionDenied, controlsError == nil {
            return SelectionLoadOutcome(
                connectionState: .partialControlAccess,
                statusMessage: "Camera permission denied for preview",
                lastErrorMessage: previewError?.localizedDescription
            )
        }

        if previewError == nil, controlsError != nil {
            return SelectionLoadOutcome(
                connectionState: .partialControlAccess,
                statusMessage: "Preview active, controls limited",
                lastErrorMessage: controlsError?.localizedDescription
            )
        }

        if previewError != nil, controlsError == nil {
            return SelectionLoadOutcome(
                connectionState: .partialControlAccess,
                statusMessage: "Preview unavailable, controls ready",
                lastErrorMessage: previewError?.localizedDescription
            )
        }

        return SelectionLoadOutcome(
            connectionState: .partialControlAccess,
            statusMessage: "Camera access limited",
            lastErrorMessage: (previewError ?? controlsError)?.localizedDescription
        )
    }
}
