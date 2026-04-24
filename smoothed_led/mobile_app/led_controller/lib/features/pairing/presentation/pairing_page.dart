import 'package:flutter/material.dart';

class PairingPage extends StatelessWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加设备')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('步骤 1/5'),
            const SizedBox(height: 12),
            const Text('准备连接设备热点'),
            const SizedBox(height: 12),
            const Text('请确认设备已经上电，并准备连接 LED_Config。'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {},
              child: const Text('打开系统 WiFi 设置'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('我已连接，继续'),
            ),
          ],
        ),
      ),
    );
  }
}
