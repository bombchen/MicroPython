import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:led_controller/features/devices/data/shared_prefs_device_repository.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';
import 'package:led_controller/features/devices/domain/led_device.dart';

void main() {
  test('保存后可以重新读取设备列表', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPrefsDeviceRepository();

    final device = LedDevice(
      id: 'device-1',
      name: '客厅灯带',
      ipAddress: '192.168.1.23',
      lastSeenAt: DateTime(2026, 4, 24, 21),
      lastKnownStatus: const DeviceStatus(
        mode: EffectMode.rainbow,
        brightness: 180,
        connectionState: DeviceConnectionState.online,
      ),
      createdAt: DateTime(2026, 4, 24, 20),
      updatedAt: DateTime(2026, 4, 24, 21),
    );

    await repository.saveDevice(device);
    final devices = await repository.loadDevices();

    expect(devices.single.name, '客厅灯带');
    expect(devices.single.ipAddress, '192.168.1.23');
  });
}
