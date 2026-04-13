# WebcamSettings

Native macOS SwiftUI replacement for the legacy Webcam Settings utility, built around a capability-driven architecture for UVC webcams on macOS.

## Status

Current reality:

- The packaged app launches locally on macOS Tahoe with a Microsoft LifeCam Studio attached over USB.
- Live preview works in the packaged app.
- The app now uses a real raw-UVC hardware path for the LifeCam rather than the earlier mock-only control path.
- Device discovery enriches AVFoundation cameras with USB metadata such as vendor/product IDs and registry identity when available.
- Preview and control loading are handled independently so the UI can distinguish connected, device-busy, permission-denied, partial-access, and bad-device-state cases more accurately.
- Profiles, reconnect recovery, wake recovery, and serialized control writes are implemented.
- Unverified USB webcams now surface as explicit generic-UVC test targets rather than being implied as fully validated devices.

Controls validated on the attached LifeCam:

- Brightness
- Contrast
- Saturation
- Sharpness
- White Balance Auto
- White Balance Temperature
- Focus Auto
- Focus
- Exposure Mode
- Exposure Time
- Zoom

Known caveats:

- `Power Line Frequency` is exposed by the device but does not reliably persist changes on this LifeCam/Tahoe combination.
- The LifeCam can enter a bad raw-control state after repeated failures; unplugging and reconnecting the webcam restores it.
- Manual exposure on this camera is very coarse at the low end and is not perceptually smooth.
- Generic USB webcams still rely on provisional raw mappings until they are validated on hardware.

## Replacement Webcam Readiness

- Non-LifeCam USB webcams now show an explicit compatibility banner in the app.
- Generic mapped controls are marked as experimental so test runs do not look like validated support.
- USB vendor/product metadata is carried through discovery, diagnostics, and backend selection to make new-device bringup faster.
- The debug panel now distinguishes validated LifeCam support from generic USB candidate support.

## Docs

- `docs/master-project-spec.md`
- `docs/session-handoff-prompt.md`
- `docs/testing-notes.md`
