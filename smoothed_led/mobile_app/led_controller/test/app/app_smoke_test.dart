import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/app/app.dart';
import 'package:led_controller/features/devices/application/device_list_controller.dart';
import 'package:led_controller/features/devices/domain/device_repository.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';

class EmptyDeviceRepository implements DeviceRepository {
  @override
  Future<void> deleteDevice(String id) async {}

  @override
  Future<List<LedDevice>> loadDevices() async => const [];

  @override
  Future<void> saveDevice(LedDevice device) async {}

  @override
  Future<void> updateDeviceStatus(String id, DeviceStatus status) async {}
}

void main() {
  testWidgets('应用使用消费品化浅暖主题', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(EmptyDeviceRepository()),
        ],
        child: const LedControllerApp(),
      ),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final theme = materialApp.theme!;

    expect(theme.scaffoldBackgroundColor, isNot(Colors.white));
    expect(theme.cardTheme.shape, isNotNull);
    expect(theme.filledButtonTheme.style, isNotNull);
  });

  testWidgets('启动后默认显示设备列表空状态', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(EmptyDeviceRepository()),
        ],
        child: const LedControllerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的设备'), findsOneWidget);
    expect(find.text('还没有设备'), findsOneWidget);
    expect(find.text('添加设备'), findsOneWidget);
  });
}
