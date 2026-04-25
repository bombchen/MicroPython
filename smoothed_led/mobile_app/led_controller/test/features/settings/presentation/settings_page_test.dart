import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('帮助页展示 WiFi 切换说明', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('网络与权限说明'), findsOneWidget);
    expect(find.textContaining('LED_Config'), findsOneWidget);
    expect(find.textContaining('无互联网'), findsOneWidget);
  });
}
