# LED Controller Gap Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the highest-priority gaps from the Flutter design review by adding device-list status refresh and completing pairing retry/recovery states.

**Architecture:** Extend the existing Riverpod + controller structure instead of introducing a new state-management layer. Reuse `UdpClient` and `UdpLedProtocol` for batch status refresh on the list page, and extend the pairing controller/page with an explicit `sendingConfig` step plus recovery actions that keep user input intact.

**Tech Stack:** Flutter, Riverpod, widget tests, unit tests, integration-friendly fake repositories/UDP clients

---

### Task 1: Device List Refresh

**Files:**
- Modify: `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart`
- Modify: `mobile_app/led_controller/lib/features/devices/application/device_list_controller.dart`
- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`

- [ ] Add failing tests for list item status/timestamp display and manual refresh behavior.
- [ ] Run the targeted widget test file and confirm the new expectations fail for the right reason.
- [ ] Implement a list refresh controller/service path that requests `status` for each saved device, persists the resulting status/timestamp, and keeps partial failures isolated per device.
- [ ] Update the list UI to show status, last sync time, and a visible refresh trigger.
- [ ] Re-run the targeted widget test file until green.

### Task 2: Pairing Sending/Retry Recovery

**Files:**
- Modify: `mobile_app/led_controller/test/features/pairing/application/pairing_controller_test.dart`
- Modify: `mobile_app/led_controller/test/features/pairing/presentation/pairing_page_test.dart`
- Modify: `mobile_app/led_controller/lib/features/pairing/domain/pairing_step.dart`
- Modify: `mobile_app/led_controller/lib/features/pairing/application/pairing_controller.dart`
- Modify: `mobile_app/led_controller/lib/features/pairing/presentation/pairing_page.dart`

- [ ] Add failing tests for the explicit `sendingConfig` step, retrying config submission in place, and continuing the reconnect wait after a reconnect timeout.
- [ ] Run the targeted pairing test files and confirm the new expectations fail.
- [ ] Implement the minimal controller state transitions and page actions to satisfy the new tests while preserving entered SSID/password.
- [ ] Re-run the targeted pairing test files until green.

### Task 3: Regression Verification

**Files:**
- Modify: none expected

- [ ] Run the focused Flutter test files touched by Tasks 1 and 2.
- [ ] Run the full `flutter test` suite for `mobile_app/led_controller`.
- [ ] Note any integration-test limitations in the final handoff if no device is attached.
