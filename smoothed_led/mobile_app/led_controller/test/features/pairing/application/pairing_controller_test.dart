import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/pairing/application/pairing_controller.dart';
import 'package:led_controller/features/pairing/application/pairing_coordinator.dart';
import 'package:led_controller/features/pairing/domain/pairing_state.dart';
import 'package:led_controller/features/pairing/domain/pairing_step.dart';

class FakePairingCoordinator implements PairingCoordinator {
  bool didOpenWifi = false;
  bool didSubmit = false;
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
    didSubmit = true;
    if (submitError != null) {
      throw submitError!;
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

    controller.markWaitingReconnect('LED_Config', 'secret123');
    expect(controller.state.step, PairingStep.waitingReconnect);
    expect(controller.state.ssid, 'LED_Config');
    expect(controller.state.password, 'secret123');
  });

  test(
      'PairingState.copyWith preserves omitted nullable fields and clears explicitly',
      () {
    const original = PairingState(
      step: PairingStep.failure,
      errorMessage: 'network error',
      resolvedIpAddress: '192.168.4.1',
    );

    final preserved = original.copyWith();
    expect(preserved.errorMessage, 'network error');
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
    expect(coordinator.didSubmit, isTrue);
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
      ..submitError = Exception('配网超时');
    final controller = PairingController(coordinator: coordinator);

    await controller.submitCredentials(
      ssid: 'HomeWiFi',
      password: '12345678',
    );

    expect(controller.state.step, PairingStep.failure);
    expect(controller.state.errorMessage, contains('配网超时'));
    expect(controller.state.resolvedIpAddress, isNull);
    expect(coordinator.didSubmit, isTrue);
  });
}
