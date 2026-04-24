import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalDeviceStore {
  static const _devicesKey = 'registered_devices';

  Future<List<Map<String, dynamic>>> readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_devicesKey);
      if (raw == null) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final result = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is! Map) return [];
        result.add(Map<String, dynamic>.from(item));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> writeAll(List<Map<String, dynamic>> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_devicesKey, jsonEncode(devices));
  }
}
