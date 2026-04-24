import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/pairing/application/pairing_controller.dart';
import 'package:led_controller/features/pairing/domain/pairing_state.dart';
import 'package:led_controller/features/pairing/domain/pairing_step.dart';

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

  test('PairingState.copyWith preserves omitted nullable fields and clears explicitly', () {
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
}
