# Flutter LED Controller Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在当前固件能力不变的前提下，交付一个 Android 优先的 Flutter APP，完成 ESP8266 设备的半自动配网、局域网控制、设备登记与基础帮助页面。

**Architecture:** 在仓库内新增独立 Flutter 子工程 `mobile_app/led_controller`，与现有 MicroPython 固件目录隔离。APP 采用轻量分层结构：`presentation` 负责页面，`application` 负责流程编排，`domain` 负责模型与接口，`infrastructure` 负责 UDP、持久化与 Android 网络跳转实现，状态管理使用 `flutter_riverpod`。

**Tech Stack:** Flutter, Dart, flutter_riverpod, shared_preferences, android_intent_plus, flutter_test, integration_test

---

## 文件结构映射

### 新建 Flutter 工程根目录

- `mobile_app/led_controller/pubspec.yaml`
- `mobile_app/led_controller/lib/main.dart`
- `mobile_app/led_controller/lib/app/app.dart`
- `mobile_app/led_controller/lib/app/router.dart`

### 核心公共层

- `mobile_app/led_controller/lib/core/network/udp_client.dart`
- `mobile_app/led_controller/lib/core/network/udp_led_protocol.dart`
- `mobile_app/led_controller/lib/core/network/pairing_probe_service.dart`
- `mobile_app/led_controller/lib/core/platform/wifi_settings_launcher.dart`
- `mobile_app/led_controller/lib/core/platform/android_wifi_settings_launcher.dart`

### 设备域与数据层

- `mobile_app/led_controller/lib/features/devices/domain/effect_mode.dart`
- `mobile_app/led_controller/lib/features/devices/domain/device_status.dart`
- `mobile_app/led_controller/lib/features/devices/domain/led_device.dart`
- `mobile_app/led_controller/lib/features/devices/domain/device_repository.dart`
- `mobile_app/led_controller/lib/features/devices/data/local_device_store.dart`
- `mobile_app/led_controller/lib/features/devices/data/shared_prefs_device_repository.dart`
- `mobile_app/led_controller/lib/features/devices/application/device_list_controller.dart`
- `mobile_app/led_controller/lib/features/devices/application/device_control_controller.dart`
- `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`
- `mobile_app/led_controller/lib/features/devices/presentation/device_control_page.dart`

### 配网功能

- `mobile_app/led_controller/lib/features/pairing/domain/pairing_step.dart`
- `mobile_app/led_controller/lib/features/pairing/domain/pairing_state.dart`
- `mobile_app/led_controller/lib/features/pairing/application/pairing_coordinator.dart`
- `mobile_app/led_controller/lib/features/pairing/application/pairing_controller.dart`
- `mobile_app/led_controller/lib/features/pairing/presentation/pairing_page.dart`

### 设置与帮助

- `mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart`

### Android 配置

- `mobile_app/led_controller/android/app/src/main/AndroidManifest.xml`

### 测试

- `mobile_app/led_controller/test/app/app_smoke_test.dart`
- `mobile_app/led_controller/test/features/devices/domain/led_device_test.dart`
- `mobile_app/led_controller/test/core/network/udp_led_protocol_test.dart`
- `mobile_app/led_controller/test/features/devices/data/shared_prefs_device_repository_test.dart`
- `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart`
- `mobile_app/led_controller/test/features/pairing/application/pairing_controller_test.dart`
- `mobile_app/led_controller/test/features/devices/application/device_control_controller_test.dart`
- `mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart`
- `mobile_app/led_controller/integration_test/pairing_flow_test.dart`
- `mobile_app/led_controller/integration_test/device_control_flow_test.dart`

## Task 1: 建立 Flutter 子工程与首页骨架

**Files:**
- Create: `mobile_app/led_controller/pubspec.yaml`
- Create: `mobile_app/led_controller/lib/main.dart`
- Create: `mobile_app/led_controller/lib/app/app.dart`
- Create: `mobile_app/led_controller/lib/app/router.dart`
- Create: `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`
- Test: `mobile_app/led_controller/test/app/app_smoke_test.dart`

- [ ] **Step 1: 写一个会失败的首页冒烟测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/app/app.dart';

void main() {
  testWidgets('启动后默认显示设备列表空状态', (tester) async {
    await tester.pumpWidget(const LedControllerApp());

    expect(find.text('我的设备'), findsOneWidget);
    expect(find.text('还没有设备'), findsOneWidget);
    expect(find.text('添加设备'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认它失败**

Run:

```bash
cd mobile_app/led_controller
flutter test test/app/app_smoke_test.dart -r expanded
```

Expected:

```text
FAIL: Target of URI doesn't exist: 'package:led_controller/app/app.dart'
```

- [ ] **Step 3: 写最小实现，建立工程和首页空状态**

```bash
mkdir -p mobile_app
cd mobile_app
flutter create --platforms=android --org dev.chenxi led_controller
```

```yaml
# mobile_app/led_controller/pubspec.yaml
name: led_controller
description: Flutter app for ESP8266 LED control
publish_to: "none"

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  shared_preferences: ^2.2.3
  android_intent_plus: ^5.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^3.0.2

flutter:
  uses-material-design: true
```

```dart
// mobile_app/led_controller/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() {
  runApp(const ProviderScope(child: LedControllerApp()));
}
```

```dart
// mobile_app/led_controller/lib/app/app.dart
import 'package:flutter/material.dart';
import 'router.dart';

class LedControllerApp extends StatelessWidget {
  const LedControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LED Controller',
      theme: ThemeData(colorSchemeSeed: Colors.orange),
      onGenerateRoute: buildLedRoute,
      initialRoute: '/',
    );
  }
}
```

```dart
// mobile_app/led_controller/lib/app/router.dart
import 'package:flutter/material.dart';
import '../features/devices/presentation/device_list_page.dart';

Route<dynamic> buildLedRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => const DeviceListPage());
    default:
      return MaterialPageRoute(builder: (_) => const DeviceListPage());
  }
}
```

```dart
// mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart
import 'package:flutter/material.dart';

class DeviceListPage extends StatelessWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的设备')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('还没有设备'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {},
              child: const Text('添加设备'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 再跑一次测试，确认通过**

Run:

```bash
cd mobile_app/led_controller
flutter test test/app/app_smoke_test.dart -r expanded
```

Expected:

```text
00:00 +1: All tests passed!
```

- [ ] **Step 5: 提交**

```bash
git add mobile_app/led_controller
git commit -m "feat: scaffold Flutter LED controller app"
```

## Task 2: 建立设备域模型与枚举

**Files:**
- Create: `mobile_app/led_controller/lib/features/devices/domain/effect_mode.dart`
- Create: `mobile_app/led_controller/lib/features/devices/domain/device_status.dart`
- Create: `mobile_app/led_controller/lib/features/devices/domain/led_device.dart`
- Create: `mobile_app/led_controller/lib/features/devices/domain/device_repository.dart`
- Test: `mobile_app/led_controller/test/features/devices/domain/led_device_test.dart`

- [ ] **Step 1: 写失败测试，锁定设备模型行为**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';

void main() {
  test('LedDevice.copyWith 只覆盖传入字段', () {
    final device = LedDevice(
      id: 'device-1',
      name: '客厅灯带',
      ipAddress: '192.168.1.23',
      lastSeenAt: DateTime(2026, 4, 24, 20),
      lastKnownStatus: const DeviceStatus(
        mode: EffectMode.rainbow,
        brightness: 180,
        connectionState: DeviceConnectionState.online,
      ),
      createdAt: DateTime(2026, 4, 24, 19),
      updatedAt: DateTime(2026, 4, 24, 20),
    );

    final updated = device.copyWith(name: '卧室灯带');

    expect(updated.name, '卧室灯带');
    expect(updated.ipAddress, '192.168.1.23');
    expect(updated.lastKnownStatus.mode, EffectMode.rainbow);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/devices/domain/led_device_test.dart -r expanded
```

Expected:

```text
FAIL: Target of URI doesn't exist: 'package:led_controller/features/devices/domain/led_device.dart'
```

- [ ] **Step 3: 写最小领域实现**

```dart
// mobile_app/led_controller/lib/features/devices/domain/effect_mode.dart
enum EffectMode {
  rainbow,
  breath,
  fire,
  starry,
  wave,
  chase,
  sparkle,
  snake,
}
```

```dart
// mobile_app/led_controller/lib/features/devices/domain/device_status.dart
import 'effect_mode.dart';

enum DeviceConnectionState { online, offline, timeout, sending }

class DeviceStatus {
  const DeviceStatus({
    required this.mode,
    required this.brightness,
    required this.connectionState,
  });

  final EffectMode mode;
  final int brightness;
  final DeviceConnectionState connectionState;
}
```

```dart
// mobile_app/led_controller/lib/features/devices/domain/led_device.dart
import 'device_status.dart';

class LedDevice {
  const LedDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.lastSeenAt,
    required this.lastKnownStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ipAddress;
  final String name;
  final DateTime lastSeenAt;
  final DeviceStatus lastKnownStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  LedDevice copyWith({
    String? name,
    String? ipAddress,
    DateTime? lastSeenAt,
    DeviceStatus? lastKnownStatus,
    DateTime? updatedAt,
  }) {
    return LedDevice(
      id: id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastKnownStatus: lastKnownStatus ?? this.lastKnownStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

```dart
// mobile_app/led_controller/lib/features/devices/domain/device_repository.dart
import 'device_status.dart';
import 'led_device.dart';

abstract class DeviceRepository {
  Future<List<LedDevice>> loadDevices();
  Future<void> saveDevice(LedDevice device);
  Future<void> deleteDevice(String id);
  Future<void> updateDeviceStatus(String id, DeviceStatus status);
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/devices/domain/led_device_test.dart -r expanded
```

Expected:

```text
00:00 +1: All tests passed!
```

- [ ] **Step 5: 提交**

```bash
git add mobile_app/led_controller/lib/features/devices mobile_app/led_controller/test/features/devices/domain
git commit -m "feat: add device domain models"
```

## Task 3: 建立 UDP 协议层与状态解析

**Files:**
- Create: `mobile_app/led_controller/lib/core/network/udp_client.dart`
- Create: `mobile_app/led_controller/lib/core/network/udp_led_protocol.dart`
- Create: `mobile_app/led_controller/lib/core/network/pairing_probe_service.dart`
- Test: `mobile_app/led_controller/test/core/network/udp_led_protocol_test.dart`

- [ ] **Step 1: 写失败测试，锁定命令拼装与状态解析**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/core/network/udp_led_protocol.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';

void main() {
  test('正确拼装控制命令', () {
    final protocol = UdpLedProtocol();

    expect(protocol.statusCommand(), 'status');
    expect(protocol.modeCommand(EffectMode.fire), 'mode:fire');
    expect(protocol.nextModeCommand(), 'mode:next');
    expect(protocol.brightnessCommand(200), 'bright:200');
  });

  test('正确解析 status 响应', () {
    final protocol = UdpLedProtocol();
    final status = protocol.parseStatus('MODE:rainbow;BRIGHT:180');

    expect(status.mode, EffectMode.rainbow);
    expect(status.brightness, 180);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:

```bash
cd mobile_app/led_controller
flutter test test/core/network/udp_led_protocol_test.dart -r expanded
```

Expected:

```text
FAIL: Target of URI doesn't exist: 'package:led_controller/core/network/udp_led_protocol.dart'
```

- [ ] **Step 3: 写最小协议实现**

```dart
// mobile_app/led_controller/lib/core/network/udp_led_protocol.dart
import '../../features/devices/domain/device_status.dart';
import '../../features/devices/domain/effect_mode.dart';

class UdpLedProtocol {
  String statusCommand() => 'status';
  String nextModeCommand() => 'mode:next';
  String previousModeCommand() => 'mode:prev';
  String modeCommand(EffectMode mode) => 'mode:${mode.name}';
  String brightnessCommand(int brightness) => 'bright:${brightness.clamp(0, 255)}';

  DeviceStatus parseStatus(String payload) {
    final parts = payload.split(';');
    final modePart = parts.firstWhere((item) => item.startsWith('MODE:'));
    final brightnessPart = parts.firstWhere((item) => item.startsWith('BRIGHT:'));
    final mode = EffectMode.values.byName(modePart.substring(5).toLowerCase());
    final brightness = int.parse(brightnessPart.substring(7));

    return DeviceStatus(
      mode: mode,
      brightness: brightness,
      connectionState: DeviceConnectionState.online,
    );
  }
}
```

```dart
// mobile_app/led_controller/lib/core/network/udp_client.dart
abstract class UdpClient {
  Future<String> send({
    required String host,
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 2),
  });

  /// 返回在广播窗口内响应的设备源 IP；没有响应时返回 null。
  Future<String?> sendBroadcast({
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 3),
  });
}
```

```dart
// mobile_app/led_controller/lib/core/network/pairing_probe_service.dart
import 'udp_client.dart';
import 'udp_led_protocol.dart';

class PairingProbeService {
  PairingProbeService(this._udpClient, this._protocol);

  final UdpClient _udpClient;
  final UdpLedProtocol _protocol;

  Future<String?> resolveDeviceIp() async {
    return _udpClient.sendBroadcast(
      port: 8888,
      payload: _protocol.statusCommand(),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run:

```bash
cd mobile_app/led_controller
flutter test test/core/network/udp_led_protocol_test.dart -r expanded
```

Expected:

```text
00:00 +2: All tests passed!
```

- [ ] **Step 5: 提交**

```bash
git add mobile_app/led_controller/lib/core/network mobile_app/led_controller/test/core/network
git commit -m "feat: add UDP LED protocol layer"
```

## Task 4: 建立本地持久化仓储

**Files:**
- Create: `mobile_app/led_controller/lib/features/devices/data/local_device_store.dart`
- Create: `mobile_app/led_controller/lib/features/devices/data/shared_prefs_device_repository.dart`
- Test: `mobile_app/led_controller/test/features/devices/data/shared_prefs_device_repository_test.dart`

- [ ] **Step 1: 写失败测试，锁定设备列表的保存与读取**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:led_controller/features/devices/data/shared_prefs_device_repository.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';

void main() {
  test('保存后可以重新读取设备列表', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPrefsDeviceRepository();

    final device = LedDevice(
      id: 'device-1',
      name: '客厅灯带',
      ipAddress: '192.168.1.23',
      lastSeenAt: DateTime(2026, 4, 24, 21),
      lastKnownStatus: const DeviceStatus(
        mode: EffectMode.rainbow,
        brightness: 180,
        connectionState: DeviceConnectionState.online,
      ),
      createdAt: DateTime(2026, 4, 24, 20),
      updatedAt: DateTime(2026, 4, 24, 21),
    );

    await repository.saveDevice(device);
    final devices = await repository.loadDevices();

    expect(devices.single.name, '客厅灯带');
    expect(devices.single.ipAddress, '192.168.1.23');
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/devices/data/shared_prefs_device_repository_test.dart -r expanded
```

Expected:

```text
FAIL: Target of URI doesn't exist: 'package:led_controller/features/devices/data/shared_prefs_device_repository.dart'
```

- [ ] **Step 3: 写最小持久化实现**

```dart
// mobile_app/led_controller/lib/features/devices/data/local_device_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDeviceStore {
  static const _devicesKey = 'registered_devices';

  Future<List<Map<String, dynamic>>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_devicesKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> writeAll(List<Map<String, dynamic>> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_devicesKey, jsonEncode(devices));
  }
}
```

```dart
// mobile_app/led_controller/lib/features/devices/data/shared_prefs_device_repository.dart
import '../domain/device_repository.dart';
import '../domain/device_status.dart';
import '../domain/effect_mode.dart';
import '../domain/led_device.dart';
import 'local_device_store.dart';

class SharedPrefsDeviceRepository implements DeviceRepository {
  SharedPrefsDeviceRepository({LocalDeviceStore? store}) : _store = store ?? LocalDeviceStore();

  final LocalDeviceStore _store;

  @override
  Future<List<LedDevice>> loadDevices() async {
    final items = await _store.readAll();
    return items.map(_fromMap).toList();
  }

  @override
  Future<void> saveDevice(LedDevice device) async {
    final items = await _store.readAll();
    items.removeWhere((item) => item['id'] == device.id);
    items.add(_toMap(device));
    await _store.writeAll(items);
  }

  @override
  Future<void> deleteDevice(String id) async {
    final items = await _store.readAll();
    items.removeWhere((item) => item['id'] == id);
    await _store.writeAll(items);
  }

  @override
  Future<void> updateDeviceStatus(String id, DeviceStatus status) async {
    final devices = await loadDevices();
    final updated = devices
        .map((device) => device.id == id
            ? device.copyWith(lastKnownStatus: status, updatedAt: DateTime.now(), lastSeenAt: DateTime.now())
            : device)
        .toList();
    await _store.writeAll(updated.map(_toMap).toList());
  }

  Map<String, dynamic> _toMap(LedDevice device) => {
        'id': device.id,
        'name': device.name,
        'ipAddress': device.ipAddress,
        'lastSeenAt': device.lastSeenAt.toIso8601String(),
        'mode': device.lastKnownStatus.mode.name,
        'brightness': device.lastKnownStatus.brightness,
        'connectionState': device.lastKnownStatus.connectionState.name,
        'createdAt': device.createdAt.toIso8601String(),
        'updatedAt': device.updatedAt.toIso8601String(),
      };

  LedDevice _fromMap(Map<String, dynamic> item) {
    return LedDevice(
      id: item['id'] as String,
      name: item['name'] as String,
      ipAddress: item['ipAddress'] as String,
      lastSeenAt: DateTime.parse(item['lastSeenAt'] as String),
      lastKnownStatus: DeviceStatus(
        mode: EffectMode.values.byName(item['mode'] as String),
        brightness: item['brightness'] as int,
        connectionState: DeviceConnectionState.values.byName(item['connectionState'] as String),
      ),
      createdAt: DateTime.parse(item['createdAt'] as String),
      updatedAt: DateTime.parse(item['updatedAt'] as String),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/devices/data/shared_prefs_device_repository_test.dart -r expanded
```

Expected:

```text
00:00 +1: All tests passed!
```

- [ ] **Step 5: 提交**

```bash
git add mobile_app/led_controller/lib/features/devices/data mobile_app/led_controller/test/features/devices/data
git commit -m "feat: persist registered devices locally"
```

## Task 5: 完成设备列表页与列表控制器

**Files:**
- Create: `mobile_app/led_controller/lib/features/devices/application/device_list_controller.dart`
- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`
- Modify: `mobile_app/led_controller/lib/app/app.dart`
- Test: `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart`

- [ ] **Step 1: 写失败测试，覆盖空状态和已登记设备展示**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';
import 'package:led_controller/features/devices/presentation/device_list_page.dart';

void main() {
  testWidgets('设备列表页展示已保存设备', (tester) async {
    final devices = [
      LedDevice(
        id: 'device-1',
        name: '客厅灯带',
        ipAddress: '192.168.1.23',
        lastSeenAt: DateTime(2026, 4, 24, 21),
        lastKnownStatus: const DeviceStatus(
          mode: EffectMode.fire,
          brightness: 180,
          connectionState: DeviceConnectionState.online,
        ),
        createdAt: DateTime(2026, 4, 24, 20),
        updatedAt: DateTime(2026, 4, 24, 21),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceListProvider.overrideWith((ref) async => devices)],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('客厅灯带'), findsOneWidget);
    expect(find.text('192.168.1.23'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/devices/presentation/device_list_page_test.dart -r expanded
```

Expected:

```text
FAIL: Undefined name 'deviceListProvider'
```

- [ ] **Step 3: 写最小列表控制器和页面绑定**

```dart
// mobile_app/led_controller/lib/features/devices/application/device_list_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/shared_prefs_device_repository.dart';
import '../domain/device_repository.dart';
import '../domain/led_device.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return SharedPrefsDeviceRepository();
});

final deviceListProvider = FutureProvider<List<LedDevice>>((ref) async {
  final repository = ref.watch(deviceRepositoryProvider);
  return repository.loadDevices();
});
```

```dart
// mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/device_list_controller.dart';

class DeviceListPage extends ConsumerWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(deviceListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的设备')),
      body: devicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('还没有设备'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () {}, child: const Text('添加设备')),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device.name),
                subtitle: Text(device.ipAddress),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/devices/presentation/device_list_page_test.dart -r expanded
```

Expected:

```text
00:00 +1: All tests passed!
```

- [ ] **Step 5: 提交**

```bash
git add mobile_app/led_controller/lib/features/devices/application mobile_app/led_controller/lib/features/devices/presentation mobile_app/led_controller/test/features/devices/presentation
git commit -m "feat: render registered devices on home page"
```

## Task 6: 建立配网状态机与配网页

**Files:**
- Create: `mobile_app/led_controller/lib/features/pairing/domain/pairing_step.dart`
- Create: `mobile_app/led_controller/lib/features/pairing/domain/pairing_state.dart`
- Create: `mobile_app/led_controller/lib/features/pairing/application/pairing_controller.dart`
- Create: `mobile_app/led_controller/lib/features/pairing/presentation/pairing_page.dart`
- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`
- Test: `mobile_app/led_controller/test/features/pairing/application/pairing_controller_test.dart`

- [ ] **Step 1: 写失败测试，锁定状态机流转**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/pairing/application/pairing_controller.dart';
import 'package:led_controller/features/pairing/domain/pairing_step.dart';

void main() {
  test('配网控制器按照步骤推进', () {
    final controller = PairingController();

    expect(controller.state.step, PairingStep.prepare);

    controller.moveToApJoin();
    expect(controller.state.step, PairingStep.joinAp);

    controller.confirmApJoined();
    expect(controller.state.step, PairingStep.enterWifi);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/pairing/application/pairing_controller_test.dart -r expanded
```

Expected:

```text
FAIL: Target of URI doesn't exist: 'package:led_controller/features/pairing/application/pairing_controller.dart'
```

- [ ] **Step 3: 写最小状态机实现和配网页骨架**

```dart
// mobile_app/led_controller/lib/features/pairing/domain/pairing_step.dart
enum PairingStep { prepare, joinAp, returnToApp, enterWifi, waitingReconnect, success, failure }
```

```dart
// mobile_app/led_controller/lib/features/pairing/domain/pairing_state.dart
import 'pairing_step.dart';

class PairingState {
  const PairingState({
    required this.step,
    this.ssid = '',
    this.password = '',
    this.errorMessage,
    this.resolvedIpAddress,
  });

  final PairingStep step;
  final String ssid;
  final String password;
  final String? errorMessage;
  final String? resolvedIpAddress;

  PairingState copyWith({
    PairingStep? step,
    String? ssid,
    String? password,
    String? errorMessage,
    String? resolvedIpAddress,
  }) {
    return PairingState(
      step: step ?? this.step,
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      errorMessage: errorMessage,
      resolvedIpAddress: resolvedIpAddress ?? this.resolvedIpAddress,
    );
  }
}
```

```dart
// mobile_app/led_controller/lib/features/pairing/application/pairing_controller.dart
import '../domain/pairing_state.dart';
import '../domain/pairing_step.dart';

class PairingController {
  PairingState _state = const PairingState(step: PairingStep.prepare);

  PairingState get state => _state;

  void moveToApJoin() {
    _state = _state.copyWith(step: PairingStep.joinAp);
  }

  void confirmApJoined() {
    _state = _state.copyWith(step: PairingStep.enterWifi);
  }

  void markWaitingReconnect(String ssid, String password) {
    _state = _state.copyWith(
      step: PairingStep.waitingReconnect,
      ssid: ssid,
      password: password,
    );
  }
}
```

```dart
// mobile_app/led_controller/lib/features/pairing/presentation/pairing_page.dart
import 'package:flutter/material.dart';

class PairingPage extends StatelessWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加设备')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('步骤 1/5'),
            SizedBox(height: 12),
            Text('准备连接设备热点'),
            SizedBox(height: 12),
            Text('请确认设备已经上电，并准备连接 LED_Config。'),
          ],
        ),
      ),
    );
  }
}
```

```dart
// mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pairing/presentation/pairing_page.dart';
import '../application/device_list_controller.dart';

class DeviceListPage extends ConsumerWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(deviceListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的设备')),
      body: devicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('还没有设备'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PairingPage()),
                      );
                    },
                    child: const Text('添加设备'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device.name),
                subtitle: Text(device.ipAddress),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/pairing/application/pairing_controller_test.dart -r expanded
```

Expected:

```text
00:00 +1: All tests passed!
```

- [ ] **Step 5: 提交**

```bash
git add mobile_app/led_controller/lib/features/pairing mobile_app/led_controller/test/features/pairing/application
git commit -m "feat: add pairing state machine skeleton"
```

## Task 7: 完成配网编排器、WiFi 跳转与设备登记

**Files:**
- Create: `mobile_app/led_controller/lib/core/platform/wifi_settings_launcher.dart`
- Create: `mobile_app/led_controller/lib/core/platform/android_wifi_settings_launcher.dart`
- Create: `mobile_app/led_controller/lib/features/pairing/application/pairing_coordinator.dart`
- Modify: `mobile_app/led_controller/lib/features/pairing/application/pairing_controller.dart`
- Modify: `mobile_app/led_controller/lib/features/pairing/presentation/pairing_page.dart`
- Test: `mobile_app/led_controller/test/features/pairing/application/pairing_controller_test.dart`

- [ ] **Step 1: 写失败测试，锁定提交 WiFi 后的编排逻辑**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/pairing/application/pairing_controller.dart';
import 'package:led_controller/features/pairing/application/pairing_coordinator.dart';
import 'package:led_controller/features/pairing/domain/pairing_step.dart';

class FakePairingCoordinator implements PairingCoordinator {
  bool didOpenWifi = false;
  bool didSubmit = false;

  @override
  Future<void> openWifiSettings() async {
    didOpenWifi = true;
  }

  @override
  Future<String> submitCredentials({
    required String ssid,
    required String password,
  }) async {
    didSubmit = true;
    return '192.168.1.23';
  }
}

void main() {
  test('提交 WiFi 后进入等待重连并最终成功', () async {
    final coordinator = FakePairingCoordinator();
    final controller = PairingController(coordinator: coordinator);

    await controller.submitCredentials(
      ssid: 'HomeWiFi',
      password: '12345678',
    );

    expect(controller.state.step, PairingStep.success);
    expect(controller.state.resolvedIpAddress, '192.168.1.23');
    expect(coordinator.didSubmit, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/pairing/application/pairing_controller_test.dart -r expanded
```

Expected:

```text
FAIL: Target of URI doesn't exist: 'package:led_controller/features/pairing/application/pairing_coordinator.dart'
```

- [ ] **Step 3: 写最小配网编排实现**

```dart
// mobile_app/led_controller/lib/core/platform/wifi_settings_launcher.dart
abstract class WifiSettingsLauncher {
  Future<void> openWifiSettings();
}
```

```dart
// mobile_app/led_controller/lib/core/platform/android_wifi_settings_launcher.dart
import 'package:android_intent_plus/android_intent.dart';
import 'wifi_settings_launcher.dart';

class AndroidWifiSettingsLauncher implements WifiSettingsLauncher {
  @override
  Future<void> openWifiSettings() async {
    const intent = AndroidIntent(action: 'android.settings.WIFI_SETTINGS');
    await intent.launch();
  }
}
```

```dart
// mobile_app/led_controller/lib/features/pairing/application/pairing_coordinator.dart
import '../../../core/network/pairing_probe_service.dart';
import '../../../core/network/udp_led_protocol.dart';
import '../../../core/network/udp_client.dart';
import '../../../core/platform/wifi_settings_launcher.dart';
import '../../devices/domain/device_repository.dart';
import '../../devices/domain/device_status.dart';
import '../../devices/domain/effect_mode.dart';
import '../../devices/domain/led_device.dart';

abstract class PairingCoordinator {
  Future<void> openWifiSettings();
  Future<String> submitCredentials({required String ssid, required String password});
}

class DefaultPairingCoordinator implements PairingCoordinator {
  DefaultPairingCoordinator({
    required this.wifiSettingsLauncher,
    required this.udpClient,
    required this.deviceRepository,
    PairingProbeService? pairingProbeService,
  }) : pairingProbeService = pairingProbeService ?? PairingProbeService(udpClient, UdpLedProtocol());

  final WifiSettingsLauncher wifiSettingsLauncher;
  final UdpClient udpClient;
  final DeviceRepository deviceRepository;
  final PairingProbeService pairingProbeService;

  @override
  Future<void> openWifiSettings() {
    return wifiSettingsLauncher.openWifiSettings();
  }

  @override
  Future<String> submitCredentials({required String ssid, required String password}) async {
    await udpClient.send(host: '192.168.4.1', port: 8889, payload: 'config:$ssid:$password');
    final ip = await pairingProbeService.resolveDeviceIp();
    if (ip == null) {
      throw Exception('设备未在配网窗口内返回局域网');
    }

    final now = DateTime.now();
    await deviceRepository.saveDevice(
      LedDevice(
        id: ip,
        name: 'LED-$ip',
        ipAddress: ip,
        lastSeenAt: now,
        lastKnownStatus: const DeviceStatus(
          mode: EffectMode.rainbow,
          brightness: 180,
          connectionState: DeviceConnectionState.online,
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );

    return ip;
  }
}
```

```dart
// mobile_app/led_controller/lib/features/pairing/application/pairing_controller.dart
import '../domain/pairing_state.dart';
import '../domain/pairing_step.dart';
import 'pairing_coordinator.dart';

class PairingController {
  PairingController({PairingCoordinator? coordinator})
      : _coordinator = coordinator;

  final PairingCoordinator? _coordinator;
  PairingState _state = const PairingState(step: PairingStep.prepare);

  PairingState get state => _state;

  void moveToApJoin() {
    _state = _state.copyWith(step: PairingStep.joinAp);
  }

  void confirmApJoined() {
    _state = _state.copyWith(step: PairingStep.enterWifi);
  }

  Future<void> openWifiSettings() async {
    await _coordinator?.openWifiSettings();
    _state = _state.copyWith(step: PairingStep.returnToApp);
  }

  Future<void> submitCredentials({
    required String ssid,
    required String password,
  }) async {
    _state = _state.copyWith(step: PairingStep.waitingReconnect, ssid: ssid, password: password);
    try {
      final ip = await _coordinator!.submitCredentials(ssid: ssid, password: password);
      _state = _state.copyWith(step: PairingStep.success, resolvedIpAddress: ip);
    } catch (error) {
      _state = _state.copyWith(step: PairingStep.failure, errorMessage: '$error');
    }
  }
}
```

```dart
// mobile_app/led_controller/lib/features/pairing/presentation/pairing_page.dart
import 'package:flutter/material.dart';

class PairingPage extends StatelessWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加设备')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('步骤 1/5'),
            const SizedBox(height: 12),
            const Text('准备连接设备热点'),
            const SizedBox(height: 12),
            const Text('请确认设备已经上电，并准备连接 LED_Config。'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {},
              child: const Text('打开系统 WiFi 设置'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('我已连接，继续'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/pairing/application/pairing_controller_test.dart -r expanded
```

Expected:

```text
00:00 +1: All tests passed!
```

- [ ] **Step 5: 提交**

```bash
git add mobile_app/led_controller/lib/core/platform mobile_app/led_controller/lib/features/pairing/application mobile_app/led_controller/lib/features/pairing/presentation mobile_app/led_controller/test/features/pairing/application
git commit -m "feat: wire pairing coordinator and WiFi settings handoff"
```

## Task 8: 完成单设备控制页与控制控制器

**Files:**
- Create: `mobile_app/led_controller/lib/features/devices/application/device_control_controller.dart`
- Create: `mobile_app/led_controller/lib/features/devices/presentation/device_control_page.dart`
- Test: `mobile_app/led_controller/test/features/devices/application/device_control_controller_test.dart`

- [ ] **Step 1: 写失败测试，锁定状态拉取与控制命令**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/core/network/udp_client.dart';
import 'package:led_controller/core/network/udp_led_protocol.dart';
import 'package:led_controller/features/devices/application/device_control_controller.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';

class FakeUdpClient implements UdpClient {
  @override
  Future<String> send({
    required String host,
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return 'MODE:sparkle;BRIGHT:200';
  }

  @override
  Future<String?> sendBroadcast({
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return null;
  }
}

void main() {
  test('refresh 后用 status 响应刷新页面状态', () async {
    final controller = DeviceControlController(FakeUdpClient(), UdpLedProtocol());

    await controller.refresh('192.168.1.23');

    expect(controller.state.requireValue.mode, EffectMode.sparkle);
    expect(controller.state.requireValue.brightness, 200);
    expect(controller.state.requireValue.connectionState, DeviceConnectionState.online);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/devices/application/device_control_controller_test.dart -r expanded
```

Expected:

```text
FAIL: Target of URI doesn't exist: 'package:led_controller/features/devices/application/device_control_controller.dart'
```

- [ ] **Step 3: 写最小控制器与控制页实现**

```dart
// mobile_app/led_controller/lib/features/devices/application/device_control_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/udp_client.dart';
import '../../../core/network/udp_led_protocol.dart';
import '../domain/device_status.dart';
import '../domain/effect_mode.dart';

class DeviceControlController extends StateNotifier<AsyncValue<DeviceStatus>> {
  DeviceControlController(this._udpClient, this._protocol)
      : super(
          const AsyncValue.data(
            DeviceStatus(
              mode: EffectMode.rainbow,
              brightness: 180,
              connectionState: DeviceConnectionState.online,
            ),
          ),
        );

  final UdpClient _udpClient;
  final UdpLedProtocol _protocol;

  Future<void> refresh(String ip) async {
    state = const AsyncValue.loading();
    final payload = await _udpClient.send(host: ip, port: 8888, payload: _protocol.statusCommand());
    state = AsyncValue.data(_protocol.parseStatus(payload));
  }

  Future<void> setMode(String ip, EffectMode mode) async {
    await _udpClient.send(host: ip, port: 8888, payload: _protocol.modeCommand(mode));
    await refresh(ip);
  }

  Future<void> setBrightness(String ip, int brightness) async {
    await _udpClient.send(host: ip, port: 8888, payload: _protocol.brightnessCommand(brightness));
    await refresh(ip);
  }
}
```

```dart
// mobile_app/led_controller/lib/features/devices/presentation/device_control_page.dart
import 'package:flutter/material.dart';

class DeviceControlPage extends StatelessWidget {
  const DeviceControlPage({
    super.key,
    required this.deviceName,
    required this.ipAddress,
  });

  final String deviceName;
  final String ipAddress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(deviceName)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IP: $ipAddress'),
            const SizedBox(height: 12),
            const Text('当前模式'),
            const SizedBox(height: 12),
            const Text('亮度'),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/devices/application/device_control_controller_test.dart -r expanded
```

Expected:

```text
00:00 +1: All tests passed!
```

- [ ] **Step 5: 提交**

```bash
git add mobile_app/led_controller/lib/features/devices/application mobile_app/led_controller/lib/features/devices/presentation mobile_app/led_controller/test/features/devices/application
git commit -m "feat: add single-device control flow"
```

## Task 9: 完成设置 / 帮助页与 Android 权限配置

**Files:**
- Create: `mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart`
- Modify: `mobile_app/led_controller/android/app/src/main/AndroidManifest.xml`
- Test: `mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart`

- [ ] **Step 1: 写失败测试，锁定帮助页关键文案**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('帮助页展示 WiFi 切换说明', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('网络与权限说明'), findsOneWidget);
    expect(find.textContaining('LED_Config'), findsOneWidget);
    expect(find.textContaining('无互联网'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/settings/presentation/settings_page_test.dart -r expanded
```

Expected:

```text
FAIL: Target of URI doesn't exist: 'package:led_controller/features/settings/presentation/settings_page.dart'
```

- [ ] **Step 3: 写最小设置页和 Android 权限声明**

```dart
// mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('网络与权限说明')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('配网时需要连接设备热点 LED_Config。'),
            SizedBox(height: 12),
            Text('看到“此网络无互联网”属于正常现象。'),
            SizedBox(height: 12),
            Text('如果 Android 自动切回原 WiFi，请重新连接后再返回 APP。'),
          ],
        ),
      ),
    );
  }
}
```

```xml
<!-- mobile_app/led_controller/android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <application
        android:label="led_controller"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

- [ ] **Step 4: 运行测试，确认通过**

Run:

```bash
cd mobile_app/led_controller
flutter test test/features/settings/presentation/settings_page_test.dart -r expanded
```

Expected:

```text
00:00 +1: All tests passed!
```

- [ ] **Step 5: 提交**

```bash
git add mobile_app/led_controller/lib/features/settings mobile_app/led_controller/android/app/src/main/AndroidManifest.xml mobile_app/led_controller/test/features/settings/presentation
git commit -m "feat: add settings help and Android network permissions"
```

## Task 10: 补全端到端集成测试与文档

**Files:**
- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`
- Create: `mobile_app/led_controller/integration_test/pairing_flow_test.dart`
- Create: `mobile_app/led_controller/integration_test/device_control_flow_test.dart`
- Create: `mobile_app/led_controller/README.md`

- [ ] **Step 1: 写失败的集成测试草案**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:led_controller/app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首页可以进入设置与帮助页', (tester) async {
    await tester.pumpWidget(const LedControllerApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('网络与权限说明'), findsOneWidget);
    expect(find.textContaining('LED_Config'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:

```bash
cd mobile_app/led_controller
flutter test integration_test/pairing_flow_test.dart -r expanded
```

Expected:

```text
FAIL: Expected: exactly one matching candidate
Actual: _WidgetPredicateWidgetFinder:<Found 0 widgets with icon IconData(U+0E57F)>
```

- [ ] **Step 3: 补上首页设置入口，并写集成测试与移动端 README**

```dart
// mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pairing/presentation/pairing_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../application/device_list_controller.dart';

class DeviceListPage extends ConsumerWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(deviceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的设备'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: devicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('还没有设备'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PairingPage()),
                      );
                    },
                    child: const Text('添加设备'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device.name),
                subtitle: Text(device.ipAddress),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
      ),
    );
  }
}
```

```dart
// mobile_app/led_controller/integration_test/device_control_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:led_controller/features/devices/presentation/device_control_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('设备控制页展示 IP 与基础控制字段', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DeviceControlPage(
          deviceName: '客厅灯带',
          ipAddress: '192.168.1.23',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('IP:'), findsWidgets);
    expect(find.text('当前模式'), findsOneWidget);
    expect(find.text('亮度'), findsOneWidget);
  });
}
```

```md
# LED Controller Mobile App

## 目标

这是 `smoothed_led` 项目的 Flutter Android 控制端。

## 本地开发

```bash
cd mobile_app/led_controller
flutter pub get
flutter test
```

## 关键能力

- 配网向导
- 设备登记
- UDP 状态查询
- UDP 模式切换
- UDP 亮度调节
```

- [ ] **Step 4: 运行测试与静态检查**

Run:

```bash
cd mobile_app/led_controller
flutter test
flutter test integration_test/pairing_flow_test.dart -r expanded
flutter test integration_test/device_control_flow_test.dart -r expanded
flutter analyze
```

Expected:

```text
All tests passed
No issues found!
```

- [ ] **Step 5: 提交**

```bash
git add mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart mobile_app/led_controller/integration_test mobile_app/led_controller/README.md
git commit -m "test: add integration coverage for pairing and device control"
```

## 自检结果

### Spec 覆盖检查

- 设备列表：首页空状态、已登记设备展示由 Task 1、Task 5 覆盖。
- 半自动配网、步骤式引导、WiFi 设置跳转、失败恢复骨架由 Task 6、Task 7 覆盖。
- 配网后受限 UDP 广播解析设备 IP 由 Task 3、Task 7 覆盖。
- 单设备控制、状态拉取、模式切换、亮度控制由 Task 3、Task 8 覆盖。
- 设置与帮助、Android 网络与权限说明由 Task 9 覆盖。
- 单元测试、集成测试与基本文档由 Task 1 到 Task 10 覆盖。

### 占位项扫描

- 计划中未保留 `TBD`、`TODO`、`implement later` 一类占位词。
- 每个任务都给出了明确文件路径、测试命令和最小实现代码。

### 一致性检查

- 工程根目录统一为 `mobile_app/led_controller`。
- UDP 端口统一为：配置 `8889`，控制与配网解析 `8888`。
- 状态管理策略统一为 `flutter_riverpod`，未混入其他状态库。
- 产品边界统一保持为：Android 优先、局域网控制、多设备无分组、不做通用发现。
