import Testing
@testable import WebcamSettings

@Test
func selectionLoadResolverReportsConnectedWhenPreviewAndControlsSucceed() {
    let outcome = SelectionLoadStateResolver.resolve(
        deviceName: "LifeCam",
        previewError: nil,
        controlsError: nil
    )

    #expect(outcome.connectionState == .connected)
    #expect(outcome.statusMessage == "Loaded LifeCam")
    #expect(outcome.lastErrorMessage == nil)
}

@Test
func selectionLoadResolverPrioritizesDeviceBusy() {
    let outcome = SelectionLoadStateResolver.resolve(
        deviceName: "LifeCam",
        previewError: .deviceBusy,
        controlsError: nil
    )

    #expect(outcome.connectionState == .deviceBusy)
    #expect(outcome.statusMessage == "Camera is busy")
}

@Test
func selectionLoadResolverExplainsPermissionDeniedPreview() {
    let outcome = SelectionLoadStateResolver.resolve(
        deviceName: "LifeCam",
        previewError: .permissionDenied,
        controlsError: nil
    )

    #expect(outcome.connectionState == .partialControlAccess)
    #expect(outcome.statusMessage == "Camera permission denied for preview")
}

@Test
func selectionLoadResolverPreservesPreviewWhenControlsFail() {
    let outcome = SelectionLoadStateResolver.resolve(
        deviceName: "LifeCam",
        previewError: nil,
        controlsError: .controlReadFailed(.brightness)
    )

    #expect(outcome.connectionState == .partialControlAccess)
    #expect(outcome.statusMessage == "Preview active, controls limited")
}
