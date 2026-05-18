# Single-Device Scene Priority Design

Date: 2026-05-18

## Summary

This design deepens the single-device experience for `smoothed_led` by turning the current controller from a temporary effect switcher into a reusable ambient-light product centered around saved scenes.

The first milestone adds a complete device state model, persistent on-device scenes, scene-first mobile controls, and boot-time restoration of a preferred scene. It deliberately does not pursue WLED-style platform breadth such as multi-device sync, segments, web UI, or smart-home integrations.

## Context

The current project already supports:

- UDP WiFi provisioning over AP mode
- UDP control for effect mode changes
- UDP control for brightness changes
- A Flutter mobile app with device list, pairing, and single-device control

The current product gap is that the device cannot preserve or recall a meaningful lighting setup. It only exposes `mode` and `brightness`, so the user must repeatedly reconstruct preferred ambient states by hand.

For the target use case of daily ambient lighting, the most valuable WLED-inspired capability is not a larger effect catalog. It is a lightweight scene system built on top of a richer state model.

## Goals

- Make a single light strip feel like a reusable ambient-light product
- Let users save multiple named scenes and recall them with one tap
- Restore a predictable state on boot
- Keep the device protocol simple enough for ESP8266 + MicroPython
- Create a state model that can support future timers and scene automation

## Non-Goals

- Multi-device sync
- Segment or zone-based rendering
- Web UI
- MQTT, Home Assistant, or other smart-home integrations
- Large-scale effect expansion
- A full WLED-compatible JSON API

## Current Constraints

### Firmware

- Device firmware runs on ESP8266 with MicroPython
- Current control loop is built around a single global `mode`, `brightness`, `frame_count`, and `anim_state`
- Current UDP control protocol is text-based and intentionally small
- Current effect implementations contain hardcoded colors and effect characteristics

### Mobile App

- Mobile app assumes status only contains `mode`, `brightness`, and connection state
- Control UI is centered around direct effect switching instead of reusable scenes

## Proposed Solution

The first implementation milestone introduces:

- A richer single-device lighting state
- A persistent scene store on the device
- A scene-first control experience in the mobile app
- Boot restoration using a default scene or most recent state

The design keeps the existing UDP text protocol and extends it instead of replacing it with JSON.

## Device State Model

The device state will expand from two fields to a complete ambient-light snapshot:

- `power`
- `mode`
- `brightness`
- `primary_color`
- `secondary_color`
- `speed`
- `intensity`
- `scene_id`
- `scene_name`

### Semantics

- `power` controls whether LEDs should render light output at all
- `mode` selects the active effect renderer
- `brightness` remains a global output scalar
- `primary_color` is the main hue used by static and animated effects
- `secondary_color` is an accent or blend color for effects that support two-color composition
- `speed` controls animation rate where applicable
- `intensity` controls effect density, spread, contrast, or amplitude depending on the effect
- `scene_id` identifies the currently applied saved scene when the live state exactly matches one
- `scene_name` is optional metadata for UI display

## Scene Model

A scene is a named snapshot of the full device state.

Each scene contains:

- `id`
- `name`
- `power`
- `mode`
- `brightness`
- `primary_color`
- `secondary_color`
- `speed`
- `intensity`
- `is_default_on_boot`

### Limits

- Device stores `4` to `8` scenes
- Exact default should start at `4` for lower flash and parsing risk on ESP8266
- Scene names should remain short and ASCII-safe by default

This limit is intentional. The product goal is a compact set of reliable everyday scenes, not an unlimited library.

## Protocol Design

The existing UDP text protocol remains the transport. It is extended in two layers.

### State Commands

- `status`
- `power:on`
- `power:off`
- `mode:<effect>`
- `bright:<0-255>`
- `color1:<r>,<g>,<b>`
- `color2:<r>,<g>,<b>`
- `speed:<0-255>`
- `intensity:<0-255>`
- `apply:<scene_id>`

### Scene Commands

- `scene:list`
- `scene:save:<id>:<name>`
- `scene:load:<id>`
- `scene:delete:<id>`
- `scene:default:<id>`
- `scene:rename:<id>:<name>`

### Status Response

The status payload should expand from:

`MODE:<mode>;BRIGHT:<value>`

to a complete flat response, for example:

`POWER:1;MODE:wave;BRIGHT:180;COLOR1:255,160,80;COLOR2:0,0,0;SPEED:120;INTENSITY:160;SCENE:2`

### Protocol Rationale

- Flat text is easier to parse on MicroPython than a full JSON surface
- Existing app and firmware architecture can evolve incrementally
- The payload is still human-readable during debugging over UDP

## Device Persistence Design

The device should persist scene-related data in two files:

- `state.cfg`
- `scenes.cfg`

### `state.cfg`

Stores:

- current or last-restorable state
- default scene pointer
- optional last applied scene id

### `scenes.cfg`

Stores:

- saved scene entries

### Persistence Rules

Do not write flash on every slider movement. Persist only on explicit or infrequent actions:

- save scene
- rename scene
- delete scene
- set default scene
- optionally save last state during explicit power or scene transitions

### Boot Behavior

On boot:

1. Read `state.cfg`
2. If a default scene exists, load it
3. Else if a recent restorable state exists, restore it
4. Else fall back to built-in defaults

This makes startup deterministic and product-like.

## Effect Adaptation Strategy

The first milestone should not rewrite every effect. Instead, it should make the state model useful quickly by prioritizing a small set of effects.

### First Effects to Adapt

- a static solid-color mode
- `breath`
- `wave`
- `music`

These should read from:

- `primary_color`
- `secondary_color`
- `speed`
- `intensity`

### Deferred Effects

Effects with hardcoded palettes or behavior can remain partially fixed during the first pass:

- `fire`
- `starry`
- `chase`
- `sparkle`
- `snake`

They can be parameterized later once the state model and scene workflow are stable.

## Mobile App Design

The mobile experience should become scene-first rather than effect-first.

### Control Page Layout

Top to bottom:

- device status
- current scene summary
- scene cards or buttons
- power and brightness controls
- quick parameter controls
- effect picker
- save and scene-management actions

### Primary Interactions

- tapping a scene applies it immediately
- editing brightness or parameters creates a modified-unsaved state
- if the live state diverges from a saved scene, the UI indicates that the scene has been modified
- the user can save as a new scene or overwrite the current one
- the user can mark one scene as the boot default

### App State Changes

The mobile app must expand its internal device status model to match the new firmware fields. The UDP protocol adapter must parse and serialize the new commands and payloads.

## Implementation Scope

### Phase 1

- add expanded device state fields
- add solid-color mode
- add parameter commands and parsing
- add expanded status response
- add scene storage on device
- add scene list, save, load, rename, delete, and default selection
- restore default scene or last state on boot
- update Flutter data model and UDP protocol layer
- redesign device control page around scenes first

### Phase 2

- scene ordering
- recently used scenes
- scene previews or color swatches
- curated ambient presets such as warm white or candlelight
- timers that switch to scenes
- fade-out or nightlight behavior

### Explicitly Deferred

- device groups
- sync broadcasting
- segments
- web-based management
- home automation integrations

## Error Handling

### Firmware

- reject malformed commands with clear error responses
- clamp numeric values into valid ranges
- treat missing scene ids as recoverable errors rather than crashing
- ignore unsupported parameters on effects that do not yet use them

### App

- surface unreachable or timeout states without discarding local UI state
- preserve the user-visible draft when a save or apply fails
- distinguish between online state and parsing errors

## Testing Strategy

### Firmware

- unit-style validation for command parsing helpers where practical
- manual protocol tests for scene save, load, rename, delete, default, and reboot restore
- regression tests for existing WiFi provisioning and current basic controls

### Mobile App

- update protocol parser tests for expanded status payloads
- add controller tests for scene actions
- add widget tests for scene-first control UI states
- retain existing pairing and control flow coverage

## Risks

- ESP8266 flash and memory limits may require stricter scene count or shorter scene names
- Frequent state persistence could wear flash if not gated carefully
- Expanding the protocol without versioning could break older app or firmware builds if mixed
- Some current effects may not map cleanly to `speed` and `intensity` without follow-up tuning

## Mitigations

- start with a conservative scene count
- persist only on explicit scene management actions
- treat protocol expansion as a coordinated firmware and app release
- prioritize a small set of effects for true parameter support in phase 1

## Success Criteria

- User can save at least four named scenes on one device
- User can apply any saved scene with one tap
- Device restores a predictable scene or last state after reboot
- App clearly distinguishes saved scenes from unsaved modifications
- Existing WiFi provisioning and basic control reliability are preserved

## Recommendation

This project should adopt a scene-first roadmap rather than a WLED-style breadth roadmap. For the stated goal of deepening the single-device ambient-light experience, scenes, state persistence, and fast recall provide the highest product value with the lowest architectural disruption.
