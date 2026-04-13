# Testing Notes

## Local hardware/runtime validation

Validated on:

- macOS Tahoe
- Microsoft LifeCam Studio connected over USB

Observed locally:

- `system_profiler SPCameraDataType` reports `Microsoft(R) LifeCam Studio(TM)`
- `swift run WebcamSettings` launches and remains running
- AVFoundation camera stack resolves the LifeCam device during startup
- a packaged `.build/WebcamSettings.app` also launches successfully
- bundled runtime logs show active CMIO frame traffic from the LifeCam after the preview-session fix
- direct raw-UVC control works in the packaged app for the main LifeCam controls
- the app now compiles with an IOKit-backed USB metadata discovery layer for vendor/product/serial enrichment

Current live-test caveats:

- preview permission and control loading can now fail independently, so partial-access states are more honest than earlier all-or-nothing loading
- USB metadata enrichment is best-effort and currently matched heuristically from the USB registry to the AVFoundation camera name
- the legacy `Webcam Settings` utility should be closed during live testing to avoid camera/control contention
- on this Tahoe Mac, the LifeCam can fall into a bad raw-control state where direct reads/writes fail until the webcam is unplugged and replugged
- `Power Line Frequency` reads successfully but does not reliably persist writes on this LifeCam/Tahoe combination
- manual exposure is hardware-coarse on this device: values near the low end can jump from black to overbright in one integer step
- replacement USB webcams can now be exercised through the same UI, but generic mappings should be treated as experimental until a webcam is individually validated

## Backend reality

Implemented today:

- capability-driven control architecture
- typed device/profile matching
- serialized control write path with validation
- ordered profile application
- raw-UVC LifeCam hardware read/write path
- LifeCam-specific defaults/ranges and recovery messaging
- reconnect and wake recovery scaffolding
- generic USB webcam compatibility diagnostics and experimental-control labeling

Still not implemented:

- true capability probing from the physical device
- polished handling for the remaining unreliable `Power Line Frequency` control
- deeper capability probing beyond the current mapped-control set

## Practical next step

Highest-value next milestone:

- keep hardening the current working control path, especially device-state recovery, replacement-webcam validation, and the remaining unreliable controls
