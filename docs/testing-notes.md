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
- the app now compiles with an IOKit-backed USB metadata discovery layer for vendor/product/serial enrichment
- the UVC backend stack now compiles with a preferred-backend/fallback-backend wrapper and fallback tests
- the raw UVC layer now compiles with selector/entity mapping tests for the LifeCam candidate path
- the preferred backend now compiles with synthetic raw capability generation for mapped USB LifeCam candidates

Current live-test caveats:

- real hardware control writes are still mocked behind the in-memory UVC backend
- preview permission and control loading can now fail independently, so partial-access states are more honest than earlier all-or-nothing loading
- USB metadata enrichment is best-effort and currently matched heuristically from the USB registry to the AVFoundation camera name
- the legacy `Webcam Settings` utility should be closed during live testing to avoid camera/control contention

## Backend reality

Implemented today:

- capability-driven control architecture
- typed device/profile matching
- serialized control write path with validation
- ordered profile application
- in-memory UVC backend with LifeCam-specific defaults/ranges
- reconnect and wake recovery scaffolding

Still not implemented:

- real UVC hardware read/write calls for the LifeCam
- true capability probing from the physical device
- verification that each legacy control maps correctly to actual hardware selectors on Tahoe

## Practical next step

Highest-value next milestone:

- replace the in-memory UVC backend with a real backend implementation while keeping the existing adapter/service/view-model/UI structure intact
