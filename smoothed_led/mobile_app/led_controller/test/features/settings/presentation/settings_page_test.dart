import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/pairing/application/pairing_coordinator.dart';
import 'package:led_controller/features/settings/presentation/settings_page.dart';

class FakePairingCoordinator implements PairingCoordinator {
  @override
  Future<void> openWifiSettings() async {}

  @override
  Future<String> submitCredentials({
    required String ssid,
    required String password,
  }) async {
    return '192.168.1.45';
  }
}

void main() {
  testWidgets('帮助页展示结构化帮助中心内容', (tester) async {
    final faqAnswerSnippet = find.textContaining('设备刚上电');

    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('配网帮助'), findsOneWidget);
    expect(find.text('去添加设备'), findsOneWidget);

    expect(find.text('配网步骤'), findsOneWidget);
    expect(find.text('连接设备热点 LED_Config'), findsOneWidget);
    expect(find.text('等待设备重启并回到设备列表'), findsOneWidget);

    expect(find.text('常见故障'), findsOneWidget);
    expect(find.text('系统与权限说明'), findsOneWidget);
    expect(find.text('看不到 LED_Config'), findsNothing);
    expect(faqAnswerSnippet, findsNothing);

    await tester.tap(find.text('常见故障'));
    await tester.pumpAndSettle();

    expect(find.text('看不到 LED_Config'), findsOneWidget);
    expect(faqAnswerSnippet, findsNothing);

    await tester.tap(find.text('看不到 LED_Config'));
    await tester.pumpAndSettle();

    expect(faqAnswerSnippet, findsOneWidget);
  });

  testWidgets('帮助页点击去添加设备后进入配网页', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pairingCoordinatorProvider.overrideWithValue(FakePairingCoordinator()),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );

    await tester.tap(find.text('去添加设备'));
    await tester.pumpAndSettle();

    expect(find.text('添加设备'), findsOneWidget);
    expect(find.text('开始配网'), findsOneWidget);
  });
}
