# Master Project Spec — macOS Webcam Settings Replacement

## 1. Project overview

Build a native macOS desktop app that functionally replaces the old **Webcam Settings** utility currently used to control a **Microsoft LifeCam Studio** webcam.

The old app still works on current macOS Tahoe, but it is aging and glitchy. The replacement app should preserve the useful working behavior while using a modern, maintainable architecture.

This project is a **functional replacement**, not a code clone and not a direct port of an existing Windows app.

---

## 2. Primary objective

Create a stable macOS app that can:

- preview the selected webcam
- expose the working controls currently available through the old app
- allow live editing of those controls
- save and reload named profiles
- optionally load a selected profile at startup
- optionally reapply settings after reconnect, relaunch, or sleep/wake

Primary target device:

- **Microsoft LifeCam Studio**

Secondary goal:

- support other compatible external UVC webcams through capability detection, without hardcoding LifeCam-only assumptions into the UI layer

---

## 3. Product scope

### In scope

- native macOS app
- device picker
- live camera preview
- Basic tab
- Advanced tab
- Preferences tab
- capability-driven control rendering
- immediate application of controls
- named profile save/update/delete/load
- startup profile load
- reconnect/reapply support
- debug/diagnostics panel

### Out of scope for v1

- virtual camera output
- OBS integration
- recording
- filters/effects/LUTs
- cloud sync
- remote control
- broad support for every webcam beyond capability-based handling

---

## 4. Functional requirements

### 4.1 Main window

The app should present:

- a camera device selector at the top
- tabbed sections:
  - Basic
  - Advanced
  - Preferences
- a profile management section at the bottom
- a status area or banner for device/control feedback

---

### 4.2 Basic tab

The Basic tab should include the following control groups.

#### Exposure
- Exposure mode
- Exposure time

#### Image controls
- Brightness
- Contrast
- Saturation
- Sharpness

#### White balance
- Auto white balance
- White balance temperature

Behavior requirements:
- controls should reflect current device values
- changes should apply live
- dependent manual controls should disable appropriately when auto mode is enabled
- unsupported controls should be hidden or disabled based on capability data

---

### 4.3 Advanced tab

The Advanced tab should include:

#### Power line frequency
- Disabled
- 50 Hz
- 60 Hz
- Auto

#### Other controls
- Backlight compensation
- Autofocus
- Focus
- Zoom
- Pan
- Tilt

Behavior requirements:
- controls apply live
- focus must disable when autofocus is enabled
- unsupported values/options should not be shown if the selected device does not expose them

---

### 4.4 Preferences tab

The Preferences tab should include app-level behavior, not camera image controls.

Recommended v1 options:
- load selected profile at startup
- auto-reapply profile on reconnect
- auto-reapply after wake/sleep recovery
- show/hide unsupported controls
- show/hide debug panel
- optional debug logging controls

---

### 4.5 Profile system

The app must support:
- save new profile
- update existing profile
- delete profile
- select profile
- load profile manually
- mark a selected profile for startup loading

Profile behavior requirements:
- profiles should store semantic control keys, not UI labels
- unsupported controls should be skipped during apply rather than causing total failure
- device matching should prefer exact matches, but partial model-name matching may be allowed with caution

---

### 4.6 Lifecycle/recovery behavior

The app should handle:
- app launch
- device selection change
- device disconnect/reconnect
- system sleep/wake
- preview restart
- optional device busy/recovery conditions

When configured, the app should:
- restore preview
- re-fetch capabilities
- re-read device state
- reapply selected profile in a safe order

---

## 5. Confirmed target control inventory

Based on the old app screens currently working on macOS Tahoe, the replacement should target this control inventory.

### Basic tab
- exposureMode
- exposureTime
- brightness
- contrast
- saturation
- sharpness
- whiteBalanceAuto
- whiteBalanceTemperature

### Advanced tab
- powerLineFrequency
- backlightCompensation
- focusAuto
- focus
- zoom
- pan
- tilt

These controls should be treated as **capability-driven targets**, not as hardcoded guarantees for every camera.

---

## 6. Product design principles

The app should follow these product-level principles:

1. **LifeCam-first, not LifeCam-only**
2. **Capability-driven rendering**
3. **Minimal-friction utility UI**
4. **Immediate feedback**
5. **Graceful degradation**
6. **Maintainability over quick hacks**
7. **Reconnection resilience as a first-class requirement**

---

## 7. Technical architecture

### 7.1 Architectural goals

The codebase should optimize for:
- separation between preview, control, profile, lifecycle, and UI logic
- backend replaceability
- clean state flow
- low rewrite cost for additional controls later
- easier debugging when a device or control fails

---

### 7.2 Recommended stack

#### Language and UI
- Swift
- SwiftUI
- AppKit bridging only where needed

#### Preview/media
- AVFoundation

#### Camera control
- UVC control backend behind an adapter layer
- implementation may use an existing macOS UVC framework, custom bindings, or another backend, but must remain isolated behind a hardware abstraction boundary

#### Persistence
- JSON or equivalent simple structured persistence for profiles
- UserDefaults or equivalent for small app preferences

#### Logging
- unified logger and debug store

---

### 7.3 Layered architecture

Use these layers:

1. App/UI layer
2. View model / app state layer
3. Domain/service layer
4. Hardware abstraction layer
5. Persistence layer

The UI must not talk directly to raw backend code.

---

## 8. Top-level modules

The app should be organized into these modules.

### 8.1 App module
Responsibilities:
- app startup
- dependency injection
- window lifecycle
- root composition

Suggested files:
- `WebcamSettingsApp.swift`
- `AppContainer.swift`
- `AppDependencies.swift`

---

### 8.2 Device discovery module
Responsibilities:
- enumerate available cameras
- monitor add/remove events
- normalize identity fields

Suggested files:
- `DeviceDiscoveryService.swift`
- `CameraDeviceDescriptor.swift`
- `DeviceWatcher.swift`

---

### 8.3 Preview module
Responsibilities:
- start/stop preview
- expose preview surface
- isolate preview concerns from control concerns

Suggested files:
- `CameraPreviewService.swift`
- `PreviewSessionController.swift`
- `PreviewView.swift`

---

### 8.4 UVC control module
Responsibilities:
- fetch control capabilities
- read control values
- write control values
- expose normalized app-level control semantics

Suggested files:
- `CameraControlService.swift`
- `UVCCameraBackend.swift`
- `CameraControlCapability.swift`
- `CameraControlValue.swift`
- `CameraControlError.swift`

---

### 8.5 Capability mapping module
Responsibilities:
- map backend-specific selectors and metadata into app semantic controls

Suggested files:
- `ControlCapabilityMapper.swift`
- `ControlCatalog.swift`

---

### 8.6 Profile module
Responsibilities:
- save/update/delete/list profiles
- apply profiles
- device/profile matching
- startup profile handling

Suggested files:
- `ProfileService.swift`
- `CameraProfile.swift`
- `ProfileStore.swift`

---

### 8.7 Lifecycle/reapply module
Responsibilities:
- handle reconnect
- handle wake/sleep
- rebuild state after preview/device events
- reapply settings when configured

Suggested files:
- `LifecycleCoordinator.swift`
- `ProfileReapplyService.swift`
- `ApplyPlanBuilder.swift`

---

### 8.8 Preferences module
Responsibilities:
- app-level preferences
- startup and reapply settings
- debug visibility preferences

Suggested files:
- `PreferencesService.swift`
- `AppPreferences.swift`

---

### 8.9 Logging/debug module
Responsibilities:
- operation logs
- capability diagnostics
- control read/write result tracking
- lifecycle event tracking

Suggested files:
- `Logger.swift`
- `DebugStore.swift`
- `DebugEvent.swift`

---

## 9. Domain model

Use explicit domain types rather than loose dictionaries and strings.

### 9.1 CameraDeviceDescriptor
Represents one camera device.

Suggested fields:
- `id: String`
- `name: String`
- `manufacturer: String?`
- `model: String?`
- `transportType`
- `isConnected: Bool`
- `avFoundationUniqueID: String?`
- `backendIdentifier: String?`

---

### 9.2 CameraControlKey
Enum of semantic controls:
- `exposureMode`
- `exposureTime`
- `brightness`
- `contrast`
- `saturation`
- `sharpness`
- `whiteBalanceAuto`
- `whiteBalanceTemperature`
- `powerLineFrequency`
- `backlightCompensation`
- `focusAuto`
- `focus`
- `zoom`
- `pan`
- `tilt`

---

### 9.3 CameraControlType
Suggested cases:
- boolean
- integerRange
- floatRange
- enumSelection

---

### 9.4 CameraControlValue
Suggested cases:
- bool
- int
- double
- enumCase

---

### 9.5 CameraControlCapability
Represents:
- support
- readability
- writability
- min/max/step/default/current
- enum options
- dependency data

Suggested fields:
- `key`
- `displayName`
- `type`
- `isSupported`
- `isReadable`
- `isWritable`
- `minValue`
- `maxValue`
- `stepValue`
- `defaultValue`
- `currentValue`
- `enumOptions`
- `dependency`

---

### 9.6 ControlDependency
Represents enable/disable dependencies.

Examples:
- manual focus disabled when autofocus is on
- white balance temperature disabled when auto white balance is on
- exposure time disabled when exposure mode is not manual-compatible

---

### 9.7 CameraProfile
Represents a saved named set of device values.

Suggested fields:
- `id`
- `name`
- `deviceMatch`
- `values`
- `createdAt`
- `updatedAt`
- `loadAtStart`

---

### 9.8 ProfileDeviceMatch
Represents matching info for profile/device association.

Suggested fields:
- `deviceName`
- `deviceIdentifier`
- `manufacturer`
- `model`

---

## 10. Service interfaces

Define protocol-based boundaries.

### 10.1 DeviceDiscoveryServicing
Responsibilities:
- fetch current devices
- observe changes

### 10.2 CameraPreviewServicing
Responsibilities:
- start preview
- stop preview

### 10.3 CameraControlServicing
Responsibilities:
- fetch capabilities
- read values
- write values
- refresh current state

### 10.4 ProfileServicing
Responsibilities:
- list/save/update/delete/load profiles

### 10.5 ProfileApplying
Responsibilities:
- apply a profile to a device
- return structured result

### 10.6 PreferencesServicing
Responsibilities:
- manage app-level settings such as startup profile and auto-reapply behavior

---

## 11. View-model architecture

Views should bind to view models, never directly to hardware/backends.

### Required view models
- `AppViewModel`
- `BasicTabViewModel`
- `AdvancedTabViewModel`
- `ProfilesViewModel`
- `PreferencesViewModel`

Responsibilities:
- UI state management
- capability-driven rendering state
- selected device state
- current control state
- profile list state
- status/error presentation

---

## 12. State model

Use one source of truth for current device and control state.

Suggested state partitions:

### DeviceState
- selected device
- availability
- connection state

### CapabilityState
- supported controls
- control metadata

### CurrentControlState
- last known values
- in-progress writes
- last per-control errors

### ProfileState
- available profiles
- selected profile
- startup profile choice

### UIState
- selected tab
- warnings/errors
- debug visibility

---

## 13. Hardware abstraction rules

This is a critical boundary.

### Rule 1
The UI layer must not know about raw UVC selectors or raw backend API details.

### Rule 2
The control service must expose semantic controls only.

### Rule 3
The backend adapter layer must translate semantic control keys into backend-specific operations.

### Rule 4
Preview and control logic must not be merged into one service.

---

## 14. Control write architecture

All hardware writes must go through a centralized write path.

### Requirements
- validate values before write
- serialize writes
- support read-after-write when appropriate
- log all write attempts and results
- update UI state only through the state/view-model path

### Recommended structure
- `ControlWriteCoordinator`
- `CameraControlActor` or equivalent serialized execution model

---

## 15. Profile apply ordering

Profiles must not be applied in arbitrary dictionary order.

### Required apply order

#### Stage 1
Auto/manual toggles:
- `whiteBalanceAuto`
- `focusAuto`

#### Stage 2
Exposure mode:
- `exposureMode`

#### Stage 3
Enum controls:
- `powerLineFrequency`

#### Stage 4
Dependent manual values:
- `exposureTime`
- `whiteBalanceTemperature`
- `focus`

#### Stage 5
Image controls:
- `brightness`
- `contrast`
- `saturation`
- `sharpness`
- `backlightCompensation`

#### Stage 6
PTZ:
- `zoom`
- `pan`
- `tilt`

Reason:
Auto modes may overwrite manual values if the order is wrong.

---

## 16. Error model

Use explicit error handling.

Suggested error cases:
- deviceNotConnected
- deviceBusy
- controlUnsupported
- controlReadFailed
- controlWriteFailed
- invalidValue
- backendFailure
- permissionDenied
- timedOut

Profile apply results should include:
- per-control success/failure
- skipped unsupported controls
- overall outcome
- messages for diagnostics

---

## 17. Threading and concurrency

The UI must remain responsive.

### Requirements
- UI updates on main actor
- hardware/device operations off the main thread
- serialized control writes
- no overlapping conflicting writes

### Recommended approach
Use a dedicated actor or serial queue for hardware control operations.

---

## 18. UI composition

### Main window
- device selector at top
- tab content in center
- profile manager at bottom
- status banner/debug access

### Reusable controls
Build generic components such as:
- slider row
- enum selector row
- auto-linked slider row
- profile manager bar
- status banner
- debug panel

Avoid duplicating control logic per tab.

---

## 19. Persistence design

### Profiles
Profiles should be stored in a structured format such as JSON.

Requirements:
- semantic control keys only
- portable and readable
- persistent across relaunch

### Preferences
Small app settings may use UserDefaults or equivalent.

Examples:
- startup profile ID
- auto-reapply flag
- show unsupported controls
- debug panel visibility

---

## 20. Debug and diagnostics

Debugging should be built in early, not bolted on later.

The debug panel/store should expose:
- selected device IDs
- capability inventory
- supported vs unsupported controls
- min/max/default/current values
- writable/readable status
- last write attempts
- last read results
- profile apply results
- reconnect/lifecycle event log

---

## 21. Suggested project structure

```text
WebcamSettings/
  App/
    WebcamSettingsApp.swift
    AppContainer.swift
    AppDependencies.swift

  Domain/
    Models/
      CameraDeviceDescriptor.swift
      CameraControlKey.swift
      CameraControlType.swift
      CameraControlValue.swift
      CameraControlCapability.swift
      ControlDependency.swift
      CameraProfile.swift
      ProfileDeviceMatch.swift
    Errors/
      CameraControlError.swift
    Protocols/
      DeviceDiscoveryServicing.swift
      CameraPreviewServicing.swift
      CameraControlServicing.swift
      ProfileServicing.swift
      PreferencesServicing.swift
      ProfileApplying.swift

  Services/
    DeviceDiscovery/
      DeviceDiscoveryService.swift
      DeviceWatcher.swift
    Preview/
      CameraPreviewService.swift
      PreviewSessionController.swift
    Controls/
      CameraControlService.swift
      ControlCapabilityMapper.swift
      ControlWriteCoordinator.swift
      CameraControlActor.swift
    Profiles/
      ProfileService.swift
      ProfileStore.swift
      ProfileApplyCoordinator.swift
      ApplyPlanBuilder.swift
    Lifecycle/
      LifecycleCoordinator.swift
    Preferences/
      PreferencesService.swift
    Debug/
      Logger.swift
      DebugStore.swift

  Backends/
    UVC/
      UVCCameraBackend.swift
      UVCControlAdapter.swift
      RawUVCBindings.swift
    Preview/
      AVFoundationPreviewBackend.swift

  ViewModels/
    AppViewModel.swift
    BasicTabViewModel.swift
    AdvancedTabViewModel.swift
    ProfilesViewModel.swift
    PreferencesViewModel.swift

  Views/
    MainWindowView.swift
    Tabs/
      BasicTabView.swift
      AdvancedTabView.swift
      PreferencesTabView.swift
    Components/
      SliderControlRow.swift
      EnumSelectorRow.swift
      AutoLinkedSliderRow.swift
      ProfileManagerBar.swift
      StatusBanner.swift
      DebugPanel.swift

  Persistence/
    JSONProfileStore.swift

  Tests/
    Unit/
    Mocks/
    Integration/
    
## 22\. Build checklist

The coding agent should implement the project in phases.

### Phase 0 — project setup

Tasks:

*   create Swift + SwiftUI macOS project
    
*   create folder structure
    
*   create dependency injection scaffold
    
*   create logger scaffold
    
*   compile placeholder app shell
    

Validation:

*   clean build
    
*   no backend code in views
    

* * *

### Phase 1 — domain model and protocols

Tasks:

*   implement all core models
    
*   implement service protocols
    
*   implement typed errors
    
*   create placeholder mocks
    

Validation:

*   domain layer compiles independently
    
*   semantic control keys are typed
    

* * *

### Phase 2 — device discovery

Tasks:

*   implement camera discovery
    
*   device selection list
    
*   connect/disconnect monitoring
    

Validation:

*   device list updates on plug/unplug
    
*   no crash on device loss
    

* * *

### Phase 3 — preview pipeline

Tasks:

*   implement AVFoundation preview service
    
*   connect preview to selected device
    
*   support start/stop on device change
    

Validation:

*   LifeCam preview opens
    
*   switching devices does not require app restart
    

* * *

### Phase 4 — raw control backend scaffold

Tasks:

*   create backend abstraction
    
*   create capability/read/write method stubs
    
*   isolate backend behind adapter
    
*   add logging to backend calls
    

Validation:

*   backend failures produce typed errors
    
*   app remains stable with unsupported operations
    

* * *

### Phase 5 — capability discovery and mapping

Tasks:

*   fetch control capabilities
    
*   map backend info into semantic controls
    
*   capture current/min/max/default/step/options
    
*   define dependency rules
    

Validation:

*   LifeCam control inventory is visible in app state
    
*   unsupported controls do not crash rendering
    

* * *

### Phase 6 — app state and selection coordination

Tasks:

*   implement `AppViewModel`
    
*   implement camera selection coordination
    
*   wire preview + capabilities + current values + profiles into one selection flow
    

Validation:

*   selecting a device loads preview and controls together
    
*   stale state is cleared on device change
    

* * *

### Phase 7 — reusable UI control components

Tasks:

*   build slider row
    
*   build enum selector row
    
*   build auto-linked slider row
    
*   build status banner
    

Validation:

*   reusable components work consistently
    
*   no duplicated tab-specific control logic
    

* * *

### Phase 8 — Basic tab implementation

Tasks:

*   implement Basic tab view model and UI
    
*   wire live control writes for:
    
    *   exposure mode
        
    *   exposure time
        
    *   brightness
        
    *   contrast
        
    *   saturation
        
    *   sharpness
        
    *   white balance auto
        
    *   white balance temperature
        

Validation:

*   visible image changes confirm controls are working
    
*   dependencies enable/disable correctly
    

* * *

### Phase 9 — serialized write pipeline

Tasks:

*   implement control write coordinator
    
*   serialize hardware writes
    
*   validate write inputs
    
*   add read-after-write if needed
    
*   track per-control errors
    

Validation:

*   rapid writes do not corrupt state
    
*   failed writes are recoverable and visible
    

* * *

### Phase 10 — Advanced tab implementation

Tasks:

*   implement Advanced tab view model and UI
    
*   wire:
    
    *   power line frequency
        
    *   backlight compensation
        
    *   focus auto
        
    *   focus
        
    *   zoom
        
    *   pan
        
    *   tilt
        

Validation:

*   advanced controls work when supported
    
*   autofocus/focus dependency works
    
*   supported enum options match actual device capability
    

* * *

### Phase 11 — profile persistence

Tasks:

*   implement profile serialization
    
*   implement JSON profile store
    
*   implement save/update/delete/list/load
    

Validation:

*   profiles persist across relaunch
    
*   profiles use semantic keys
    

* * *

### Phase 12 — ordered profile application

Tasks:

*   implement apply plan builder
    
*   implement ordered profile apply coordinator
    
*   skip unsupported controls safely
    
*   log per-control result
    

Validation:

*   loading a saved LifeCam profile restores settings as expected
    
*   partial applies are visible, not silent
    

* * *

### Phase 13 — startup preferences and auto-load

Tasks:

*   implement app preferences
    
*   wire startup profile selection
    
*   add auto-load and auto-reapply settings
    

Validation:

*   relaunch loads configured startup profile when enabled
    
*   missing profile/device fails gracefully
    

* * *

### Phase 14 — lifecycle and reconnect handling

Tasks:

*   implement reconnect handling
    
*   implement wake/sleep recovery
    
*   re-fetch preview/capabilities/current state
    
*   reapply selected profile if configured
    

Validation:

*   unplug/replug recovery works
    
*   sleep/wake recovery works
    
*   no stale sessions or duplicate preview pipelines
    

* * *

### Phase 15 — debug panel and diagnostics

Tasks:

*   implement debug store
    
*   expose diagnostics in UI
    
*   include capability and write/apply/lifecycle logs
    

Validation:

*   debug panel helps identify control failures without code edits
    

* * *

### Phase 16 — polish and hardening

Tasks:

*   improve errors and status messaging
    
*   remove duplication
    
*   refine disabled states
    
*   stabilize layout
    
*   confirm architecture remains clean
    

Validation:

*   app remains usable even with partial backend failures
    

* * *

### Phase 17 — testing

Tasks:

*   unit tests
    
*   mock service tests
    
*   manual hardware tests
    

Manual validation targets:

*   preview works
    
*   all currently working controls are exposed
    
*   live writes work
    
*   profile save/load works
    
*   startup load works
    
*   reconnect/wake recovery works
    

* * *

## 23\. Acceptance criteria

The project is successful when the following are true on the target Mac with the LifeCam Studio:

1.  The device appears in the selector.
    
2.  Live preview works reliably.
    
3.  All currently working controls shown in the old app are exposed.
    
4.  Control values reflect actual current device state.
    
5.  Live edits affect the camera.
    
6.  Auto/manual dependency behavior works correctly.
    
7.  Profiles can be saved, loaded, updated, and deleted.
    
8.  Startup profile loading works.
    
9.  Reconnect/reapply works.
    
10.  The codebase remains modular and maintainable.
    

* * *

## 24\. Implementation rules for the coding agent

The coding agent must follow these rules:

1.  Do not let SwiftUI views call raw backend code.
    
2.  Do not merge preview and control logic into one service.
    
3.  Do not hardcode LifeCam-only assumptions into the UI rendering path.
    
4.  Do not store profiles using display labels.
    
5.  Do not apply profiles in arbitrary dictionary order.
    
6.  Serialize hardware writes.
    
7.  Add debug logging early.
    
8.  Treat reconnect and lifecycle resilience as first-class concerns.
    
9.  Keep backend-specific details behind adapters/protocols.
    
10.  Prefer maintainable structure over fast scaffolding shortcuts.
    

* * *

## 25\. Recommended repository setup

Suggested initial repo contents:

*   `README.md`
    
*   `docs/master-project-spec.md`
    

Optional later additions:

*   `docs/testing-notes.md`
    
*   `docs/device-observations-lifecam-studio.md`
    

* * *

## 26\. Recommended coding-agent workflow

Best workflow:

1.  Create the GitHub repo first.
    
2.  Add this file as `docs/master-project-spec.md`.
    
3.  Add `docs/session-handoff-prompt.md`.
    
4.  Then give the coding agent the session handoff prompt.
    
5.  Keep the repo as the durable source of truth across sessions.
    

* * *

## 27\. Final note

This project should be built as a **stable utility app with a clean internal architecture**, not as a throwaway prototype. The main value is not only replacing the old app, but also creating a maintainable foundation that can keep working as macOS and hardware conditions evolve.    