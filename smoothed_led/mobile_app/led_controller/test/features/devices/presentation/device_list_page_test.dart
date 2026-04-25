import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/core/network/udp_client.dart';
import 'package:led_controller/features/devices/application/device_control_controller.dart';
import 'package:led_controller/features/devices/application/device_list_controller.dart';
import 'package:led_controller/features/devices/domain/device_repository.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';
import 'package:led_controller/features/devices/presentation/device_list_page.dart';

class FakeDeviceRepository implements DeviceRepository {
  FakeDeviceRepository(this.devices);

  final List<LedDevice> devices;

  @override
  Future<List<LedDevice>> loadDevices() async => devices;

  @override
  Future<void> deleteDevice(String id) async {}

  @override
  Future<void> saveDevice(LedDevice device) async {}

  @override
  Future<void> updateDeviceStatus(String id, DeviceStatus status) async {}
}

class ThrowingDeviceRepository implements DeviceRepository {
  @override
  Future<List<LedDevice>> loadDevices() async {
    throw StateError('load failed');
  }

  @override
  Future<void> deleteDevice(String id) async {}

  @override
  Future<void> saveDevice(LedDevice device) async {}

  @override
  Future<void> updateDeviceStatus(String id, DeviceStatus status) async {}
}

class FakeUdpClient implements UdpClient {
  @override
  Future<String> send({
    required String host,
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return 'MODE:fire;BRIGHT:180';
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
  testWidgets('设备列表页展示空状态', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider
              .overrideWithValue(FakeDeviceRepository(const []))
        ],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('还没有设备'), findsOneWidget);
    expect(find.text('添加设备'), findsOneWidget);
  });

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
        overrides: [
          deviceRepositoryProvider
              .overrideWithValue(FakeDeviceRepository(devices)),
          udpClientProvider.overrideWithValue(FakeUdpClient()),
        ],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('客厅灯带'), findsOneWidget);
    expect(find.text('192.168.1.23'), findsOneWidget);
  });

  testWidgets('点击已保存设备后进入控制页', (tester) async {
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
        overrides: [
          deviceRepositoryProvider
              .overrideWithValue(FakeDeviceRepository(devices)),
          udpClientProvider.overrideWithValue(FakeUdpClient()),
        ],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('客厅灯带'));
    await tester.pumpAndSettle();

    expect(find.text('IP: 192.168.1.23'), findsOneWidget);
  });

  testWidgets('点击设置按钮后进入帮助页', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider
              .overrideWithValue(FakeDeviceRepository(const []))
        ],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('网络与权限说明'), findsOneWidget);
    expect(find.textContaining('LED_Config'), findsOneWidget);
  });

  testWidgets('设备列表页展示错误状态', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(ThrowingDeviceRepository())
        ],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('加载设备失败'), findsOneWidget);
  });
}
