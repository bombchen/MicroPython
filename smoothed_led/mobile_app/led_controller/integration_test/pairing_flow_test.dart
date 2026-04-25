import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首页可以进入设置与帮助页', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(EmptyDeviceRepository()),
        ],
        child: const LedControllerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('网络与权限说明'), findsOneWidget);
    expect(find.textContaining('LED_Config'), findsOneWidget);
  });
}
