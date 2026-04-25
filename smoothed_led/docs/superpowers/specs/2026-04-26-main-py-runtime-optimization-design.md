# `main.py` Runtime Optimization Design

Date: 2026-04-26
Project: `smoothed_led`
Target: `main.py` on ESP8266 NodeMCU running MicroPython

## Goal

Optimize the existing `main.py` runtime for lower memory pressure and lower CPU overhead on ESP8266 without adding features.

## Confirmed Constraints

- Keep `main.py` as the primary single-file runtime.
- Do not add new user-facing features.
- Keep UDP control/config behavior unchanged from the caller's perspective.
- Keep the same ports, commands, and effect names.
- Animation visuals may change slightly if needed for better memory or runtime behavior.
- Prefer changes that improve long-running stability on limited ESP8266 memory.

## Non-Goals

- No protocol redesign.
- No multi-file runtime refactor.
- No new persistence format.
- No async, threading, or task scheduler changes.
- No mobile app changes.

## Recommended Approach

Use a targeted single-file runtime refactor inside `main.py`.

This approach keeps the existing boot flow and external behavior, but rewrites hot paths so they allocate fewer temporary objects, perform fewer repeated lookups, and rely less on per-frame floating point and dynamic imports.

## Alternatives Considered

### 1. Conservative cleanup only

Examples:

- Move dynamic imports to module scope.
- Reuse static strings.
- Reduce repeated `split()` calls.

Pros:

- Lowest risk.

Cons:

- Leaves the main performance and fragmentation hotspots in place.
- Likely not enough improvement for long-running ESP8266 use.

### 2. Targeted single-file optimization

Examples:

- Rewrite hot animation loops to reduce temporary allocations.
- Replace per-frame rebuilt constants with module-level constants.
- Narrow exception scopes around network I/O.
- Simplify command parsing to reduce transient string/list objects.

Pros:

- Best balance of runtime gain, maintainability, and low deployment impact.

Cons:

- Slightly more internal restructuring than a minimal cleanup.
- Some animations may have minor visual differences.

### 3. Aggressive runtime redesign

Examples:

- Rebuild animation and socket handling around a lower-level state machine.

Pros:

- Highest theoretical performance ceiling.

Cons:

- Harder to reason about.
- Higher regression risk.
- Too invasive for an optimization-only change.

## High-Level Design

### Runtime boundaries

Keep the existing top-level runtime split:

- `main()` initializes hardware and chooses mode.
- `try_wifi()` decides whether the device enters control mode or config mode.
- `control_mode()` handles UDP control commands and animation refresh.
- `config_mode()` handles AP setup, UDP config commands, and WiFi list broadcast.

### Optimization focus areas

1. Animation loop hot paths
2. Command parsing and response generation
3. WiFi/config loop memory behavior
4. Garbage collection timing

## Animation Design

### State model

Keep the existing top-level state variables:

- `mode`
- `brightness`
- `frame_count`
- `anim_state`

Internal changes:

- Keep `anim_state` as the single animation-specific container.
- Normalize it to a small, predictable set of keys per effect instead of ad hoc dictionary shapes that grow and change over time.
- Reset only the minimum required state during mode switches.

### Hot-path optimization rules

Each animation function should:

- Write LED values directly to `np`
- Update only the state it owns
- Avoid constructing lists or tuples inside tight loops unless unavoidable
- Avoid repeated global lookups where a local alias is enough
- Avoid dynamic imports

### Planned animation-specific changes

#### `rainbow()`

- Keep the same overall effect.
- Reduce repeated global lookups and repeated arithmetic where practical.

#### `breath()`

- Preserve the current state-machine style.
- Keep only the minimum state fields needed for step, direction, and cycle count.

#### `fire()`, `starry()`, `sparkle()`

- Move color palettes to module-level constants.
- Keep random behavior, but avoid rebuilding color lists every frame.

#### `wave()`

- Remove per-iteration dynamic `__import__('math')`.
- Prefer a module-level import or a lighter approximation if it materially reduces overhead.
- Minor visual deviation is acceptable if the effect still reads as a flowing wave.

#### `chase()`

- Replace list comprehensions used only for transient scaling.
- Compute scaled RGB values directly with integers.

#### `snake()`

- Replace the append/pop moving list approach with a lighter fixed-shape state representation if possible.
- Preserve the visible behavior category: moving snake, target point, direction changes, target reset when eaten.
- Minor visual differences are acceptable.

## Command Parsing Design

### Requirements

- Keep all current command words and reply formats.
- Keep support for:
  - `mode:<effect>`
  - `mode:next`
  - `mode:prev`
  - `bright:<0-255>`
  - `status`
  - `help`
- Keep config mode support for:
  - `config:SSID:PASSWORD`
  - `status`
  - `list`

### Internal parsing strategy

- Use prefix checks instead of broad repeated splitting.
- Split at most once or twice when needed.
- Keep static response strings and joined effect/help text as module-level constants.
- Avoid rebuilding help text and effect lists inside long-running loops.

## WiFi and Network Loop Design

### Control mode

Keep the current behavior:

- UDP socket on control port
- Receive command
- Process command
- Advance one animation frame

Internal changes:

- Narrow `try/except` blocks to actual socket and decode boundaries.
- Avoid using exceptions as a normal control path where a branch is sufficient.
- Keep animation dispatch behavior stable even when packets are absent.

### Config mode

Keep the current behavior:

- Disable STA mode
- Enable AP mode with the same SSID
- Listen on config UDP port
- Broadcast scanned SSIDs periodically

Internal changes:

- Reuse scan and broadcast data where possible.
- Avoid unnecessary message reconstruction.
- Keep scan retry behavior tolerant of transient failures.

## Memory Management Design

### Main principles

- Prefer module-level constants over per-frame temporary objects.
- Prefer integer math where it materially lowers cost.
- Avoid loop-local imports.
- Reduce repeated string formatting inside long-running loops.
- Keep garbage collection explicit but less noisy.

### Garbage collection strategy

Instead of collecting opportunistically in many unrelated places:

- Collect after command handling where it helps bound short-lived allocations.
- Collect after periodic config-mode work such as scanning/broadcast refresh if needed.
- Avoid placing `gc.collect()` in every inner path unless profiling shows it is necessary.

## Error Handling Design

- Keep I/O boundaries defensive: socket receive, decode, file read/write, WiFi scan/connect.
- Reduce bare `except:` usage where a narrower failure boundary is enough.
- Do not let malformed packets crash the runtime.
- Do not silently hide non-I/O logic errors inside the animation or command code unless the current behavior depends on it.

## Compatibility Expectations

The following must remain compatible:

- Ports `8888` and `8889`
- AP SSID `LED_Config`
- Existing command words
- Existing effect names
- Existing basic reply formats
- Existing boot decision flow: saved WiFi -> try control mode, otherwise config mode

The following may vary slightly:

- Exact animation timing feel within a small range
- Exact per-pixel wave/snake visual details
- Internal implementation structure

## Verification Plan

### Functional checks

1. Boot with valid `w.cfg` and verify the device enters control mode.
2. Boot without valid WiFi config and verify the device enters config mode.
3. Verify control commands still work:
   - `mode:<effect>`
   - `mode:next`
   - `mode:prev`
   - `bright:<value>`
   - `status`
   - `help`
4. Verify config commands still work:
   - `config:SSID:PASSWORD`
   - `status`
   - `list`
5. Verify all eight effects still run and remain switchable.

### Runtime quality checks

1. Confirm no immediate crashes or resets in either mode.
2. Confirm repeated mode switching does not obviously degrade responsiveness.
3. Confirm the optimized version does not introduce visibly worse frame stutter than the current baseline.

## Risks and Mitigations

### Risk: optimization changes visual identity too much

Mitigation:

- Only allow minor visual differences.
- Keep each effect's recognizable style intact.

### Risk: tightening exception handling exposes hidden bugs

Mitigation:

- Keep defensive boundaries around network and file I/O.
- Verify command handling and mode switching explicitly after refactor.

### Risk: memory savings are offset by new constants

Mitigation:

- Only hoist data that is reused frequently.
- Prefer compact constants and shared strings.

## Implementation Scope

This design is scoped for a single implementation plan focused on `main.py`.

The implementation should remain incremental:

1. Hoist constants and shared strings.
2. Simplify command parsing.
3. Optimize animation hot paths.
4. Tighten network loop behavior and GC timing.
5. Verify external behavior remains compatible.
