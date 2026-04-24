import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';

void main() {
  test('LedDevice.copyWith 只覆盖传入字段', () {
    final device = LedDevice(
      id: 'device-1',
      name: '客厅灯带',
      ipAddress: '192.168.1.23',
      lastSeenAt: DateTime(2026, 4, 24, 20),
      lastKnownStatus: const DeviceStatus(
        mode: EffectMode.rainbow,
        brightness: 180,
        connectionState: DeviceConnectionState.online,
      ),
      createdAt: DateTime(2026, 4, 24, 19),
      updatedAt: DateTime(2026, 4, 24, 20),
    );

    final updated = device.copyWith(name: '卧室灯带');

    expect(updated.name, '卧室灯带');
    expect(updated.ipAddress, '192.168.1.23');
    expect(updated.lastKnownStatus.mode, EffectMode.rainbow);
  });
}
