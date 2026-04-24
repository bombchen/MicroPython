import '../domain/pairing_state.dart';
import '../domain/pairing_step.dart';

class PairingController {
  // The later pairing steps are reserved for the approved follow-up tasks.
  PairingState _state = const PairingState(step: PairingStep.prepare);

  PairingState get state => _state;

  void moveToApJoin() {
    _state = _state.copyWith(step: PairingStep.joinAp);
  }

  void confirmApJoined() {
    _state = _state.copyWith(step: PairingStep.enterWifi);
  }

  void markWaitingReconnect(String ssid, String password) {
    _state = _state.copyWith(
      step: PairingStep.waitingReconnect,
      ssid: ssid,
      password: password,
    );
  }
}
