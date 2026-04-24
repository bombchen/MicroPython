import 'package:flutter/material.dart';

class PairingPage extends StatelessWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加设备')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('步骤 1/5'),
            SizedBox(height: 12),
            Text('准备连接设备热点'),
            SizedBox(height: 12),
            Text('请确认设备已经上电，并准备连接 LED_Config。'),
          ],
        ),
      ),
    );
  }
}
