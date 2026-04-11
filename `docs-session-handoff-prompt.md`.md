
# `docs/session-handoff-prompt.md`

```md
# Session Handoff Prompt

Paste the following into Codex or Claude after the repo exists and `docs/master-project-spec.md` is in place.

---

Read `docs/master-project-spec.md` first and treat it as the governing implementation specification for this repository.

Your job is to build a native macOS desktop app in Swift and SwiftUI that replaces the old “Webcam Settings” utility for the Microsoft LifeCam Studio.

This is a functional replacement, not a code clone.

Build the project in phases, following the architecture, module boundaries, domain model, build checklist, and implementation rules in `docs/master-project-spec.md`.

Critical constraints:
- keep preview logic separate from camera control logic
- keep UI separate from raw backend code
- use capability-driven control rendering
- use semantic control keys and typed values
- serialize all hardware writes
- implement ordered profile application
- treat reconnect, relaunch, and sleep/wake resilience as first-class requirements
- add debug logging and diagnostics early

Required control inventory target:

## Basic tab
- exposureMode
- exposureTime
- brightness
- contrast
- saturation
- sharpness
- whiteBalanceAuto
- whiteBalanceTemperature

## Advanced tab
- powerLineFrequency
- backlightCompensation
- focusAuto
- focus
- zoom
- pan
- tilt

Execution instructions:
1. scaffold the project structure first
2. implement in the phased order defined in `docs/master-project-spec.md`
3. after each major phase, summarize:
   - what was completed
   - what remains
   - blockers or uncertainties
   - any backend-specific issues that were isolated behind adapters
4. do not shortcut the architecture for speed
5. keep code maintainable and production-oriented

If backend-specific UVC control access is uncertain, isolate that uncertainty behind the backend adapter layer rather than contaminating the rest of the app.

Goal:
Produce a maintainable v1 macOS app that can preview the LifeCam Studio, expose the currently working controls, save/load profiles, and reliably reapply settings after reconnect or relaunch.