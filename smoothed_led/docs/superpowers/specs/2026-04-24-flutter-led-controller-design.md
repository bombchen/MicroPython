# Flutter LED Controller Design

Date: 2026-04-24

## 1. Goal

Build a Flutter Android app for controlling ESP8266 devices running the `smoothed_led` MicroPython firmware.

The app must cover two core jobs:

1. First-time device onboarding through the firmware's existing AP + UDP configuration flow.
2. Daily LAN control of registered devices through the firmware's existing UDP control commands.

This is a `v1` design for a publishable first release, not a prototype and not a near-production enterprise build.

## 2. Fixed Scope

### In scope

- Android-first release.
- Flutter app implementation.
- Semi-automatic onboarding flow.
- Multiple devices supported in a flat list.
- Device registration during successful onboarding.
- LAN-only control.
- Single-device control screen with medium-strength state feedback.
- Device rename and local record deletion.
- Help and troubleshooting content for onboarding and network issues.

### Out of scope

- iPhone-first behavior or iOS-specific onboarding guarantees.
- Automatic LAN device discovery.
- Manual IP entry.
- Device groups or rooms.
- Remote control over the internet.
- Scenes, favorites, or batch control.
- Color picker or custom color authoring.
- Firmware changes as part of this app `v1`.

## 3. Firmware Constraints

The design must match the current firmware behavior documented in `README.md`.

### Configuration mode

- Device exposes AP `LED_Config`.
- App must work with UDP port `8889`.
- Supported config commands:
  - `config:SSID:PASSWORD`
  - `status`
  - `list`

### Control mode

- Device listens on UDP port `8888`.
- Supported control commands:
  - `mode:<effect>`
  - `mode:next`
  - `mode:prev`
  - `bright:<0-255>`
  - `status`
  - `help`

### Supported effect set

- `rainbow`
- `breath`
- `fire`
- `starry`
- `wave`
- `chase`
- `sparkle`
- `snake`

## 4. Product Direction

The app follows a device-list-first information architecture.

Reasoning:

- It fits the chosen multi-device-without-groups scope.
- It keeps first-time onboarding contained in an explicit flow.
- It scales cleanly later if firmware capabilities expand.
- It avoids promising dashboard-level capabilities the firmware does not support yet.

## 5. Information Architecture

The app consists of four top-level areas:

1. Device List
2. Add Device Wizard
3. Device Control
4. Settings and Help

### 5.1 Device List

This is the default home screen.

Responsibilities:

- Show all registered devices.
- Show latest known online state.
- Show latest known IP if available.
- Show latest sync time.
- Provide entry to add a device.
- Provide navigation into a single device control screen.

Behavior:

- If no device exists, show a strong empty state with an onboarding CTA.
- If devices exist, show them in a flat list.
- No group, room, or dashboard abstraction in `v1`.

### 5.2 Add Device Wizard

This is a dedicated onboarding flow for first-time setup.

Responsibilities:

- Explain what the user is about to do.
- Guide the user to connect to `LED_Config`.
- Collect target WiFi credentials.
- Send the configuration over UDP.
- Wait for device reboot and network return.
- Register the device locally when onboarding succeeds.

### 5.3 Device Control

This is a single-device screen.

Responsibilities:

- Show device identity and connectivity state.
- Fetch current device state when entering the screen.
- Allow effect switching.
- Allow brightness changes.
- Support `next` and `prev` actions.
- Support manual refresh.
- Support rename and local delete.

### 5.4 Settings and Help

Responsibilities:

- Explain permissions and Android network behavior.
- Provide onboarding troubleshooting.
- Provide network troubleshooting.
- Provide app info and version info.

## 6. Key User Flows

### 6.1 First-Time Onboarding Flow

1. User opens app.
2. User sees empty state on Device List.
3. User taps `Add Device`.
4. App enters guided onboarding.
5. App explains that the device exposes `LED_Config`.
6. App opens Android WiFi settings or guided system handoff.
7. User connects to `LED_Config`.
8. User returns to app and confirms continuation.
9. App collects home WiFi SSID and password.
10. App sends `config:SSID:PASSWORD` to UDP `8889`.
11. App waits for reboot and network return.
12. App performs a pairing-scoped LAN resolution step to identify the newly onboarded device IP.
13. On success, app registers the device locally and returns to Device List.

### 6.2 Daily Control Flow

1. User opens Device List.
2. User taps a registered device.
3. App enters Device Control screen.
4. App requests `status`.
5. App renders current mode, brightness, and online state.
6. User sends mode or brightness commands.
7. App refreshes status after actions.
8. App surfaces success, timeout, or offline feedback.

## 7. Onboarding UX Design

The onboarding flow must be more explicit than a minimal wizard because Android WiFi handoff is the highest-risk interaction in `v1`.

### 7.1 Wizard Shape

Use a visible step-based guided task flow with progress states:

1. Prepare device
2. Connect to `LED_Config`
3. Return to app
4. Enter home WiFi
5. Wait for reboot and finish

### 7.2 UX Principles

- Do not pretend WiFi switching is fully automatic.
- Always show the current step and the next action.
- Give the user explicit buttons for system WiFi handoff and manual continuation.
- Keep the user in the flow after failures instead of ejecting them to the home screen.
- Preserve entered SSID where possible on retry.

### 7.3 Required Guidance Content

The wizard must explicitly explain:

- `LED_Config` may appear as a network without internet.
- Android may switch back to another network automatically.
- If `LED_Config` is missing, the device may already be connected elsewhere or not in config mode.
- Returning to the app after connecting to AP is expected and normal.

### 7.4 Failure Recovery

The wizard must handle these cases with specific recovery actions:

- Failed to connect to `LED_Config`
  - Action: stay on current step and allow reopening WiFi settings.
- Failed to send config command
  - Action: allow retry from the same form.
- Device did not return to LAN after reboot
  - Action: allow retry wait and allow restarting onboarding.

### 7.5 Pairing-Scoped Device Resolution

`v1` does not support generic LAN auto-discovery as a product feature, but onboarding still needs one narrow resolution step to capture the IP of the device that just rebooted.

Rule:

- After sending WiFi credentials and waiting for reboot, the app may perform a short-lived, pairing-scoped UDP broadcast probe on control port `8888`.
- The probe is only used inside an active onboarding session.
- The first valid device response received during that pairing session is treated as the newly onboarded device.
- The responding source IP becomes the stored `ipAddress` for the registered device.

This is not treated as general device discovery because:

- It is only triggered immediately after an explicit onboarding flow.
- It is bounded to a short pairing window.
- It does not scan or maintain a list of arbitrary LAN devices outside onboarding.

## 8. Device Control UX Design

The control page should be practical and aligned with current firmware capabilities.

### 8.1 Required Elements

- Device name
- Latest known IP
- Online/offline/timeout state
- Last sync time
- Current mode display
- Brightness slider
- Effect selector for all supported firmware effects
- `Previous effect`
- `Next effect`
- `Refresh status`
- Rename device
- Delete device record

### 8.2 Explicit Non-Goals

Do not include:

- Color editor
- Scene editor
- Group control
- Favorite presets
- Any control model not backed by firmware behavior

## 9. State Feedback Model

The app uses medium-strength feedback, not real-time syncing.

### Device List

- Refresh latest known state on entering the screen.
- Refresh after onboarding returns.
- Refresh on explicit user action.
- Do not run aggressive background polling.

### Device Control

- Request `status` when entering the screen.
- Refresh after each user control action.
- Surface `online`, `offline`, `sending`, and `timeout` states clearly.

This model is intentionally modest because the firmware uses UDP and does not provide reliable push state.

## 10. Data Model

### 10.1 Core Entities

#### LedDevice

- `id`
- `name`
- `ipAddress`
- `lastSeenAt`
- `lastKnownMode`
- `lastKnownBrightness`
- `connectionState`
- `createdAt`
- `updatedAt`

#### DeviceStatus

- `mode`
- `brightness`
- `connectionState`
- `updatedAt`

#### PairingSession

- `step`
- `targetSsid`
- `password`
- `errorType`
- `startedAt`

#### EffectMode

Enum containing:

- `rainbow`
- `breath`
- `fire`
- `starry`
- `wave`
- `chase`
- `sparkle`
- `snake`

## 11. App Architecture

Use a simple layered architecture that keeps UI, flow orchestration, protocol details, and storage separate.

### 11.1 Presentation

Contains pages, widgets, and view-level state binding.

Examples:

- Device List page
- Add Device wizard pages
- Device Control page
- Settings and help pages

### 11.2 Application

Contains use-case orchestration and flow coordination.

Examples:

- `PairingCoordinator`
- `DeviceRegistrationUseCase`
- `FetchDeviceStatusUseCase`
- `SendDeviceCommandUseCase`

### 11.3 Domain

Contains core models, enums, and repository/service interfaces.

Examples:

- `LedDevice`
- `DeviceStatus`
- `EffectMode`
- `PairingSession`

### 11.4 Infrastructure

Contains concrete implementations.

Examples:

- UDP transport
- Android platform/network integration
- Local persistence
- Logging implementation

### 11.5 Shared

Contains shared constants, result wrappers, error types, and reusable UI state enums.

## 12. State Management

Use a lightweight, explicit state management solution. `Riverpod` is the recommended default.

Reasoning:

- Good fit for Flutter app layering.
- Keeps device list state, onboarding state, and control state separate.
- Works well with async network actions and local persistence.

### 12.1 Required State Separation

- Device list state
- Pairing wizard state
- Device control state
- Settings/help state

### 12.2 Pairing State Machine

The pairing flow must be modeled explicitly as a state machine:

- `idle`
- `waitingApJoin`
- `wifiForm`
- `sendingConfig`
- `waitingReconnect`
- `success`
- `failure`

### 12.3 Device Control State

The control screen must distinguish:

- `loading`
- `ready`
- `sending`
- `timeout`
- `offline`

## 13. Networking Design

### 13.1 Pairing Transport

- Use UDP for configuration on port `8889`.
- Send configuration using the firmware command format exactly.
- Support status checks where useful during onboarding.

### 13.2 Control Transport

- Use UDP for control on port `8888`.
- Support `status`, `mode:*`, `mode:next`, `mode:prev`, and `bright:*`.

### 13.3 Pairing Resolution Transport

- After onboarding config is sent, the app may broadcast a short-lived `status` probe on UDP `8888`.
- A valid response during the active pairing window is used to resolve the device IP.
- If no valid response is received within the pairing timeout window, onboarding remains incomplete and recovery actions are shown.

### 13.4 Reliability Expectations

UDP is unreliable.

Therefore:

- Every critical action must have timeout behavior.
- The UI must not imply guaranteed delivery.
- Retry paths must be visible.
- Success must be based on response evidence when available.

## 14. Persistence Design

Persist the registered device list locally.

### Required stored fields

- Device identity
- User-defined name
- Latest known IP
- Latest known status snapshot
- Last sync time

### Persistence responsibilities

- Keep registered devices across app restarts.
- Support rename and delete.
- Update latest known state after successful status pulls.

## 15. Error Handling

Errors must be actionable, not just descriptive.

### 15.1 Onboarding Errors

- Cannot find `LED_Config`
- User did not switch networks successfully
- Config send timeout
- Device reboot timeout
- Device did not become reachable on LAN

Each must map to a next action such as:

- Retry current step
- Reopen WiFi settings
- Wait again
- Restart onboarding

### 15.2 Control Errors

- Device offline
- Device IP invalid or stale
- UDP command timeout
- Status read failure

Each must map to a next action such as:

- Refresh
- Return later
- Remove and re-onboard device if necessary

## 16. Permissions and Platform Concerns

Because `v1` is Android-first, the app must include explicit handling for:

- WiFi/network behavior explanations
- App foreground/background transitions during onboarding
- System settings handoff behavior
- Required permissions and why they are needed

The settings/help area must explain these behaviors in plain language.

## 17. Testing Strategy

### 17.1 Unit Tests

- Pairing state machine transitions
- UDP command formatting
- UDP response parsing
- Device persistence behaviors
- Effect mode mapping

### 17.2 Integration Tests

- Device registration flow
- Return from onboarding into Device List
- Control screen state transitions
- Error presentation for network failures

### 17.3 Manual Verification

Manual Android testing is required for:

- WiFi settings handoff
- Returning to app after network changes
- Config send over UDP `8889`
- Control send over UDP `8888`
- Device reboot and reconnection timing

## 18. Success Criteria

`v1` is successful when:

- A user can onboard a new ESP8266 device without external tools.
- A successfully onboarded device appears in the device list.
- A user can open a device control screen and reliably send supported commands on the same LAN.
- The app gives understandable feedback when onboarding or control fails.
- The product feels complete enough to publish as an Android first release.

## 19. Deferred Work

These are intentionally deferred beyond this design:

- Automatic discovery protocol
- Manual IP entry
- iOS-specific onboarding design
- Group and room model
- Scenes and presets
- Remote access architecture
- Firmware upgrades or firmware-side protocol redesign
