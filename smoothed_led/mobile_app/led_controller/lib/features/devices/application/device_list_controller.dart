import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_prefs_device_repository.dart';
import '../domain/device_repository.dart';
import '../domain/led_device.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return SharedPrefsDeviceRepository();
});

final deviceListProvider = FutureProvider<List<LedDevice>>((ref) async {
  final repository = ref.watch(deviceRepositoryProvider);
  return repository.loadDevices();
});
