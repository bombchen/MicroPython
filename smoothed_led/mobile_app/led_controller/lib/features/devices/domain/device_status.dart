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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeviceStatus &&
            other.mode == mode &&
            other.brightness == brightness &&
            other.connectionState == connectionState;
  }

  @override
  int get hashCode => Object.hash(mode, brightness, connectionState);
}
