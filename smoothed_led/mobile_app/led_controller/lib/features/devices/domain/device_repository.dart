import 'device_status.dart';
import 'led_device.dart';

abstract class DeviceRepository {
  Future<List<LedDevice>> loadDevices();
  Future<void> saveDevice(LedDevice device);
  Future<void> deleteDevice(String id);
  Future<void> updateDeviceStatus(String id, DeviceStatus status);
}
