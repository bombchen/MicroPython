import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final pairingCoordinatorProvider = Provider<PairingCoordinator>((ref) {
  return DefaultPairingCoordinator(
    wifiSettingsLauncher: AndroidWifiSettingsLauncher(),
    udpClient: ref.watch(udpClientProvider),
    deviceRepository: ref.watch(deviceRepositoryProvider),
  );
});

abstract class PairingCoordinator {
  Future<void> openWifiSettings();

  Future<String> submitCredentials({
    required String ssid,
    required String password,
  });
}

class DefaultPairingCoordinator implements PairingCoordinator {
  DefaultPairingCoordinator({
    required this.wifiSettingsLauncher,
    required this.udpClient,
    required this.deviceRepository,
    PairingProbeService? pairingProbeService,
  }) : pairingProbeService = pairingProbeService ??
            PairingProbeService(udpClient, UdpLedProtocol());

  final WifiSettingsLauncher wifiSettingsLauncher;
  final UdpClient udpClient;
  final DeviceRepository deviceRepository;
  final PairingProbeService pairingProbeService;

  @override
  Future<void> openWifiSettings() {
    return wifiSettingsLauncher.openWifiSettings();
  }

  @override
  Future<String> submitCredentials({
    required String ssid,
    required String password,
  }) async {
    await udpClient.send(
      host: '192.168.4.1',
      port: 8889,
      payload: 'config:$ssid:$password',
    );

    final ip = await pairingProbeService.resolveDeviceIp();
    if (ip == null) {
      throw Exception('设备未在配网窗口内返回局域网');
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
}
