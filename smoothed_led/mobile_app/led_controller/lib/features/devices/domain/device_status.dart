import 'effect_mode.dart';

enum DeviceConnectionState { online, offline, timeout, sending }

class DeviceStatus {
  const DeviceStatus({
    required this.mode,
    required this.brightness,
    required this.connectionState,
  });

  final EffectMode mode;
  final int brightness;
  final DeviceConnectionState connectionState;
}
