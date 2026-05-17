import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/core/network/udp_client.dart';
import 'package:led_controller/features/devices/application/device_control_controller.dart';
import 'package:led_controller/features/devices/application/device_list_controller.dart';
import 'package:led_controller/features/pairing/application/pairing_coordinator.dart';
import 'package:led_controller/features/devices/domain/device_repository.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';
import 'package:led_controller/features/devices/presentation/device_list_page.dart';
import 'dart:async';

class FakeDeviceRepository implements DeviceRepository {
  FakeDeviceRepository(
    this.devices, {
    DateTime? statusUpdatedAt,
  }) : statusUpdatedAt = statusUpdatedAt ?? DateTime(2026, 4, 24, 21, 30);

  final List<LedDevice> devices;
  final DateTime statusUpdatedAt;

  @override
  Future<List<LedDevice>> loadDevices() async => devices;

  @override
  Future<void> deleteDevice(String id) async {}

  @override
  Future<void> saveDevice(LedDevice device) async {
    final index = devices.indexWhere((item) => item.id == device.id);
    if (index == -1) {
      devices.add(device);
    } else {
      devices[index] = device;
    }
  }

  @override
  Future<void> updateDeviceStatus(String id, DeviceStatus status) async {
    final index = devices.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    devices[index] = devices[index].copyWith(
      lastKnownStatus: status,
      lastSeenAt: statusUpdatedAt,
      updatedAt: statusUpdatedAt,
    );
  }
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
  FakeUdpClient({
    List<Object>? sendResults,
  }) : sendResults = sendResults ?? <Object>['MODE:fire;BRIGHT:180'];

  final List<Object> sendResults;
  final List<String> payloads = <String>[];

  @override
  Future<String> send({
    required String host,
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    payloads.add('$host:$port:$payload');
    if (sendResults.isEmpty) {
      return 'MODE:fire;BRIGHT:180';
    }
    final result = sendResults.removeAt(0);
    if (result is Exception) {
      throw result;
    }
    if (result is Error) {
      throw result;
    }
    return result as String;
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

class FakePairingCoordinator implements PairingCoordinator {
  FakePairingCoordinator(this.repository);

  final FakeDeviceRepository repository;

  @override
  Future<void> openWifiSettings() async {}

  @override
  Future<void> resetConfiguration() async {}

  @override
  Future<void> sendCredentials({
    required String ssid,
    required String password,
  }) async {}

  @override
  Future<String> waitForDeviceRegistration() async {
    final now = DateTime(2026, 4, 25, 12);
    await repository.saveDevice(
      LedDevice(
        id: 'device-2',
        name: '新灯带',
        ipAddress: '192.168.1.45',
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
    return '192.168.1.45';
  }
}

Future<void> completePairingHappyPath(WidgetTester tester) async {
  await tester.tap(find.text('开始配网'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('打开系统 WiFi 设置'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('我已连接，继续'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'HomeWiFi');
  await tester.enterText(find.byType(TextFormField).at(1), '12345678');
  await tester.tap(find.text('发送配网信息'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('开始控制设备'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('设备列表页展示家庭灯光首页头部和主按钮', (tester) async {
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

    expect(find.text('我的灯光'), findsOneWidget);
    expect(find.text('随时调出家里的氛围'), findsOneWidget);
    expect(find.text('还没有设备'), findsOneWidget);
    expect(find.text('添加第一台灯带'), findsOneWidget);
  });

  testWidgets('设备列表页用设备卡展示状态摘要', (tester) async {
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
    expect(find.text('火焰'), findsOneWidget);
    expect(find.text('在线'), findsOneWidget);
  });

  testWidgets('设备列表页进入后自动刷新状态并展示最近同步时间', (tester) async {
    final devices = [
      LedDevice(
        id: 'device-1',
        name: '客厅灯带',
        ipAddress: '192.168.1.23',
        lastSeenAt: DateTime(2026, 4, 24, 21),
        lastKnownStatus: const DeviceStatus(
          mode: EffectMode.fire,
          brightness: 180,
          connectionState: DeviceConnectionState.offline,
        ),
        createdAt: DateTime(2026, 4, 24, 20),
        updatedAt: DateTime(2026, 4, 24, 21),
      ),
    ];
    final repository = FakeDeviceRepository(
      devices,
      statusUpdatedAt: DateTime(2026, 4, 24, 21, 30),
    );
    final udpClient = FakeUdpClient(
      sendResults: <Object>['MODE:rainbow;BRIGHT:180'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
          udpClientProvider.overrideWithValue(udpClient),
        ],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(udpClient.payloads, contains('192.168.1.23:8888:status'));
    expect(find.text('在线'), findsOneWidget);
    expect(find.text('最近同步: 2026-04-24 21:30'), findsOneWidget);
  });

  testWidgets('设备列表页支持手动刷新并展示超时结果', (tester) async {
    final devices = [
      LedDevice(
        id: 'device-1',
        name: '客厅灯带',
        ipAddress: '192.168.1.23',
        lastSeenAt: DateTime(2026, 4, 24, 21),
        lastKnownStatus: const DeviceStatus(
          mode: EffectMode.fire,
          brightness: 180,
          connectionState: DeviceConnectionState.offline,
        ),
        createdAt: DateTime(2026, 4, 24, 20),
        updatedAt: DateTime(2026, 4, 24, 21),
      ),
    ];
    final repository = FakeDeviceRepository(devices);
    final udpClient = FakeUdpClient(
      sendResults: <Object>[
        'MODE:rainbow;BRIGHT:180',
        TimeoutException('timeout'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
          udpClientProvider.overrideWithValue(udpClient),
        ],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('在线'), findsOneWidget);

    await tester.tap(find.byTooltip('刷新全部'));
    await tester.pumpAndSettle();

    expect(udpClient.payloads, <String>[
      '192.168.1.23:8888:status',
      '192.168.1.23:8888:status',
    ]);
    expect(find.text('超时'), findsOneWidget);
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
    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();

    expect(find.text('支持中心'), findsWidgets);
    expect(find.text('配网步骤'), findsOneWidget);
  });

  testWidgets('配网成功返回后刷新设备列表并提示成功', (tester) async {
    final repository = FakeDeviceRepository(<LedDevice>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
          udpClientProvider.overrideWithValue(FakeUdpClient()),
          pairingCoordinatorProvider
              .overrideWithValue(FakePairingCoordinator(repository)),
        ],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('添加第一台灯带'));
    await tester.pumpAndSettle();
    await completePairingHappyPath(tester);

    expect(find.text('新灯带'), findsOneWidget);
    expect(find.text('192.168.1.45'), findsOneWidget);
    expect(find.text('设备已添加'), findsOneWidget);
  });

  testWidgets('从帮助页进入配网成功后返回列表刷新并提示成功', (tester) async {
    final repository = FakeDeviceRepository(<LedDevice>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
          udpClientProvider.overrideWithValue(FakeUdpClient()),
          pairingCoordinatorProvider
              .overrideWithValue(FakePairingCoordinator(repository)),
        ],
        child: const MaterialApp(home: DeviceListPage()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();

    expect(find.text('支持中心'), findsWidgets);

    await tester.tap(find.text('添加新设备'));
    await tester.pumpAndSettle();
    await completePairingHappyPath(tester);

    expect(find.text('新灯带'), findsOneWidget);
    expect(find.text('192.168.1.45'), findsOneWidget);
    expect(find.text('设备已添加'), findsOneWidget);
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
