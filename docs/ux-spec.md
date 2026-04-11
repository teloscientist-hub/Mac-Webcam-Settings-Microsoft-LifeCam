# UX Specification — macOS Webcam Settings Replacement

## 1. Purpose

Define the user experience, screen structure, interaction behavior, layout rules, and interface components for the macOS webcam settings app.

This document governs the product-facing interface. It should be used alongside `docs/master-project-spec.md`.

This UX should feel like a compact, stable macOS utility:
- simple
- fast
- low-friction
- easy to understand at a glance
- optimized for repeated use with one primary camera

The app is not a creative media suite. It is a practical control console.

---

## 2. Primary user goal

The user wants to:

1. select a webcam
2. see a live preview
3. adjust image and camera controls quickly
4. save those settings as a named profile
5. restore those settings later without rebuilding them manually
6. recover easily after reconnect, relaunch, or sleep/wake

The interface should optimize for speed, confidence, and repeatability.

---

## 3. UX principles

### 3.1 Utility-first
The interface should prioritize clarity and function over visual flourish.

### 3.2 Immediate feedback
When the user changes a setting, the app should respond immediately and visibly whenever possible.

### 3.3 Low cognitive load
The user should not need to hunt for controls or infer hidden state.

### 3.4 Capability-driven clarity
Only show controls that exist for the selected device, unless the user explicitly enables a debug view for unsupported controls.

### 3.5 Stable mental model
The layout should remain consistent across devices and sessions.

### 3.6 Reduced friction
Common actions should require minimal clicks:
- open app
- choose profile
- adjust setting
- save/update profile

### 3.7 Graceful failure
If a control cannot be written or a device disconnects, the app should fail visibly but calmly, without breaking the whole interface.

---

## 4. Primary window structure

The app should use a single main utility window.

### Window regions

#### Top bar
Contains:
- device selector
- connection/status indicator
- optional refresh/reconnect action

#### Main content area
Split into two vertical columns:

**Left column**
- live camera preview
- optional preview overlay/status

**Right column**
- tabbed controls:
  - Basic
  - Advanced
  - Preferences

#### Bottom bar
Contains:
- profile selector
- Save New Profile
- Update Profile
- Delete Profile
- Load at Start toggle

---

## 5. Default layout

### 5.1 Overall window proportions
Default layout should feel like a compact desktop utility window, approximately:
- medium width
- enough height to show preview and controls without excessive scrolling on a common laptop screen

Suggested behavior:
- preview occupies roughly 40–50% of horizontal space
- controls occupy roughly 50–60%

### 5.2 Resizing
The window may be resizable, but the layout should degrade gracefully:
- preview shrinks but remains visible
- controls remain readable
- bottom profile bar remains fixed and usable

### 5.3 Scrolling
Tabs may scroll vertically if needed, but the default layout should minimize scrolling for the primary target device.

---

## 6. Top bar UX

### 6.1 Device selector
A dropdown at top left or top center.

Behavior:
- shows currently selected device name
- lists detected devices
- selecting a new device refreshes preview and controls
- if only one device exists, still show selector for consistency

### 6.2 Connection indicator
Small status indicator beside or near device selector.

States:
- Connected
- Loading
- Disconnected
- Device Busy
- Partial Control Access

Indicator style should be subtle but visible.

### 6.3 Refresh/reconnect action
A small button or icon may appear near the device selector.

Purpose:
- manually refresh device state
- re-query capabilities/current values
- recover from partial control desync

This action should not be visually dominant.

---

## 7. Preview panel UX

### 7.1 Purpose
The preview is the user’s primary feedback surface.

### 7.2 Behavior
- shows live feed from selected camera
- updates continuously
- should remain active while adjusting controls

### 7.3 Preview chrome
The preview panel should be visually simple:
- rounded macOS-style container
- subtle border or card background
- no unnecessary overlays in normal use

### 7.4 Optional overlay information
Small overlay or footer line may show:
- selected device name
- resolution if available
- status messages like “Reapplying profile…”

Overlay must remain lightweight and non-distracting.

### 7.5 Empty states
If no camera is selected or available:
- show a clean placeholder
- message example:
  - “No camera selected”
  - “Camera disconnected”
  - “Preview unavailable”

No noisy warning style unless the state is actually an error.

---

## 8. Tabs and navigation UX

The app uses three tabs:

- Basic
- Advanced
- Preferences

These should appear as a segmented control or native tab selector near the top of the control column.

Behavior:
- tabs switch instantly
- selected tab remains remembered during session
- tab content should not reset unnecessarily when switching

---

## 9. Basic tab UX

The Basic tab is the default tab on launch.

It should contain the most commonly used image controls.

### Sections
- Exposure
- Image
- White Balance

### Section design
Each section should appear as a clean grouped panel with:
- section title
- rows for each control
- consistent spacing

### Control rows in Basic
- Exposure Mode
- Exposure Time
- Brightness
- Contrast
- Saturation
- Sharpness
- Auto White Balance
- White Balance Temperature

### Interaction rules
- value changes apply live
- disabled dependent controls are still visible but dimmed
- numeric value is always visible next to the slider where practical

### Exposure Mode UI
Use a dropdown or segmented selector depending on available options.

### Slider rows
Each slider row should include:
- label
- slider
- numeric value field or value label
- disabled state when necessary

---

## 10. Advanced tab UX

The Advanced tab contains secondary or less frequently adjusted camera controls.

### Sections
- Lighting
- Focus
- PTZ

### Controls
- Power Line Frequency
- Backlight Compensation
- Autofocus
- Focus
- Zoom
- Pan
- Tilt

### Power Line Frequency UI
Use a segmented control or dropdown, depending on how many supported options are returned.

### Focus UX
- Autofocus is a toggle
- Focus slider stays visible
- Focus slider is disabled when autofocus is on

### PTZ UX
Use slider rows for:
- Zoom
- Pan
- Tilt

These should appear only when supported.

If unsupported:
- hide by default
- optionally show in disabled form only in debug mode

---

## 11. Preferences tab UX

The Preferences tab contains app behavior, not image tuning controls.

### Suggested settings
- Load selected profile at startup
- Auto-reapply on reconnect
- Auto-reapply after wake
- Show unsupported controls
- Show debug panel

### Presentation
Use standard macOS toggle rows and simple dropdowns where needed.

This tab should feel quieter and simpler than the Basic and Advanced tabs.

---

## 12. Profile bar UX

The profile system is central to the workflow.

### Profile bar placement
Bottom of main window, fixed position.

### Contents
- profile selector dropdown
- Save New Profile button
- Update Profile button
- Delete Profile button
- Load at Start toggle

### Behavior
- profile selector shows available profiles for current device first
- selecting a profile does not necessarily auto-apply unless that behavior is explicitly chosen
- loading a profile should be a clear, deliberate action unless auto-load is enabled

### Save New Profile
Opens a simple naming flow:
- text input
- confirm save
- cancel

### Update Profile
Updates currently selected profile with current values.

Should be disabled when no profile is selected.

### Delete Profile
Requires a lightweight confirmation.

### Load at Start
A simple checkbox or toggle associated with the selected profile.

---

## 13. Status and feedback UX

### 13.1 Inline status
Use lightweight status lines rather than intrusive modal dialogs whenever possible.

Examples:
- “Profile applied”
- “Camera reconnected”
- “Focus write failed”
- “3 controls skipped”

### 13.2 Error severity levels
Use three levels:

#### Informational
Example:
- “Refreshing device state”

#### Warning
Example:
- “Some controls are unavailable for this camera”

#### Error
Example:
- “Could not write Focus value”

### 13.3 Display pattern
Prefer:
- inline banners
- row-level status
- bottom status line

Avoid modal alerts unless the action is destructive or unrecoverable.

---

## 14. Control row behavior

All control rows should follow consistent patterns.

### 14.1 Toggle row
Contains:
- label
- toggle
- optional help text

Used for:
- autofocus
- auto white balance
- load at start
- auto-reapply options

### 14.2 Slider row
Contains:
- label
- slider
- numeric value display or field
- optional reset behavior later

Used for:
- brightness
- contrast
- saturation
- sharpness
- exposure time
- white balance temperature
- focus
- zoom
- pan
- tilt
- backlight compensation

### 14.3 Enum row
Contains:
- label
- dropdown or segmented control

Used for:
- exposure mode
- power line frequency

### 14.4 Disabled state
Disabled controls should:
- remain visible if logically linked to an auto toggle
- be clearly dimmed
- still show their current value if possible

Reason:
The user should understand why they cannot edit the control.

---

## 15. UX behavior for dependencies

### 15.1 Focus
When autofocus is enabled:
- Focus remains visible
- Focus slider becomes disabled
- optional helper text: “Manual focus disabled while autofocus is on”

### 15.2 White balance
When auto white balance is enabled:
- White Balance Temperature remains visible
- slider becomes disabled

### 15.3 Exposure
When exposure mode is not manual-compatible:
- Exposure Time remains visible
- control becomes disabled

These dependencies should be obvious from the interface.

---

## 16. Empty, loading, and reconnect states

### 16.1 Initial loading
Show:
- preview placeholder
- subtle spinner or loading text
- controls either skeleton-loaded or temporarily disabled

### 16.2 No device
Show:
- “No compatible camera found”
- device selector empty or disabled
- rest of interface disabled but visible

### 16.3 Device disconnected
Show:
- connection banner
- preview placeholder
- controls disabled
- profile bar remains visible

### 16.4 Reconnect in progress
Show non-blocking message:
- “Reconnecting to camera…”
- “Reapplying profile…”

The user should understand what is happening without being blocked by a modal.

---

## 17. Debug UX

Debug UI should exist, but stay out of normal use by default.

### 17.1 Access
Debug panel shown only when enabled from Preferences.

### 17.2 Contents
May include:
- selected device identifiers
- supported controls
- min/max/default/current
- last write results
- last profile apply result
- lifecycle event log

### 17.3 Presentation
Use collapsible sections or a drawer-like panel.

It should not dominate the main UI.

---

## 18. Visual style guidance

### 18.1 General style
- native macOS feel
- clean spacing
- soft grouping
- minimal ornamentation

### 18.2 Tone
The UI should feel:
- reliable
- calm
- technical but approachable

### 18.3 Avoid
- flashy gradients
- dense developer-only visuals in normal mode
- oversized buttons
- consumer-photo-app aesthetics

---

## 19. Default launch behavior

On launch, the app should:
1. restore last selected device if still available
2. show Basic tab by default
3. restore preview
4. load selected startup profile if enabled
5. show concise status if profile application occurs

This should feel automatic and stable.

---

## 20. Primary user flows

### Flow 1 — quick adjustment
1. Open app
2. Preview appears
3. Adjust brightness/contrast/etc.
4. Changes apply live

### Flow 2 — save profile
1. Adjust camera
2. Click Save New Profile
3. Name profile
4. Save
5. Profile becomes selectable

### Flow 3 — restore profile
1. Open app
2. Select profile
3. Apply or auto-load occurs
4. Status confirms result

### Flow 4 — reconnect recovery
1. Camera disconnects or sleep/wake occurs
2. App shows reconnecting state
3. Preview returns
4. Profile re-applies if configured
5. Status confirms partial or full recovery

---

## 21. UX acceptance criteria

The UX is successful if:

1. A first-time user can identify the device selector, preview, controls, and profile actions immediately.
2. The difference between Basic and Advanced controls is obvious.
3. Auto/manual dependencies are understandable without documentation.
4. The user can save and reload a profile without confusion.
5. Errors are visible but not disruptive.
6. Reconnect and recovery states are understandable.
7. The app feels like a compact utility, not an unfinished dev tool.

---

## 22. Non-goals for UX v1

This UX does not need:
- a full design system
- marketing-level polish
- multiple windows
- advanced visual theming
- onboarding walkthroughs
- elaborate animations

The goal is a robust, clean utility interface.
