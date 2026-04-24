import 'package:flutter/material.dart';

import '../features/devices/presentation/device_list_page.dart';

Route<dynamic> buildLedRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => const DeviceListPage());
    default:
      return MaterialPageRoute(builder: (_) => const DeviceListPage());
  }
}
