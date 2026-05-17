import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/udp_client.dart';
import '../../../core/network/udp_led_protocol.dart';
import '../domain/device_repository.dart';
import '../domain/device_status.dart';
import '../domain/effect_mode.dart';

class DeviceControlController extends StateNotifier<AsyncValue<DeviceStatus>> {
  DeviceControlController(
    this._udpClient,
    this._protocol, {
    DeviceStatus? initialStatus,
    DeviceRepository? deviceRepository,
    String? deviceId,
  }) : _initialStatus = initialStatus ??
            const DeviceStatus(
              mode: EffectMode.rainbow,
              brightness: 180,
              connectionState: DeviceConnectionState.online,
            ),
        _deviceRepository = deviceRepository,
        _deviceId = deviceId,
        super(
          AsyncValue<DeviceStatus>.data(
            initialStatus ??
                const DeviceStatus(
                  mode: EffectMode.rainbow,
                  brightness: 180,
                  connectionState: DeviceConnectionState.online,
                ),
          ),
        );

  final UdpClient _udpClient;
  final UdpLedProtocol _protocol;
  final DeviceStatus _initialStatus;
  final DeviceRepository? _deviceRepository;
  final String? _deviceId;

  Future<void> refresh(String ip) async {
    final previous = _currentStatus();
    state = const AsyncValue.loading();

    try {
      final payload = await _udpClient.send(
        host: ip,
        port: 8888,
        payload: _protocol.statusCommand(),
      );
      final status = _protocol.parseStatus(payload);
      await _persistStatus(status);
      state = AsyncValue.data(status);
    } on TimeoutException {
      final timeoutStatus = _copyStatus(
        previous,
        connectionState: DeviceConnectionState.timeout,
      );
      await _persistStatus(timeoutStatus);
      state = AsyncValue.data(timeoutStatus);
    } on SocketException {
      final offlineStatus = _copyStatus(
        previous,
        connectionState: DeviceConnectionState.offline,
      );
      await _persistStatus(offlineStatus);
      state = AsyncValue.data(offlineStatus);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> setMode(String ip, EffectMode mode) async {
    final previous = _currentStatus();
    await _sendCommand(
      ip: ip,
      payload: _protocol.modeCommand(mode),
      sendingStatus: _copyStatus(
        previous,
        mode: mode,
        connectionState: DeviceConnectionState.sending,
      ),
    );
  }

  Future<void> setBrightness(String ip, int brightness) async {
    final previous = _currentStatus();
    await _sendCommand(
      ip: ip,
      payload: _protocol.brightnessCommand(brightness),
      sendingStatus: _copyStatus(
        previous,
        brightness: brightness,
        connectionState: DeviceConnectionState.sending,
      ),
    );
  }

  Future<void> nextMode(String ip) async {
    await _sendCommand(
      ip: ip,
      payload: _protocol.nextModeCommand(),
      sendingStatus: _copyStatus(
        _currentStatus(),
        connectionState: DeviceConnectionState.sending,
      ),
    );
  }

  Future<void> previousMode(String ip) async {
    await _sendCommand(
      ip: ip,
      payload: _protocol.previousModeCommand(),
      sendingStatus: _copyStatus(
        _currentStatus(),
        connectionState: DeviceConnectionState.sending,
      ),
    );
  }

  DeviceStatus _currentStatus() {
    return state.value ?? _initialStatus;
  }

  DeviceStatus _copyStatus(
    DeviceStatus source, {
    EffectMode? mode,
    int? brightness,
    DeviceConnectionState? connectionState,
  }) {
    return DeviceStatus(
      mode: mode ?? source.mode,
      brightness: brightness ?? source.brightness,
      connectionState: connectionState ?? source.connectionState,
    );
  }

  Future<void> _sendCommand({
    required String ip,
    required String payload,
    required DeviceStatus sendingStatus,
  }) async {
    state = AsyncValue.data(sendingStatus);

    try {
      await _udpClient.send(
        host: ip,
        port: 8888,
        payload: payload,
      );
      await refresh(ip);
    } on TimeoutException {
      final timeoutStatus = _copyStatus(
        sendingStatus,
        connectionState: DeviceConnectionState.timeout,
      );
      await _persistStatus(timeoutStatus);
      state = AsyncValue.data(timeoutStatus);
    } on SocketException {
      final offlineStatus = _copyStatus(
        sendingStatus,
        connectionState: DeviceConnectionState.offline,
      );
      await _persistStatus(offlineStatus);
      state = AsyncValue.data(offlineStatus);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _persistStatus(DeviceStatus status) async {
    final repository = _deviceRepository;
    final deviceId = _deviceId;
    if (repository == null || deviceId == null) {
      return;
    }

    await repository.updateDeviceStatus(deviceId, status);
  }
}
