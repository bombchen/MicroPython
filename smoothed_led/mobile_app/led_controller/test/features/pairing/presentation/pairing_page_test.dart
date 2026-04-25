import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/pairing/application/pairing_controller.dart';
import 'package:led_controller/features/pairing/application/pairing_coordinator.dart';
import 'package:led_controller/features/pairing/presentation/pairing_page.dart';

class FakePairingCoordinator implements PairingCoordinator {
  bool didOpenWifi = false;
  Object? submitError;

  @override
  Future<void> openWifiSettings() async {
    didOpenWifi = true;
  }

  @override
  Future<String> submitCredentials({
    required String ssid,
    required String password,
  }) async {
    if (submitError != null) {
      throw submitError!;
    }
    return '192.168.1.23';
  }
}

void main() {
  testWidgets('配网页面按步骤推进直到成功', (tester) async {
    final coordinator = FakePairingCoordinator();

    await tester.pumpWidget(
      MaterialApp(
        home: PairingPage(
          controller: PairingController(coordinator: coordinator),
        ),
      ),
    );

    expect(find.text('步骤 1/5'), findsOneWidget);
    await tester.tap(find.text('开始配网'));
    await tester.pumpAndSettle();

    expect(find.text('步骤 2/5'), findsOneWidget);
    await tester.tap(find.text('打开系统 WiFi 设置'));
    await tester.pumpAndSettle();
    expect(coordinator.didOpenWifi, isTrue);

    expect(find.text('步骤 3/5'), findsOneWidget);
    await tester.tap(find.text('我已连接，继续'));
    await tester.pumpAndSettle();

    expect(find.text('步骤 4/5'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'HomeWiFi');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');
    await tester.tap(find.text('发送配网信息'));
    await tester.pumpAndSettle();

    expect(find.text('配网成功'), findsOneWidget);
    expect(find.textContaining('192.168.1.23'), findsOneWidget);
  });

  testWidgets('配网失败后可保留输入并返回表单重试', (tester) async {
    final coordinator = FakePairingCoordinator()
      ..submitError = Exception('设备未在配网窗口内返回局域网');

    await tester.pumpWidget(
      MaterialApp(
        home: PairingPage(
          controller: PairingController(coordinator: coordinator),
        ),
      ),
    );

    await tester.tap(find.text('开始配网'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开系统 WiFi 设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我已连接，继续'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'HomeWiFi');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');
    await tester.tap(find.text('发送配网信息'));
    await tester.pumpAndSettle();

    expect(find.text('配网失败'), findsOneWidget);
    expect(find.textContaining('设备未在配网窗口内返回局域网'), findsOneWidget);

    await tester.tap(find.text('返回修改 WiFi'));
    await tester.pumpAndSettle();

    expect(find.text('步骤 4/5'), findsOneWidget);
    expect(find.text('HomeWiFi'), findsOneWidget);
    expect(find.text('12345678'), findsOneWidget);
  });
}
