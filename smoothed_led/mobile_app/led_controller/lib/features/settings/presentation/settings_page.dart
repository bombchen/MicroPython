import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('网络与权限说明')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('配网时需要连接设备热点 LED_Config。'),
            SizedBox(height: 12),
            Text('看到“此网络无互联网”属于正常现象。'),
            SizedBox(height: 12),
            Text('如果 Android 自动切回原 WiFi，请重新连接后再返回 APP。'),
          ],
        ),
      ),
    );
  }
}
