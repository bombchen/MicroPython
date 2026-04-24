import '../domain/device_repository.dart';
import '../domain/device_status.dart';
import '../domain/effect_mode.dart';
import '../domain/led_device.dart';
import 'local_device_store.dart';

class SharedPrefsDeviceRepository implements DeviceRepository {
  SharedPrefsDeviceRepository({LocalDeviceStore? store})
      : _store = store ?? LocalDeviceStore();

  final LocalDeviceStore _store;

  @override
  Future<List<LedDevice>> loadDevices() async {
    final items = await _store.readAll();
    return items.map(_fromMap).toList();
  }

  @override
  Future<void> saveDevice(LedDevice device) async {
    final items = await _store.readAll();
    final existingIndex = items.indexWhere((item) => item['id'] == device.id);
    final mapped = _toMap(device);
    if (existingIndex == -1) {
      items.add(mapped);
    } else {
      items[existingIndex] = mapped;
    }
    await _store.writeAll(items);
  }

  @override
  Future<void> deleteDevice(String id) async {
    final items = await _store.readAll();
    items.removeWhere((item) => item['id'] == id);
    await _store.writeAll(items);
  }

  @override
  Future<void> updateDeviceStatus(String id, DeviceStatus status) async {
    final devices = await loadDevices();
    final now = DateTime.now();
    final updated = devices
        .map(
          (device) => device.id == id
              ? device.copyWith(
                  lastKnownStatus: status,
                  updatedAt: now,
                  lastSeenAt: now,
                )
              : device,
        )
        .toList();
    await _store.writeAll(updated.map(_toMap).toList());
  }

  Map<String, dynamic> _toMap(LedDevice device) => {
        'id': device.id,
        'name': device.name,
        'ipAddress': device.ipAddress,
        'lastSeenAt': device.lastSeenAt.toIso8601String(),
        'mode': device.lastKnownStatus.mode.name,
        'brightness': device.lastKnownStatus.brightness,
        'connectionState': device.lastKnownStatus.connectionState.name,
        'createdAt': device.createdAt.toIso8601String(),
        'updatedAt': device.updatedAt.toIso8601String(),
      };

  LedDevice _fromMap(Map<String, dynamic> item) {
    return LedDevice(
      id: item['id'] as String,
      name: item['name'] as String,
      ipAddress: item['ipAddress'] as String,
      lastSeenAt: DateTime.parse(item['lastSeenAt'] as String),
      lastKnownStatus: DeviceStatus(
        mode: EffectMode.values.byName(item['mode'] as String),
        brightness: item['brightness'] as int,
        connectionState:
            DeviceConnectionState.values.byName(item['connectionState'] as String),
      ),
      createdAt: DateTime.parse(item['createdAt'] as String),
      updatedAt: DateTime.parse(item['updatedAt'] as String),
    );
  }
}
