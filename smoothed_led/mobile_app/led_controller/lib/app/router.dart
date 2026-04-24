import 'package:flutter/material.dart';

import '../features/devices/presentation/device_list_page.dart';

Route<dynamic> buildLedRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const DeviceListPage(),
      );
    default:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('页面不存在')),
          body: const Center(
            child: Text('找不到该页面'),
          ),
        ),
      );
  }
}
