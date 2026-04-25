import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:led_controller/core/network/udp_client.dart';
import 'package:led_controller/features/devices/application/device_control_controller.dart';
import 'package:led_controller/features/devices/application/device_list_controller.dart';
import 'package:led_controller/features/devices/domain/device_repository.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';
import 'package:led_controller/features/devices/presentation/device_control_page.dart';

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

class FakeDeviceRepository implements DeviceRepository {
  @override
  Future<void> deleteDevice(String id) async {}

  @override
  Future<List<LedDevice>> loadDevices() async => const <LedDevice>[];

  @override
  Future<void> saveDevice(LedDevice device) async {}

  @override
  Future<void> updateDeviceStatus(String id, DeviceStatus status) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('设备控制页展示 IP 与基础控制字段', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          udpClientProvider.overrideWithValue(FakeUdpClient()),
          deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
        ],
        child: MaterialApp(
          home: DeviceControlPage(
            device: LedDevice(
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('IP:'), findsWidgets);
    expect(find.text('当前模式'), findsOneWidget);
    expect(find.text('亮度'), findsOneWidget);
  });
}
