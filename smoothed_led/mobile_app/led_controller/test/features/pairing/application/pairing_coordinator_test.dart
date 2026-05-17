import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/core/network/local_network_diagnostics.dart';
import 'package:led_controller/core/network/pairing_probe_service.dart';
import 'package:led_controller/core/network/udp_client.dart';
import 'package:led_controller/core/network/udp_led_protocol.dart';
import 'package:led_controller/core/platform/wifi_settings_launcher.dart';
import 'package:led_controller/features/devices/domain/device_repository.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';
import 'package:led_controller/features/pairing/application/pairing_coordinator.dart';
import 'package:led_controller/features/pairing/application/pairing_failure.dart';

class FakeUdpClient implements UdpClient {
  final List<_SendRequest> requests = <_SendRequest>[];
  final List<Object> sendResults = <Object>[];

  @override
  Future<String> send({
    required String host,
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    requests.add(_SendRequest(host: host, port: port, payload: payload));
    if (sendResults.isNotEmpty) {
      final result = sendResults.removeAt(0);
      if (result is Exception) {
        throw result;
      }
      if (result is Error) {
        throw result;
      }
      return result as String;
    }
    return 'OK!Rebooting...';
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

class _SendRequest {
  const _SendRequest({
    required this.host,
    required this.port,
    required this.payload,
  });

  final String host;
  final int port;
  final String payload;
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

class FakePairingProbeService extends PairingProbeService {
  FakePairingProbeService({this.resolvedIp, List<String?>? resolvedIps})
      : _resolvedIps = resolvedIps == null ? null : List<String?>.from(resolvedIps),
        super(FakeUdpClient(), UdpLedProtocol());

  final String? resolvedIp;
  final List<String?>? _resolvedIps;

  @override
  Future<String?> resolveDeviceIp() async {
    if (_resolvedIps != null && _resolvedIps!.isNotEmpty) {
      return _resolvedIps!.removeAt(0);
    }
    return resolvedIp;
  }
}

class RecordingDeviceRepository implements DeviceRepository {
  LedDevice? savedDevice;

  @override
  Future<void> deleteDevice(String id) async {}

  @override
  Future<List<LedDevice>> loadDevices() async => const <LedDevice>[];

  @override
  Future<void> saveDevice(LedDevice device) async {
    savedDevice = device;
  }

  @override
  Future<void> updateDeviceStatus(String id, DeviceStatus status) async {}
}

class FakeLocalNetworkDiagnostics implements LocalNetworkDiagnostics {
  FakeLocalNetworkDiagnostics(this.snapshots);

  final List<LocalNetworkSnapshot> snapshots;
  int callCount = 0;

  @override
  Future<LocalNetworkSnapshot> capture() async {
    final snapshot = snapshots[callCount];
    callCount += 1;
    return snapshot;
  }
}

void main() {
  test('配网探测失败时抛出包含本机网络诊断的异常', () async {
    final coordinator = DefaultPairingCoordinator(
      wifiSettingsLauncher: _FakeWifiSettingsLauncher(),
      udpClient: FakeUdpClient(),
      deviceRepository: FakeDeviceRepository(),
      pairingProbeService: FakePairingProbeService(resolvedIp: null),
      localNetworkDiagnostics:
          FakeLocalNetworkDiagnostics(<LocalNetworkSnapshot>[
        const LocalNetworkSnapshot(
          ipv4Addresses: <String>['192.168.4.2'],
          broadcastTargets: <String>['255.255.255.255', '192.168.4.255'],
        ),
        const LocalNetworkSnapshot(
          ipv4Addresses: <String>['192.168.1.23'],
          broadcastTargets: <String>['255.255.255.255', '192.168.1.255'],
        ),
      ]),
    );

    expect(
      () async {
        await coordinator.sendCredentials(ssid: 'HomeWiFi', password: 'secret');
        await coordinator.waitForDeviceRegistration();
      },
      throwsA(
        isA<PairingFailure>()
            .having((error) => error.message, 'message', '设备未在配网窗口内返回局域网')
            .having(
              (error) => error.diagnostics,
              'diagnostics',
              allOf(
                contains('开始探测'),
                contains('192.168.4.2'),
                contains('192.168.4.255'),
                contains('结束探测'),
                contains('192.168.1.23'),
                contains('192.168.1.255'),
              ),
            ),
      ),
    );
  });

  test('设备已在原 WiFi 上时会回退到局域网配置并覆盖原配置', () async {
    final udpClient = FakeUdpClient()
      ..sendResults.addAll(<Object>[
        TimeoutException('UDP request to 192.168.4.1:8889 timed out'),
        'OK!Rebooting...',
      ]);
    final repository = RecordingDeviceRepository();
    final coordinator = DefaultPairingCoordinator(
      wifiSettingsLauncher: _FakeWifiSettingsLauncher(),
      udpClient: udpClient,
      deviceRepository: repository,
      pairingProbeService: FakePairingProbeService(
        resolvedIps: <String?>['192.168.1.45', '192.168.1.45'],
      ),
    );

    await coordinator.sendCredentials(
      ssid: 'HomeWiFi',
      password: 'secret',
    );
    final ip = await coordinator.waitForDeviceRegistration();

    expect(ip, '192.168.1.45');
    expect(
      udpClient.requests
          .map((request) => '${request.host}:${request.port}:${request.payload}')
          .toList(),
      <String>[
        '192.168.4.1:8889:config:HomeWiFi:secret',
        '192.168.1.45:8889:config:HomeWiFi:secret',
      ],
    );
    expect(repository.savedDevice?.id, '192.168.1.45');
    expect(repository.savedDevice?.ipAddress, '192.168.1.45');
  });

  test('重置配置时设备已在原 WiFi 上会回退到局域网命令', () async {
    final udpClient = FakeUdpClient()
      ..sendResults.addAll(<Object>[
        TimeoutException('UDP request to 192.168.4.1:8889 timed out'),
        'OK!Rebooting...',
      ]);
    final coordinator = DefaultPairingCoordinator(
      wifiSettingsLauncher: _FakeWifiSettingsLauncher(),
      udpClient: udpClient,
      deviceRepository: FakeDeviceRepository(),
      pairingProbeService: FakePairingProbeService(
        resolvedIps: <String?>['192.168.1.45'],
      ),
    );

    await coordinator.resetConfiguration();

    expect(
      udpClient.requests
          .map((request) => '${request.host}:${request.port}:${request.payload}')
          .toList(),
      <String>[
        '192.168.4.1:8889:reset',
        '192.168.1.45:8889:reset',
      ],
    );
  });
}

class _FakeWifiSettingsLauncher implements WifiSettingsLauncher {
  @override
  Future<void> openWifiSettings() async {}
}
