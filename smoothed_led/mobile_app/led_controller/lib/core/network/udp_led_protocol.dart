import '../../features/devices/domain/device_status.dart';
import '../../features/devices/domain/effect_mode.dart';

class UdpLedProtocol {
  String statusCommand() => 'status';

  String nextModeCommand() => 'mode:next';

  String previousModeCommand() => 'mode:prev';

  String modeCommand(EffectMode mode) => 'mode:${mode.name}';

  String brightnessCommand(int brightness) =>
      'bright:${brightness.clamp(0, 255).toInt()}';

  DeviceStatus parseStatus(String payload) {
    final parts = payload.split(';').map((part) => part.trim()).toList();
    final modePart = parts.firstWhere(
      (part) => part.toUpperCase().startsWith('MODE:'),
    );
    final brightnessPart = parts.firstWhere(
      (part) => part.toUpperCase().startsWith('BRIGHT:'),
    );

    final modeName = modePart.substring('MODE:'.length).toLowerCase();
    final brightness = int.parse(brightnessPart.substring('BRIGHT:'.length));

    return DeviceStatus(
      mode: EffectMode.values.byName(modeName),
      brightness: brightness,
      connectionState: DeviceConnectionState.online,
    );
  }
}
