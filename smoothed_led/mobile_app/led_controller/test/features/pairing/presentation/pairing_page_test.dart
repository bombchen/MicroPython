import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/pairing/application/pairing_controller.dart';
import 'package:led_controller/features/pairing/application/pairing_coordinator.dart';
import 'package:led_controller/features/pairing/application/pairing_failure.dart';
import 'package:led_controller/features/pairing/presentation/pairing_page.dart';

class FakePairingCoordinator implements PairingCoordinator {
  bool didOpenWifi = false;
  Object? sendError;
  Object? waitError;
  Duration sendDelay = Duration.zero;
  Duration waitDelay = Duration.zero;

  @override
  Future<void> openWifiSettings() async {
    didOpenWifi = true;
  }

  @override
  Future<void> resetConfiguration() async {}

  @override
  Future<void> sendCredentials({
    required String ssid,
    required String password,
  }) async {
    if (sendDelay > Duration.zero) {
      await Future<void>.delayed(sendDelay);
    }
    if (sendError != null) {
      throw sendError!;
    }
  }

  @override
  Future<String> waitForDeviceRegistration() async {
    if (waitDelay > Duration.zero) {
      await Future<void>.delayed(waitDelay);
    }
    if (waitError != null) {
      throw waitError!;
    }
    return '192.168.1.23';
  }
}

void main() {
  testWidgets('进入 WiFi 表单时默认填充测试用 SSID 和密码', (tester) async {
    final coordinator = FakePairingCoordinator();

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

    expect(find.text('CU_3S2p'), findsOneWidget);
    expect(find.text('qpgmfy'), findsOneWidget);
  });

  testWidgets('配网成功后完成按钮返回语义化结果', (tester) async {
    final coordinator = FakePairingCoordinator();
    PairingFlowResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push<PairingFlowResult>(
                  MaterialPageRoute(
                    builder: (_) => PairingPage(
                      controller: PairingController(coordinator: coordinator),
                    ),
                  ),
                );
              },
              child: const Text('打开配网页'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开配网页'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(result, PairingFlowResult.paired);
  });

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

  testWidgets('设备回网超时后展示诊断信息和继续等待动作', (tester) async {
    final coordinator = FakePairingCoordinator()
      ..waitError = const PairingFailure(
        message: '设备未在配网窗口内返回局域网',
        diagnostics: '开始探测: 192.168.4.2',
      );

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
    expect(find.text('设备未在配网窗口内返回局域网'), findsOneWidget);
    expect(find.text('诊断信息'), findsOneWidget);
    expect(find.textContaining('192.168.4.2'), findsOneWidget);

    expect(find.text('继续等待一次'), findsOneWidget);
    expect(find.text('重新开始'), findsOneWidget);
  });

  testWidgets('提交后立即展示等待重连反馈', (tester) async {
    final coordinator = FakePairingCoordinator()
      ..waitDelay = const Duration(seconds: 2);

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
    await tester.pump();

    expect(find.text('正在等待设备重启并重新接入局域网，请稍候。'), findsOneWidget);
    expect(find.textContaining('HomeWiFi'), findsOneWidget);
    expect(find.textContaining('已等待'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('发送配网信息时先展示发送中步骤', (tester) async {
    final coordinator = FakePairingCoordinator()
      ..sendDelay = const Duration(seconds: 2);

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
    await tester.pump();

    expect(find.text('正在发送配网信息'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('发送配置失败后可原地重试并保留输入内容', (tester) async {
    final coordinator = FakePairingCoordinator()
      ..sendError = TimeoutException('config timed out');

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

    expect(find.text('重试发送配网信息'), findsOneWidget);
    expect(find.text('返回 WiFi 表单'), findsOneWidget);

    await tester.tap(find.text('返回 WiFi 表单'));
    await tester.pumpAndSettle();

    expect(find.text('步骤 4/5'), findsOneWidget);
    expect(find.text('HomeWiFi'), findsOneWidget);
    expect(find.text('12345678'), findsOneWidget);
  });

  testWidgets('设备回网超时后允许继续等待一次', (tester) async {
    final coordinator = FakePairingCoordinator()
      ..waitError = const PairingFailure(
        message: '设备未在配网窗口内返回局域网',
        diagnostics: '开始探测: 192.168.4.2',
      );

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

    expect(find.text('继续等待一次'), findsOneWidget);
  });
}
