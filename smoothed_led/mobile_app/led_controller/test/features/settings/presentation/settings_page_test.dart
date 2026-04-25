import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('帮助页展示结构化帮助中心内容', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('配网帮助'), findsOneWidget);
    expect(find.text('去添加设备'), findsOneWidget);

    expect(find.text('配网步骤'), findsOneWidget);
    expect(find.text('连接设备热点 LED_Config'), findsOneWidget);
    expect(find.text('等待设备重启并回到设备列表'), findsOneWidget);

    expect(find.text('常见故障'), findsOneWidget);
    expect(find.text('系统与权限说明'), findsOneWidget);
    expect(find.text('看不到 LED_Config'), findsOneWidget);

    expect(find.text('如果手机搜不到热点，请先确认设备刚上电。'), findsNothing);
  });
}
