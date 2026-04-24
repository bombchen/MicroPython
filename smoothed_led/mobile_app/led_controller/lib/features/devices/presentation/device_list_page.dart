import 'package:flutter/material.dart';

class DeviceListPage extends StatelessWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的设备')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('还没有设备'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {},
              child: const Text('添加设备'),
            ),
          ],
        ),
      ),
    );
  }
}
