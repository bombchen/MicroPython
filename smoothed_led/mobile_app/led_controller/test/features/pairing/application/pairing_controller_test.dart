import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/pairing/application/pairing_controller.dart';
import 'package:led_controller/features/pairing/application/pairing_coordinator.dart';
import 'package:led_controller/features/pairing/application/pairing_failure.dart';
import 'package:led_controller/features/pairing/domain/pairing_state.dart';
import 'package:led_controller/features/pairing/domain/pairing_step.dart';

class FakePairingCoordinator implements PairingCoordinator {
  bool didOpenWifi = false;
  bool didSendCredentials = false;
  bool didWaitForRegistration = false;
  Object? sendError;
  Object? waitError;

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
    didSendCredentials = true;
    if (sendError != null) {
      throw sendError!;
    }
  }

  @override
  Future<String> waitForDeviceRegistration() async {
    didWaitForRegistration = true;
    if (waitError != null) {
      throw waitError!;
    }
    return '192.168.1.23';
  }
}

void main() {
  test('配网控制器按照步骤推进', () {
    final controller = PairingController();

    expect(controller.state.step, PairingStep.prepare);

    controller.moveToApJoin();
    expect(controller.state.step, PairingStep.joinAp);

    controller.confirmApJoined();
    expect(controller.state.step, PairingStep.enterWifi);

    controller.markSendingConfig('LED_Config', 'secret123');
    expect(controller.state.step, PairingStep.sendingConfig);
    expect(controller.state.ssid, 'LED_Config');
    expect(controller.state.password, 'secret123');
  });

  test(
      'PairingState.copyWith preserves omitted nullable fields and clears explicitly',
      () {
    const original = PairingState(
      step: PairingStep.failure,
      errorMessage: 'network error',
      diagnosticsMessage: 'diag',
      resolvedIpAddress: '192.168.4.1',
    );

    final preserved = original.copyWith();
    expect(preserved.errorMessage, 'network error');
    expect(preserved.diagnosticsMessage, 'diag');
    expect(preserved.resolvedIpAddress, '192.168.4.1');

    final cleared = original.copyWith(resolvedIpAddress: null);
    expect(cleared.resolvedIpAddress, isNull);
  });

  test('提交 WiFi 后进入等待重连并最终成功', () async {
    final coordinator = FakePairingCoordinator();
    final controller = PairingController(coordinator: coordinator);

    await controller.submitCredentials(
      ssid: 'HomeWiFi',
      password: '12345678',
    );

    expect(controller.state.step, PairingStep.success);
    expect(controller.state.resolvedIpAddress, '192.168.1.23');
    expect(coordinator.didSendCredentials, isTrue);
    expect(coordinator.didWaitForRegistration, isTrue);
  });

  test('打开 WiFi 设置后进入返回 APP 步骤', () async {
    final coordinator = FakePairingCoordinator();
    final controller = PairingController(coordinator: coordinator);

    await controller.openWifiSettings();

    expect(coordinator.didOpenWifi, isTrue);
    expect(controller.state.step, PairingStep.returnToApp);
  });

  test('提交 WiFi 失败后进入失败状态并清空旧 IP', () async {
    final coordinator = FakePairingCoordinator()
      ..sendError = Exception('配网超时');
    final controller = PairingController(coordinator: coordinator);

    await controller.submitCredentials(
      ssid: 'HomeWiFi',
      password: '12345678',
    );

    expect(controller.state.step, PairingStep.failure);
    expect(controller.state.errorMessage, contains('配网超时'));
    expect(controller.state.resolvedIpAddress, isNull);
    expect(controller.state.failureType, PairingFailureType.configSendFailed);
    expect(coordinator.didSendCredentials, isTrue);
    expect(coordinator.didWaitForRegistration, isFalse);
  });

  test('提交 WiFi 失败且包含诊断后保留独立诊断信息', () async {
    final coordinator = FakePairingCoordinator()
      ..waitError = const PairingFailure(
        message: '设备未在配网窗口内返回局域网',
        diagnostics: '开始探测: 192.168.4.2',
      );
    final controller = PairingController(coordinator: coordinator);

    await controller.submitCredentials(
      ssid: 'HomeWiFi',
      password: '12345678',
    );

    expect(controller.state.step, PairingStep.failure);
    expect(controller.state.errorMessage, '设备未在配网窗口内返回局域网');
    expect(controller.state.diagnosticsMessage, contains('192.168.4.2'));
    expect(controller.state.failureType, PairingFailureType.reconnectTimedOut);
  });

  test('从返回 APP 步骤确认后进入 WiFi 表单页', () {
    final controller = PairingController();

    controller.moveToApJoin();
    controller.markReturnToApp();
    controller.confirmApJoined();

    expect(controller.state.step, PairingStep.enterWifi);
  });

  test('重试提交前会回到重新连接热点步骤并保留已输入内容', () {
    final controller = PairingController();

    controller.markSendingConfig('HomeWiFi', '12345678');
    controller.returnToApReconnect();

    expect(controller.state.step, PairingStep.returnToApp);
    expect(controller.state.ssid, 'HomeWiFi');
    expect(controller.state.password, '12345678');
    expect(controller.state.errorMessage, isNull);
  });
}
