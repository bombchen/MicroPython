import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/core/network/udp_client.dart';
import 'package:led_controller/core/network/udp_led_protocol.dart';
import 'package:led_controller/features/devices/application/device_control_controller.dart';
import 'package:led_controller/features/devices/domain/device_repository.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';

class FakeUdpClient implements UdpClient {
  final List<_UdpRequest> requests = <_UdpRequest>[];
  final List<String> responses = <String>[
    'MODE:sparkle;BRIGHT:200',
  ];
  Object? sendError;

  @override
  Future<String> send({
    required String host,
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    requests.add(_UdpRequest(host: host, port: port, payload: payload));
    if (sendError != null) {
      throw sendError!;
    }
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

class _UdpRequest {
  const _UdpRequest({
    required this.host,
    required this.port,
    required this.payload,
  });

  final String host;
  final int port;
  final String payload;
}

class FakeDeviceRepository implements DeviceRepository {
  DeviceStatus? updatedStatus;

  @override
  Future<void> deleteDevice(String id) async {}

  @override
  Future<List<LedDevice>> loadDevices() async => const <LedDevice>[];

  @override
  Future<void> saveDevice(LedDevice device) async {}

  @override
  Future<void> updateDeviceStatus(String id, DeviceStatus status) async {
    updatedStatus = status;
  }
}

void main() {
  test('refresh 后用 status 响应刷新页面状态', () async {
    final controller =
        DeviceControlController(FakeUdpClient(), UdpLedProtocol());

    await controller.refresh('192.168.1.23');

    final status = controller.state.value;

    expect(status, isNotNull);
    expect(status!.mode, EffectMode.sparkle);
    expect(status.brightness, 200);
    expect(
      status.connectionState,
      DeviceConnectionState.online,
    );
  });

  test('setMode 发送模式命令后重新拉取状态', () async {
    final udpClient = FakeUdpClient();
    udpClient.responses
      ..clear()
      ..addAll(<String>[
        'ok',
        'MODE:fire;BRIGHT:180',
      ]);
    final controller = DeviceControlController(udpClient, UdpLedProtocol());

    await controller.setMode('192.168.1.23', EffectMode.fire);

    expect(udpClient.requests, hasLength(2));
    expect(udpClient.requests.first.payload, 'mode:fire');
    expect(udpClient.requests.last.payload, 'status');
    expect(controller.state.value?.mode, EffectMode.fire);
  });

  test('setBrightness 发送亮度命令后重新拉取状态', () async {
    final udpClient = FakeUdpClient();
    udpClient.responses
      ..clear()
      ..addAll(<String>[
        'ok',
        'MODE:rainbow;BRIGHT:64',
      ]);
    final controller = DeviceControlController(udpClient, UdpLedProtocol());

    await controller.setBrightness('192.168.1.23', 64);

    expect(udpClient.requests, hasLength(2));
    expect(udpClient.requests.first.payload, 'bright:64');
    expect(udpClient.requests.last.payload, 'status');
    expect(controller.state.value?.brightness, 64);
  });

  test('nextMode 发送下一个灯效命令后重新拉取状态', () async {
    final udpClient = FakeUdpClient();
    udpClient.responses
      ..clear()
      ..addAll(<String>[
        'ok',
        'MODE:breath;BRIGHT:180',
      ]);
    final controller = DeviceControlController(udpClient, UdpLedProtocol());

    await controller.nextMode('192.168.1.23');

    expect(udpClient.requests, hasLength(2));
    expect(udpClient.requests.first.payload, 'mode:next');
    expect(udpClient.requests.last.payload, 'status');
    expect(controller.state.value?.mode, EffectMode.breath);
  });

  test('refresh 成功后写回本地设备状态', () async {
    final repository = FakeDeviceRepository();
    final controller = DeviceControlController(
      FakeUdpClient(),
      UdpLedProtocol(),
      deviceRepository: repository,
      deviceId: 'device-1',
    );

    await controller.refresh('192.168.1.23');

    expect(repository.updatedStatus?.mode, EffectMode.sparkle);
    expect(repository.updatedStatus?.brightness, 200);
  });

  test('refresh 超时后标记为 timeout 状态', () async {
    final udpClient = FakeUdpClient()..sendError = TimeoutException('timeout');
    final controller = DeviceControlController(
      udpClient,
      UdpLedProtocol(),
      initialStatus: const DeviceStatus(
        mode: EffectMode.fire,
        brightness: 88,
        connectionState: DeviceConnectionState.online,
      ),
    );

    await controller.refresh('192.168.1.23');

    expect(controller.state is! AsyncError, isTrue);
    expect(controller.state.value?.mode, EffectMode.fire);
    expect(controller.state.value?.brightness, 88);
    expect(
      controller.state.value?.connectionState,
      DeviceConnectionState.timeout,
    );
  });
}
