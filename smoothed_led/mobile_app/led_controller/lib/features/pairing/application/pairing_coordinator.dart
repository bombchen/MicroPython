import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/local_network_diagnostics.dart';
import '../../../core/network/pairing_probe_service.dart';
import '../../../core/network/udp_client.dart';
import '../../../core/network/udp_led_protocol.dart';
import '../../../core/platform/android_wifi_settings_launcher.dart';
import '../../../core/platform/wifi_settings_launcher.dart';
import '../../devices/application/device_control_controller.dart';
import '../../devices/application/device_list_controller.dart';
import '../../devices/domain/device_repository.dart';
import '../../devices/domain/device_status.dart';
import '../../devices/domain/effect_mode.dart';
import '../../devices/domain/led_device.dart';
import 'pairing_failure.dart';

final pairingCoordinatorProvider = Provider<PairingCoordinator>((ref) {
  return DefaultPairingCoordinator(
    wifiSettingsLauncher: AndroidWifiSettingsLauncher(),
    udpClient: ref.watch(udpClientProvider),
    deviceRepository: ref.watch(deviceRepositoryProvider),
  );
});

abstract class PairingCoordinator {
  Future<void> openWifiSettings();

  Future<void> resetConfiguration();

  Future<void> sendCredentials({
    required String ssid,
    required String password,
  });

  Future<String> waitForDeviceRegistration();
}

class DefaultPairingCoordinator implements PairingCoordinator {
  DefaultPairingCoordinator({
    required this.wifiSettingsLauncher,
    required this.udpClient,
    required this.deviceRepository,
    PairingProbeService? pairingProbeService,
    LocalNetworkDiagnostics? localNetworkDiagnostics,
  })  : pairingProbeService = pairingProbeService ??
            PairingProbeService(udpClient, UdpLedProtocol()),
        localNetworkDiagnostics =
            localNetworkDiagnostics ?? IoLocalNetworkDiagnostics();

  final WifiSettingsLauncher wifiSettingsLauncher;
  final UdpClient udpClient;
  final DeviceRepository deviceRepository;
  final PairingProbeService pairingProbeService;
  final LocalNetworkDiagnostics localNetworkDiagnostics;

  @override
  Future<void> openWifiSettings() {
    return wifiSettingsLauncher.openWifiSettings();
  }

  @override
  Future<void> resetConfiguration() async {
    await _sendProvisioningPayload('reset');
  }

  @override
  Future<void> sendCredentials({
    required String ssid,
    required String password,
  }) async {
    await _sendProvisioningPayload('config:$ssid:$password');
  }

  @override
  Future<String> waitForDeviceRegistration() async {
    final startSnapshot = await localNetworkDiagnostics.capture();
    final ip = await pairingProbeService.resolveDeviceIp();
    if (ip == null) {
      final endSnapshot = await localNetworkDiagnostics.capture();
      throw PairingFailure(
        message: '设备未在配网窗口内返回局域网',
        diagnostics: _buildDiagnostics(
          startSnapshot: startSnapshot,
          endSnapshot: endSnapshot,
        ),
      );
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

  Future<void> _sendProvisioningPayload(String payload) async {
    try {
      await udpClient.send(
        host: '192.168.4.1',
        port: 8889,
        payload: payload,
      );
    } on TimeoutException {
      final existingIp = await pairingProbeService.resolveDeviceIp();
      if (existingIp == null) {
        rethrow;
      }
      await udpClient.send(
        host: existingIp,
        port: 8889,
        payload: payload,
      );
    }
  }

  String _buildDiagnostics({
    required LocalNetworkSnapshot startSnapshot,
    required LocalNetworkSnapshot endSnapshot,
  }) {
    return [
      '开始探测',
      startSnapshot.describe(),
      '结束探测',
      endSnapshot.describe(),
    ].join('\n');
  }
}
