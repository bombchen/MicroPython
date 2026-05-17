import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/io_udp_client.dart';
import '../../../core/network/udp_client.dart';
import '../../../core/network/udp_led_protocol.dart';
import '../data/shared_prefs_device_repository.dart';
import '../domain/device_repository.dart';
import '../domain/device_status.dart';
import '../domain/led_device.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return SharedPrefsDeviceRepository();
});

final udpClientProvider = Provider<UdpClient>((ref) {
  return IoUdpClient();
});

final udpLedProtocolProvider = Provider<UdpLedProtocol>((ref) {
  return UdpLedProtocol();
});

final deviceListRefresherProvider = Provider<DeviceListRefresher>((ref) {
  return DeviceListRefresher(
    repository: ref.watch(deviceRepositoryProvider),
    udpClient: ref.watch(udpClientProvider),
    protocol: ref.watch(udpLedProtocolProvider),
  );
});

final deviceListProvider = FutureProvider<List<LedDevice>>((ref) async {
  final repository = ref.watch(deviceRepositoryProvider);
  return repository.loadDevices();
});

class DeviceListRefresher {
  DeviceListRefresher({
    required DeviceRepository repository,
    required UdpClient udpClient,
    required UdpLedProtocol protocol,
  })  : _repository = repository,
        _udpClient = udpClient,
        _protocol = protocol;

  final DeviceRepository _repository;
  final UdpClient _udpClient;
  final UdpLedProtocol _protocol;

  Future<void> refreshStatuses() async {
    final devices = await _repository.loadDevices();
    for (final device in devices) {
      await _refreshSingleDevice(device);
    }
  }

  Future<void> _refreshSingleDevice(LedDevice device) async {
    try {
      final payload = await _udpClient.send(
        host: device.ipAddress,
        port: 8888,
        payload: _protocol.statusCommand(),
      );
      final status = _protocol.parseStatus(payload);
      await _repository.updateDeviceStatus(device.id, status);
    } on TimeoutException {
      await _repository.updateDeviceStatus(
        device.id,
        DeviceStatus(
          mode: device.lastKnownStatus.mode,
          brightness: device.lastKnownStatus.brightness,
          connectionState: DeviceConnectionState.timeout,
        ),
      );
    } on SocketException {
      await _repository.updateDeviceStatus(
        device.id,
        DeviceStatus(
          mode: device.lastKnownStatus.mode,
          brightness: device.lastKnownStatus.brightness,
          connectionState: DeviceConnectionState.offline,
        ),
      );
    } catch (_) {
      // Keep other devices refreshing even if one device returns bad data.
    }
  }
}
