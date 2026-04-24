import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';
import 'package:led_controller/features/devices/presentation/device_list_page.dart';

void main() {
  testWidgets('设备列表页展示空状态', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceListProvider.overrideWith((ref) async => const [])],
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
        overrides: [deviceListProvider.overrideWith((ref) async => devices)],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('客厅灯带'), findsOneWidget);
    expect(find.text('192.168.1.23'), findsOneWidget);
  });
}
