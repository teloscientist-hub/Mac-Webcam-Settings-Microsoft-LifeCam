# WebcamSettings

Native macOS SwiftUI replacement for the legacy Webcam Settings utility, built around a capability-driven architecture for the Microsoft LifeCam Studio and compatible UVC webcams.

## Status

Initial scaffold in place:

- Phase 0: app shell, folder structure, dependency container, logging scaffold
- Phase 1: domain models, protocols, typed errors, placeholder services
- Phase 2-3: device discovery, preview pipeline, runtime launch verified on local Tahoe Mac
- Phase 4-15 partial: backend adapter boundary, serialized writes, profile flows, lifecycle/reconnect handling, diagnostics

Current reality:

- The app launches locally with the attached Microsoft LifeCam Studio present.
- macOS system profiling confirms the LifeCam is visible as a USB camera.
- A packaged `.app` bundle now launches locally, which removes the earlier bundle-identity warning from raw SwiftPM execution.
- Preview and control loading are handled independently so the UI can distinguish connected, device-busy, permission-denied, and partial-access states more accurately.
- Device discovery now attempts to enrich AVFoundation cameras with USB registry metadata such as vendor/product IDs and serial number when available.
- Profile matching and mock-backend targeting can now use the Microsoft LifeCam vendor/product fingerprint (`0x045E` / `0x0772`) instead of relying only on the device name.
- The UVC stack now uses a hybrid backend wrapper that is ready to prefer a future raw hardware backend and fall back cleanly to the in-memory backend today.
- The raw UVC layer now includes a concrete LifeCam-oriented control catalog with planned unit/selector mappings for major camera and processing-unit controls.
- The preferred backend can now synthesize raw-catalog-backed capabilities for LifeCam candidates before falling back for current values and writes.
- Real UVC hardware control is still represented by an in-memory backend profile layer.

## Docs

- `docs/master-project-spec.md`
- `docs/session-handoff-prompt.md`
- `docs/testing-notes.md`
