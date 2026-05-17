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
import 'package:led_controller/features/devices/presentation/device_control_page.dart';

class FakeUdpClient implements UdpClient {
  final List<String> payloads = <String>[];
  final List<String> responses = <String>[
    'MODE:fire;BRIGHT:120',
  ];

  @override
  Future<String> send({
    required String host,
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    payloads.add(payload);
    return responses.removeAt(0);
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
  LedDevice? savedDevice;
  String? deletedDeviceId;

  @override
  Future<void> deleteDevice(String id) async {
    deletedDeviceId = id;
  }

  @override
  Future<List<LedDevice>> loadDevices() async => const <LedDevice>[];

  @override
  Future<void> saveDevice(LedDevice device) async {
    savedDevice = device;
  }

  @override
  Future<void> updateDeviceStatus(String id, DeviceStatus status) async {}
}

LedDevice buildDevice() {
  return LedDevice(
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
}

void main() {
  testWidgets('控制页展示设备头卡和主控制区', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          udpClientProvider.overrideWithValue(FakeUdpClient()),
          deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
        ],
        child: MaterialApp(
          home: DeviceControlPage(device: buildDevice()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设备状态'), findsOneWidget);
    expect(find.text('亮度调节'), findsOneWidget);
    expect(find.text('常用灯效'), findsOneWidget);
  });

  testWidgets('控制页进入后自动刷新并展示最新状态', (tester) async {
    final udpClient = FakeUdpClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          udpClientProvider.overrideWithValue(udpClient),
          deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
        ],
        child: MaterialApp(
          home: DeviceControlPage(device: buildDevice()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(udpClient.payloads, contains('status'));
    expect(find.text('火焰'), findsWidgets);
    expect(find.text('120'), findsOneWidget);
  });

  testWidgets('点击下一个灯效后发送 next 命令并刷新页面状态', (tester) async {
    final udpClient = FakeUdpClient();
    udpClient.responses
      ..clear()
      ..addAll(<String>[
        'MODE:rainbow;BRIGHT:180',
        'ok',
        'MODE:breath;BRIGHT:180',
      ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          udpClientProvider.overrideWithValue(udpClient),
          deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
        ],
        child: MaterialApp(
          home: DeviceControlPage(device: buildDevice()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('下一个灯效'), 200);
    await tester.tap(find.text('下一个灯效'));
    await tester.pumpAndSettle();

    expect(udpClient.payloads, contains('mode:next'));
    expect(find.text('呼吸'), findsWidgets);
  });

  testWidgets('控制页展示音乐律动模式文案', (tester) async {
    final udpClient = FakeUdpClient();
    udpClient.responses
      ..clear()
      ..addAll(<String>['MODE:music;BRIGHT:120']);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          udpClientProvider.overrideWithValue(udpClient),
          deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
        ],
        child: MaterialApp(
          home: DeviceControlPage(device: buildDevice()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('音乐律动'), findsWidgets);
  });

  testWidgets('点击音乐律动后发送 mode:music 命令', (tester) async {
    final udpClient = FakeUdpClient();
    udpClient.responses
      ..clear()
      ..addAll(<String>[
        'MODE:rainbow;BRIGHT:180',
        'ok',
        'MODE:music;BRIGHT:180',
      ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          udpClientProvider.overrideWithValue(udpClient),
          deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
        ],
        child: MaterialApp(
          home: DeviceControlPage(device: buildDevice()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('音乐律动'));
    await tester.pumpAndSettle();

    expect(udpClient.payloads, contains('mode:music'));
    expect(find.text('音乐律动'), findsWidgets);
  });

  testWidgets('提交重命名后更新页面标题并写回仓储', (tester) async {
    final repository = FakeDeviceRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          udpClientProvider.overrideWithValue(FakeUdpClient()),
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: DeviceControlPage(device: buildDevice()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名设备'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '书房灯带');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('书房灯带'), findsWidgets);
    expect(repository.savedDevice?.name, '书房灯带');
  });

  testWidgets('确认删除后移除本地设备记录', (tester) async {
    final repository = FakeDeviceRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          udpClientProvider.overrideWithValue(FakeUdpClient()),
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: DeviceControlPage(device: buildDevice()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(repository.deletedDeviceId, 'device-1');
  });

  testWidgets('控制页通过更多菜单暴露重命名和删除', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          udpClientProvider.overrideWithValue(FakeUdpClient()),
          deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
        ],
        child: MaterialApp(
          home: DeviceControlPage(device: buildDevice()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('重命名设备'), findsOneWidget);
    expect(find.text('删除设备'), findsOneWidget);
  });
}
